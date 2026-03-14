terraform {
  required_providers {
    cloudflare = {
      source  = "registry.terraform.io/cloudflare/cloudflare"
      version = "5.18.0"
    }
    kubernetes = {
      source  = "registry.opentofu.org/hashicorp/kubernetes"
      version = "3.0.1"
    }
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.9.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.7.0"
    }
  }

  backend "kubernetes" {
    namespace         = "github-runner"
    secret_suffix     = "state"
    config_path       = "~/.kube/config"
    in_cluster_config = true
  }
}

variable "kube_config" {
  default     = null
  description = "Path to kubeconfig file"
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

locals {
  ingress_rules = [
    {
      short = "kirillorlov.pro"
      hostname = "kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
    }, {
      short = "www"
      hostname = "www.kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
    }, {
      short = "cloud"
      hostname = "cloud.kirillorlov.pro"
      service  = "http://nextcloud.nextcloud.svc.cluster.local"
    }, {
      short = "bonsai"
      hostname = "bonsai.kirillorlov.pro"
      service  = "http://bonsai.bonsai.svc.cluster.local"
    }, {
      short = "auth"
      hostname = "auth.kirillorlov.pro"
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      originRequest = {
          noTLSVerify = true
      }
    }, {
      short = "status"
      hostname = "status.kirillorlov.pro"
      service  = "http://homepage.statuspage.svc.cluster.local:3000"
    }, {
      short = "vaultwarden"
      hostname = "vaultwarden.kirillorlov.pro"
      service  = "http://vaultwarden.vaultwarden.svc.cluster.local"
    }, {
      short = "money"
      hostname = "money.kirillorlov.pro"
      service  = "http://actualbudget.actualbudget.svc.cluster.local:80"
    }, {
      short = "suwayomi"
      hostname = "suwayomi.kirillorlov.pro"
      service  = "http://suwayomi-server.nextcloud.svc.cluster.local:4568"
    }
  ]
}

provider "cloudflare" {
  email   = data.vault_kv_secret_v2.cloudflare.data["email"]
  api_key = data.vault_kv_secret_v2.cloudflare.data["api_key"]
}

provider "kubernetes" {
  config_path = var.kube_config
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
