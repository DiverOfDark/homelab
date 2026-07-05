terraform {
  required_providers {
    cloudflare = {
      source  = "registry.terraform.io/cloudflare/cloudflare"
      version = "5.19.1"
    }
    kubernetes = {
      source  = "registry.opentofu.org/hashicorp/kubernetes"
      version = "3.2.0"
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

# Secrets that land in regular (state-persisted) resource attributes can't use
# ephemeral vault reads — flake.nix exports them as TF_VARs from OpenBao
# (secret/cloudflare) instead, which retires the deprecated
# data.vault_kv_secret_v2 sources.
variable "cloudflare_api_token" {
  description = "Cloudflare API token (OpenBao secret/cloudflare key api_token; exported by flake.nix)"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_secret" {
  description = "Shared secret for the cloudflared tunnels (OpenBao secret/cloudflare key tunnel_secret; exported by flake.nix)"
  type        = string
  sensitive   = true
}

locals {
  # Hostnames migrated off the cloudflared tunnel onto the Hetzner edge
  # (midgard, traefik-external): each entry here becomes a DNS-only A record
  # to midgard's pinned IP instead of the proxied tunnel CNAME. Migrate in
  # small batches (canary: "status"); rollback = remove from the list and
  # apply. The app's Ingress must carry the kirillorlov.pro/expose=external
  # label BEFORE its hostname is added here. auth/appbahn go LAST.
  migrated_hostnames = []

  ingress_rules = [
    {
      short    = "kirillorlov.pro"
      hostname = "kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
      }, {
      short    = "www"
      hostname = "www.kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
      }, {
      short    = "cloud"
      hostname = "cloud.kirillorlov.pro"
      service  = "http://nextcloud.nextcloud.svc.cluster.local"
      }, {
      short    = "bonsai"
      hostname = "bonsai.kirillorlov.pro"
      service  = "http://bonsai.bonsai.svc.cluster.local"
      }, {
      short    = "auth"
      hostname = "auth.kirillorlov.pro"
      # Traefik lives in the `traefik` namespace (NOT kube-system) — the old
      # kube-system URL made cloudflared 502 on the public path for years,
      # unnoticed because LAN/WARP clients resolve via pihole -> internal
      # traefik and never hit the tunnel.
      service  = "https://traefik.traefik.svc.cluster.local:443"
      originRequest = {
        noTLSVerify = true
      }
      }, {
      short    = "status"
      hostname = "status.kirillorlov.pro"
      service  = "http://homepage.statuspage.svc.cluster.local:3000"
      }, {
      short    = "vaultwarden"
      hostname = "vaultwarden.kirillorlov.pro"
      service  = "http://vaultwarden.vaultwarden.svc.cluster.local"
      }, {
      short    = "money"
      hostname = "money.kirillorlov.pro"
      service  = "http://actualbudget.actualbudget.svc.cluster.local:80"
      }, {
      short    = "appbahn"
      hostname = "appbahn.kirillorlov.pro"
      # Same namespace fix as `auth` above.
      service  = "https://traefik.traefik.svc.cluster.local:443"
      originRequest = {
        noTLSVerify = true
      }
      }, {
      short    = "suwayomi"
      hostname = "suwayomi.kirillorlov.pro"
      service  = "http://suwayomi-server.nextcloud.svc.cluster.local:4568"
    }
  ]
}

provider "cloudflare" {
  email   = ephemeral.vault_kv_secret_v2.cloudflare.data["email"]
  api_key = ephemeral.vault_kv_secret_v2.cloudflare.data["api_key"]
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
