terraform {
  required_providers {
    cloudflare = {
      source  = "registry.terraform.io/cloudflare/cloudflare"
      version = "4.52.5"
      #version = "5.0.0-alpha1"
    }
    kubernetes = {
      source  = "registry.opentofu.org/hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  backend "kubernetes" {
    namespace         = "github-runner"
    secret_suffix     = "state"
    config_path       = "~/.kube/config"
    in_cluster_config = true
  }
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

variable "kube_config" {
  default = null
  description = "Path to kubeconfig file"
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
      short = "dex"
      hostname = "dex.kirillorlov.pro"
      service  = "http://dex.oauth2-proxy.svc.cluster.local:5556"
    }, {
      short = "logto"
      hostname = "logto.kirillorlov.pro"
      service  = "http://logto.logto.svc.cluster.local:3001"
    }, {
      short = "ai"
      hostname = "ai.kirillorlov.pro"
      service  = "http://lobechat.lobechat.svc.cluster.local:80"
    }, {
      short = "search"
      hostname = "search.kirillorlov.pro"
      service  = "http://searxng.lobechat.svc.cluster.local:80"
    }, {
      short = "money"
      hostname = "money.kirillorlov.pro"
      service  = "http://actualbudget.actualbudget.svc.cluster.local:80"
    }
  ]
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

provider "kubernetes" {
  config_path = var.kube_config
}

resource "cloudflare_account" "account" {
  name = "kirillorlov.pro"
  type = "standard"
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

resource "cloudflare_record" "records" {
  for_each = { for rules in local.ingress_rules: rules.short => rules }
  name    = each.value.short

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.cname
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "backup" {
  name    = "yggdrasil"

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.cname
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "backup-s" {
  name    = "yggdrasil-s"

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.cname
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "uptime1" {
    name = "uptime"
    zone_id = cloudflare_zone.zone.id
    type = "CNAME"
    content = "diverofdark.github.io"
    ttl = 1
    proxied = false
}
#todo setup email routing
resource "cloudflare_email_routing_settings" "email_routing" {
  enabled = true
  zone_id = cloudflare_zone.zone.id
}

resource "cloudflare_email_routing_rule" "i_at_kirillorlov_pro" {
  zone_id = cloudflare_zone.zone.id
  name    = "i@kirillorlov.pro"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "i@kirillorlov.pro"
  }

  action {
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }
}

resource "cloudflare_email_routing_rule" "me_at_kirillorlov_pro" {
  zone_id = cloudflare_zone.zone.id
  name    = "me@kirillorlov.pro"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "me@kirillorlov.pro"
  }

  action {
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }
}

resource "cloudflare_email_routing_catch_all" "send_all_to_gmail" {
  zone_id = cloudflare_zone.zone.id
  name    = "catch all"
  enabled = true

  matcher {
    type = "all"
  }

  action {
    type  = "forward"
    value = ["diverofdark@gmail.com"]
  }
}

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

resource "cloudflare_zero_trust_access_application" "warp_enrollment_app" {
  account_id                = cloudflare_account.account.id
  session_duration          = "24h"
  name                      = "Warp Login App"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id, cloudflare_zero_trust_access_identity_provider.onetime.id]
  auto_redirect_to_identity = false
  type                      = "warp"
  app_launcher_visible      = false
}

resource "cloudflare_zero_trust_access_policy" "warp_enrollment_employees" {
  application_id = cloudflare_zero_trust_access_application.warp_enrollment_app.id
  account_id     = cloudflare_account.account.id
  name           = "Allow company emails"
  decision       = "allow"
  precedence     = 1

  include {
    email_domain = ["kirillorlov.pro"]
  }
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

resource "cloudflare_zero_trust_tunnel_cloudflared" "yggdrasil" {
  account_id = cloudflare_account.account.id
  name       = "yggdrasil"
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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "yggdrasil_config" {
  account_id = cloudflare_account.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.id

  config {
    ingress_rule {
      hostname = "yggdrasil.kirillorlov.pro"
      service  = "http://127.0.0.1"
    }
    ingress_rule {
      hostname = "yggdrasil-s.kirillorlov.pro"
      service  = "ssh://127.0.0.1"
    }
    ingress_rule {
      # Respond with a `404` status code when the request does not match any of the previous hostnames.
      service  = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kubernetes_account_config" {
  account_id = cloudflare_account.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id

  config {
    dynamic "ingress_rule" {
      for_each = local.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
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