terraform {
  backend "s3" {
    # Bucket for Terraform state - create once via scripts/bootstrap-state.sh
    bucket         = "brickeye-tfstate-bedrock"
    key            = "bedrock/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "brickeye-tfstate-locks"
    encrypt        = true
  }
}