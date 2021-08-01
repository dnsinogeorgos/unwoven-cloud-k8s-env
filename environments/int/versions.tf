terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.52"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.1"
    }
  }
}
