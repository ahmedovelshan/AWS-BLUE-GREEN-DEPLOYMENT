terraform {
  backend "s3" {
    bucket         = "aws-blue-green-deployment"
    region         = "eu-central-1"
    key            = "terraform/state.tfstate"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
  required_version = ">=0.13.0"
}