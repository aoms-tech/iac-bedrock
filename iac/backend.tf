terraform {
  backend "s3" {
    # Values supplied via -backend-config=backend.hcl.
    # State is stored at: env:/prod/bedrock/terraform.tfstate
    #
    # Run iac/scripts/bootstrap-state.sh once per account before terraform init.
  }
}
