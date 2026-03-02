terraform {
  required_version = ">= 1.6.0"

  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "~> 1.6"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.6"
    }
  }
}
