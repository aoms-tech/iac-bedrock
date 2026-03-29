terraform {
  backend "s3" {
    # All values supplied via -backend-config=environments/<env>/backend.hcl
    # Run scripts/bootstrap-state.sh once per account before terraform init.
    #
    # Required at init time (set in backend.hcl):
    #   bucket         - S3 bucket holding Terraform state
    #   key            - path within the bucket for this env's state file
    #   region         - AWS region of the state bucket
    #   dynamodb_table - DynamoDB table for state locking
    #   encrypt        - must be true
  }
}
