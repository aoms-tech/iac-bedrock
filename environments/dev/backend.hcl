bucket         = "brickeye-terraform-state-<ACCOUNT_ID>"
key            = "bedrock/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "brickeye-terraform-locks"
encrypt        = true
