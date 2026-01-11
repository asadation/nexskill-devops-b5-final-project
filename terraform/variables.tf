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

variable "link_service_tag" {
  type        = string
  description = "Link service image tag"
}

variable "frontend_tag" {
  type        = string
  description = "Frontend image tag"
}

variable "analytics_tag" {
  type        = string
  description = "Analytics service image tag"
}