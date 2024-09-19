terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.47"
    }
  }
  backend "s3" {
    bucket         = "terraform-state-storage-847068433460"
    dynamodb_table = "terraform-state-lock-847068433460"
    key            = "Piyush-POC-1.tfstate"
    region         = "us-east-1"
    profile        = "Sandbox"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "Sandbox"
  }
