resource "aws_bedrock_guardrail" "default" {
  count = var.enable_guardrail ? 1 : 0

  name                      = "${var.name_prefix}-guardrail"
  description               = "Baseline content filters for ${var.project_name} (${var.environment})"
  blocked_input_messaging   = "This request was blocked by organizational safety policies."
  blocked_outputs_messaging = "This response was blocked by organizational safety policies."

  # CLASSIC = single-region; STANDARD requires cross-Region inference for guardrails (account/org opt-in).
  # See: https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-tiers.html
  content_policy_config {
    tier_config {
      tier_name = "CLASSIC"
    }

    filters_config {
      type            = "HATE"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
  }
}
