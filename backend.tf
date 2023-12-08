# store the terraform state file in s3 and lock with dynamodb
terraform {
  backend "s3" {
    bucket         = "cobys-terraform-remote-state"
    key            = "terraform-module/dynamic-web-app/terraform.tfstate"
    region         = "us-east-1"
    profile        = "Coby"
    dynamodb_table = "terraform-state-lock"
  }
}