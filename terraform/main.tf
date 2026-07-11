terraform {
  required_providers {
    cloudflare = {
      source  = "registry.terraform.io/cloudflare/cloudflare"
      version = "5.19.1"
    }
  
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.12.8"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.9.0"
    }
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~> 6.0"
    }
    bunnynet = {
      source  = "registry.terraform.io/BunnyWay/bunnynet"
      version = "0.14.2"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.10"
    }
    hcloud = {
      source  = "registry.terraform.io/hetznercloud/hcloud"
      version = "~> 1.52"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "local" {
    path = "tfstate"
  }
}

variable "openbao_token" {
  description = "OpenBao/Vault token for authentication"
  type        = string
  sensitive   = true
}

variable "zitadel_org_id" {
  description = "Zitadel organization ID"
  type        = string
  default     = "363252298534683134"
}

# Secrets that land in regular (state-persisted) resource attributes can't use
# ephemeral vault reads — flake.nix exports them as TF_VARs from OpenBao
# (secret/cloudflare) instead.
variable "cloudflare_api_token" {
  description = "Cloudflare API token (OpenBao secret/cloudflare key api_token; exported by flake.nix)"
  type        = string
  sensitive   = true
}

provider "cloudflare" {
  email   = ephemeral.vault_kv_secret_v2.cloudflare.data["email"]
  api_key = ephemeral.vault_kv_secret_v2.cloudflare.data["api_key"]
}

resource "cloudflare_account" "account" {
  name = "kirillorlov.pro"
}

resource "cloudflare_account_member" "main_account" {
  account_id = cloudflare_account.account.id
  email      = "diverofdark@gmail.com"
  roles      = ["33666b9c79b9a5273fc7344ff42f953d"]
  status     = "accepted"
}

resource "cloudflare_zone" "zone" {
  account = {
    id = cloudflare_account.account.id
  }
  name = "kirillorlov.pro"
  type = "full"
}
