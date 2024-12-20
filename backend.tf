terraform {
  backend "s3" {
    bucket         = "aws-dynamic-web-app"
    region         = "eu-central-1"
    key            = "Demo-Devops-Project/terraform.tfstate"
    dynamodb_table = "terraform-tfstate"
    encrypt        = true
  }
  required_version = ">=0.13.0"
}