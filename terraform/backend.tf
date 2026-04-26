terraform {
  backend "s3" {
    bucket         = "state-file-locking-practise"
    key            = "job-portal/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
  }
}