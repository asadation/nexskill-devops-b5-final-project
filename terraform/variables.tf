# providers.tf

provider "aws" {
  region = "eu-north-1"  # Change to your desired region
}

# bucket 
terraform {
  backend "s3" {
    bucket = "terraform-bucket-aw123"
    key = "nexskill-final-project/terraform.tfstate"
    region = "eu-north-1"
  }
}


