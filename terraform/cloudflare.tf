terraform {
  required_providers {
    cloudflare = {
      source  = "registry.terraform.io/cloudflare/cloudflare"
      version = "4.49.1"
      #version = "5.0.0-alpha1"
    }
    kubernetes = {
      source  = "registry.terraform.io/hashicorp/kubernetes"
      version = "2.35.1"
    }
  }

  backend "kubernetes" {
    namespace         = "semaphoreui"
    secret_suffix     = "state"
    config_path       = "~/.kube/config"
    in_cluster_config = true
  }
}

variable "kube_config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cloudflare_email" {
  description = "Cloudflare email"
  type        = string
}

variable "cloudflare_api_key" {
  description = "Cloudflare API key"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
}

variable "tunnel_secret" {
  description = "Cloudflare Tunnel secret"
  type        = string
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

resource "cloudflare_account" "account" {
  name = "kirillorlov.pro"
  type = "standard"
}

import {
  to = cloudflare_account_member.main_account
  id = "${cloudflare_account.account.id}/d2eded2783d5376eef654d3d17a6d1ea"
}

resource "cloudflare_account_member" "main_account" {
  account_id    = cloudflare_account.account.id
  email_address = "diverofdark@gmail.com"
  role_ids = ["33666b9c79b9a5273fc7344ff42f953d"]
  status        = "accepted"
}

resource "cloudflare_zone" "zone" {
  account_id = cloudflare_account.account.id
  zone       = "kirillorlov.pro"
  type       = "full"
}

resource "cloudflare_record" "bonsai" {
  zone_id = cloudflare_zone.zone.id
  name    = "bonsai"
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  ttl     = 1
  proxied = true
}
resource "cloudflare_record" "cloud" {
  zone_id = cloudflare_zone.zone.id
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  name    = "cloud"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
resource "cloudflare_record" "main" {
  zone_id = cloudflare_zone.zone.id
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  name    = "kirillorlov.pro"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
resource "cloudflare_record" "money" {
  zone_id = cloudflare_zone.zone.id
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  name    = "money"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
resource "cloudflare_record" "status" {
  zone_id = cloudflare_zone.zone.id
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  name    = "status"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
resource "cloudflare_record" "www" {
  zone_id = cloudflare_zone.zone.id
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  name    = "www"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}

#todo setup email routing

resource "cloudflare_record" "dmarc" {
  zone_id = cloudflare_zone.zone.id
  content = "v=DMARC1; p=none; rua=mailto:aae0da00a1dc4478bfd42740df319d8f@dmarc-reports.cloudflare.net,mailto:dmarc@kirillorlov.pro; aspf=r;"
  name    = "_dmarc"
  proxied = false
  ttl     = 1
  type    = "TXT"
}
resource "cloudflare_record" "txt" {
  zone_id = cloudflare_zone.zone.id
  content = "jqsclpyyms"
  name    = "kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "TXT"
}
resource "cloudflare_record" "spf" {
  zone_id = cloudflare_zone.zone.id
  content = "v=spf1 a mx include:_spf.google.com include:_spf.mx.cloudflare.net  ~all"
  name    = "kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = cloudflare_account.account.id
  name       = "GitHub"
  type       = "github"
  config {
    client_id = "Ov23liDFOC6cLvQ2YZM2"
  }
}

resource "cloudflare_zero_trust_access_identity_provider" "onetime" {
  account_id = cloudflare_account.account.id
  type       = "onetimepin"
  name       = "One-Time PIN"
}

resource "cloudflare_zero_trust_dns_location" "default_location" {
  account_id     = cloudflare_account.account.id
  client_default = true
  ecs_support    = false
  name           = "Default Location"
}

resource "cloudflare_zero_trust_gateway_policy" "allow_home_network" {
  account_id  = cloudflare_account.account.id
  action      = "allow"
  description = "default"
  enabled     = true
  filters = ["l4"]
  name        = "allow localnet"
  precedence  = 9
  traffic     = "net.dst.ip in {192.168.0.0/16}"
  rule_settings {
    block_page_enabled                 = false
    insecure_disable_dnssec_validation = false
    ip_categories                      = false
    notification_settings {
      enabled = false
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "kubernetes_account" {
  account_id = cloudflare_account.account.id
  name       = "k8s"
  secret     = base64encode(var.tunnel_secret)
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_virtual_network" "kubernetes_virtual_network" {
  account_id         = cloudflare_account.account.id
  name               = "HomeNetwork"
  is_default_network = true
}

resource "cloudflare_zero_trust_tunnel_route" "example" {
  account_id         = cloudflare_account.account.id
  tunnel_id          = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
  network            = "192.168.0.0/16"
  comment            = "HomeNetwork route"
  virtual_network_id = cloudflare_zero_trust_tunnel_virtual_network.kubernetes_virtual_network.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kubernetes_account_config" {
  account_id = cloudflare_account.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id

  config {
    ingress_rule {
      hostname = "kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
    }
    ingress_rule {
      hostname = "www.kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
    }
    ingress_rule {
      hostname = "cloud.kirillorlov.pro"
      service = "http://nextcloud.nextcloud.svc.cluster.local"
    }
    ingress_rule {
      hostname = "money.kirillorlov.pro"
      service = "http://actualbudget.actualbudget.svc.cluster.local"
    }
    ingress_rule {
      hostname = "bonsai.kirillorlov.pro"
      service = "http://bonsai.bonsai.svc.cluster.local"
    }
    ingress_rule {
      hostname = "status.kirillorlov.pro"
      service = "http://homepage.statuspage.svc.cluster.local:3000"
    }
    ingress_rule {
      # Respond with a `404` status code when the request does not match any of the previous hostnames.
      service  = "http_status:404"
    }
    warp_routing {
      enabled = true
    }
  }
}

resource "kubernetes_secret" "cloudflared_config" {
  metadata {
    namespace = "cloudflared"
    name = "cloudflare-api-token-secret"
  }
  data = {
    account-id = cloudflare_account.account.id
    api-token = var.cloudflare_api_token
    tunnel-id = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
    tunnelToken = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.tunnel_token
  }
}

resource "kubernetes_secret" "certmanager_config" {
  metadata {
    namespace = "cert-manager"
    name = "cloudflare-api-token-secret"
  }
  data = {
    account-id = cloudflare_account.account.id
    api-token = var.cloudflare_api_token
    tunnel-id = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
  }
}
