terraform {
  backend "s3" {
    # Values supplied via -backend-config=backend.hcl (single file, all envs).
    # Workspaces provide state isolation:
    #   dev  → env:/dev/bedrock/terraform.tfstate
    #   prod → env:/prod/bedrock/terraform.tfstate
    #
    # Run scripts/bootstrap-state.sh once per account before terraform init.
  }
}
