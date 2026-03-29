terraform {
  backend "s3" {
    # Bucket for Terraform state - create once via scripts/bootstrap-state.sh
    bucket       = "brickeye-tfstate-bedrock"
    key          = "bedrock/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = false
  }
}