#!/bin/bash
# scripts/audit-iam-accounts.sh
# Classify IAM users as HUMAN or BOT, identify risk of touching each

set -e

AWS_PROFILE="${AWS_PROFILE:-default}"
OUTPUT_FILE="/tmp/iam-audit-$(date +%Y%m%d-%H%M%S).json"
RISK_FILE="/tmp/iam-risk-assessment.txt"

echo "=== AWS IAM Account Audit ==="
echo "Using AWS profile: $AWS_PROFILE"
echo "Analyzing all IAM users to classify as HUMAN or BOT..."
echo ""

# Initialize output
echo "[]" > "$OUTPUT_FILE"

# Get all IAM users
USERS=$(aws iam list-users --profile "$AWS_PROFILE" --query 'Users[*].UserName' --output text)

echo "Found users: $USERS"
echo ""

# Analyze each user
ANALYSIS="[]"

for user in $USERS; do
  echo "─────────────────────────────────"
  echo "Analyzing: $user"

  # Get access keys
  ACCESS_KEYS=$(aws iam list-access-keys --profile "$AWS_PROFILE" --user-name "$user" --query 'AccessKeyMetadata | length(@)' --output text)

  # Check for console password
  HAS_CONSOLE=0
  aws iam get-login-profile --profile "$AWS_PROFILE" --user-name "$user" >/dev/null 2>&1 && HAS_CONSOLE=1

  # Get policies
  INLINE_POLICIES=$(aws iam list-user-policies --profile "$AWS_PROFILE" --user-name "$user" --query 'PolicyNames | length(@)' --output text)
  ATTACHED_POLICIES=$(aws iam list-attached-user-policies --profile "$AWS_PROFILE" --user-name "$user" --query 'AttachedPolicies | length(@)' --output text)

  # Check for MFA
  HAS_MFA=0
  MFA_COUNT=$(aws iam list-mfa-devices --profile "$AWS_PROFILE" --user-name "$user" --query 'MFADevices | length(@)' --output text)
  [ "$MFA_COUNT" -gt 0 ] && HAS_MFA=1

  # Get last used
  LAST_USED=$(aws iam get-user --profile "$AWS_PROFILE" "$user" --query 'User.CreateDate' --output text 2>/dev/null || echo "N/A")

  # Get access key details
  KEY_AGES=""
  if [ "$ACCESS_KEYS" -gt 0 ]; then
    KEY_AGES=$(aws iam list-access-keys --profile "$AWS_PROFILE" --user-name "$user" --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate]' --output text)
  fi

  # Classification logic
  CLASSIFICATION="UNKNOWN"
  REASONING=""
  RISK_LEVEL="UNKNOWN"

  # Bot indicators
  if [[ "$user" =~ -bot$ ]] || [[ "$user" =~ -ci$ ]] || [[ "$user" =~ _bot$ ]] || [[ "$user" =~ "bot" ]]; then
    CLASSIFICATION="BOT"
    REASONING="Naming convention (contains 'bot', '-bot', '-ci')"
    RISK_LEVEL="HIGH"
  fi

  if [ "$HAS_CONSOLE" -eq 0 ] && [ "$ACCESS_KEYS" -gt 0 ]; then
    if [ "$CLASSIFICATION" = "UNKNOWN" ]; then
      CLASSIFICATION="BOT"
      REASONING="Has access keys but no console password (typical bot pattern)"
      RISK_LEVEL="HIGH"
    fi
  fi

  # Human indicators
  if [ "$HAS_CONSOLE" -eq 1 ] && [ "$CLASSIFICATION" = "UNKNOWN" ]; then
    CLASSIFICATION="HUMAN"
    REASONING="Has console password enabled"
    RISK_LEVEL="LOW"
  fi

  if [ "$HAS_MFA" -eq 1 ] && [ "$CLASSIFICATION" = "UNKNOWN" ]; then
    CLASSIFICATION="HUMAN"
    REASONING="Has MFA devices configured"
    RISK_LEVEL="LOW"
  fi

  # Service account pattern
  if [[ "$user" =~ "-deploy" ]] || [[ "$user" =~ "-service" ]] || [[ "$user" =~ "-lambda" ]]; then
    CLASSIFICATION="BOT"
    REASONING="Service account naming pattern"
    RISK_LEVEL="CRITICAL"
  fi

  if [ "$CLASSIFICATION" = "UNKNOWN" ]; then
    CLASSIFICATION="HUMAN"
    REASONING="Default classification (insufficient signals, review manually)"
    RISK_LEVEL="MEDIUM"
  fi

  # Output details
  echo "Classification: $CLASSIFICATION"
  echo "Reasoning: $REASONING"
  echo "Risk Level: $RISK_LEVEL"
  echo "Access Keys: $ACCESS_KEYS"
  echo "Console Access: $([ $HAS_CONSOLE -eq 1 ] && echo "YES" || echo "NO")"
  echo "MFA Devices: $MFA_COUNT"
  echo "Inline Policies: $INLINE_POLICIES"
  echo "Attached Policies: $ATTACHED_POLICIES"
  echo ""

  # Build JSON entry
  cat >> "$OUTPUT_FILE" <<EOF
{
  "UserName": "$user",
  "Classification": "$CLASSIFICATION",
  "Reasoning": "$REASONING",
  "RiskLevel": "$RISK_LEVEL",
  "AccessKeyCount": $ACCESS_KEYS,
  "HasConsoleAccess": $HAS_CONSOLE,
  "MFADeviceCount": $MFA_COUNT,
  "InlinePolicies": $INLINE_POLICIES,
  "AttachedPolicies": $ATTACHED_POLICIES,
  "KeyAges": "$(echo "$KEY_AGES" | tr '\n' ' ')"
}
EOF
done

# Generate summary report
cat > "$RISK_FILE" <<'EOF'
=== IAM ACCOUNT RISK ASSESSMENT ===

CRITICAL RISK (DO NOT TERRAFORM):
├─ Any account with "-deploy" or "-service" in name
├─ Any account used in CI/CD pipelines (GitHub Actions, GitLab CI, etc.)
├─ Any account used by Terraform automation
├─ Any account used by Lambda functions or other AWS services
└─ These MUST remain manual for safety

HIGH RISK (LEAVE UNCHANGED):
├─ Accounts ending in "-bot" or "-ci"
├─ Accounts with NO console password (likely service account)
├─ Accounts with access keys but no MFA
└─ Terraform-managing these could break automation

LOW RISK (SAFE TO MIGRATE TO SSO):
├─ Human employee names (alice, bob, charlie)
├─ Accounts with console password set
├─ Accounts with MFA devices configured
├─ Accounts used for interactive AWS console access
└─ These are good candidates for SSO migration

RECOMMENDATION:
1. Review the JSON output: /tmp/iam-audit-*.json
2. For each "BOT" account, verify in your CI/CD/automation systems
3. For each "HUMAN" account, prepare to migrate to SSO
4. For any "MEDIUM" risk accounts, make manual classification
5. NEVER Terraform-manage accounts with "CRITICAL" or "HIGH" risk levels

EOF

cat "$RISK_FILE"

echo ""
echo "=== AUDIT COMPLETE ==="
echo "Detailed output: $OUTPUT_FILE"
echo "Risk assessment: $RISK_FILE"
echo ""
echo "Next steps:"
echo "1. Review the output files above"
echo "2. Classify any 'UNKNOWN' accounts manually"
echo "3. For HUMAN accounts: Plan SSO migration"
echo "4. For BOT accounts: Document their purpose and keep manual"
echo "5. Share results with security team for approval"
echo ""

# Pretty print JSON if jq is available
if command -v jq &> /dev/null; then
  echo "=== SUMMARY TABLE ==="
  jq -r '.[] | "\(.UserName)\t\(.Classification)\t\(.RiskLevel)\t(Keys: \(.AccessKeyCount), Console: \(.HasConsoleAccess), MFA: \(.MFADeviceCount))"' "$OUTPUT_FILE" 2>/dev/null || cat "$OUTPUT_FILE"
else
  echo "Install jq for better output formatting:"
  echo "  brew install jq"
  echo "Then run:"
  echo "  jq '.[] | {UserName, Classification, RiskLevel}' $OUTPUT_FILE"
fi

# Generate migration plan
echo ""
echo "=== MIGRATION PLAN TEMPLATE ==="
echo ""
echo "PHASE 1: HUMANS TO SSO"
echo "─────────────────────"
jq -r '.[] | select(.Classification == "HUMAN") | .UserName' "$OUTPUT_FILE" 2>/dev/null | while read user; do
  echo "  [ ] $user - Create SSO identity in IAM Identity Center"
done

echo ""
echo "PHASE 2: BOTS - NO ACTION REQUIRED"
echo "──────────────────────────────────"
jq -r '.[] | select(.Classification == "BOT") | "\(.UserName) (Risk: \(.RiskLevel))"' "$OUTPUT_FILE" 2>/dev/null | while read user; do
  echo "  ✓ $user - Keep unchanged"
done

echo ""
echo "PHASE 3: MANUAL REVIEW REQUIRED"
echo "───────────────────────────────"
jq -r '.[] | select(.Classification == "UNKNOWN") | .UserName' "$OUTPUT_FILE" 2>/dev/null | while read user; do
  echo "  [ ] $user - Classify manually (ask team)"
done
