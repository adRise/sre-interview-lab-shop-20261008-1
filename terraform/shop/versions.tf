terraform {
  required_version = ">= 1.10"
  # Exact versions: CI and local plans use the same providers on this state.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}
