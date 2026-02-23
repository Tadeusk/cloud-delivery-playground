terraform {

  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  s3_use_path_style           = false
  skip_metadata_api_check     = true

  default_tags {
    tags = {
      Owner      = "Krzysiu"
      Project    = "Career_Pivot"
      ManagedBy  = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
