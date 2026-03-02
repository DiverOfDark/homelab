provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "kubernetes" {
  config_path = var.kube_config
}

module "cloudflare_zone" {
  source = "./modules/cloudflare-zone"
}

module "cloudflare_tunnel" {
  source        = "./modules/cloudflare-tunnel"
  account_id    = module.cloudflare_zone.account_id
  tunnel_name   = "k8s"
  tunnel_secret = var.tunnel_secret
  ingress_rules = [
    for r in var.ingress_rules : {
      hostname = r.hostname
      service  = r.service
    }
  ]
}

module "cloudflare_dns" {
  source      = "./modules/cloudflare-dns"
  zone_id     = module.cloudflare_zone.zone_id
  dns_records = [for record in var.dns_records : record if record.name != "yggdrasil" && record.name != "yggdrasil-s"]
}

module "kubernetes_secrets" {
  source                = "./modules/kubernetes-secrets"
  namespace             = "cloudflared"
  certmanager_namespace = "cert-manager"
  cloudflare_account_id = module.cloudflare_zone.account_id
  cloudflare_api_token  = var.cloudflare_api_token
  tunnel_id             = module.cloudflare_tunnel.tunnel_id
  tunnel_token          = module.cloudflare_tunnel.tunnel_token
}

resource "cloudflare_record" "tunnel_records" {
  for_each = {
    yggdrasil   = module.cloudflare_tunnel.cname
    yggdrasil-s = module.cloudflare_tunnel.cname
  }

  zone_id = module.cloudflare_zone.zone_id
  name    = each.key
  type    = "CNAME"
  content = each.value
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "dmarc" {
  zone_id = module.cloudflare_zone.zone_id
  content = "v=DMARC1; p=none; rua=mailto:aae0da00a1dc4478bfd42740df319d8f@dmarc-reports.cloudflare.net,mailto:dmarc@kirillorlov.pro; aspf=r;"
  name    = "_dmarc"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_record" "spf" {
  zone_id = module.cloudflare_zone.zone_id
  content = "v=spf1 a mx include:_spf.google.com include:_spf.mx.cloudflare.net include:mailgun.org ~all"
  name    = var.zone_name
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_record" "mailgun_txt" {
  zone_id = module.cloudflare_zone.zone_id
  content = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8FNoH2XVc2hlcoBoalxE9K1Q71wEGvwS2gtQMMO2yIq6cb+O/aJktZl1LtxOgabmOAyCSOXt2fVbwcZHo4+t+6E4JLHCUQUQ4YAAt4qRp/kdCG/HRi2de768tMUWloOPI4a4/66RxxbQIdwOsUN+MqMP9CIT6zarfOutsDW73vwIDAQAB"
  name    = "s1._domainkey.kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_record" "email_cname" {
  zone_id = module.cloudflare_zone.zone_id
  content = "eu.mailgun.org"
  name    = "email.kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "CNAME"
}

resource "cloudflare_email_routing_settings" "email_routing" {
  enabled = true
  zone_id = module.cloudflare_zone.zone_id
}

resource "cloudflare_email_routing_rule" "routing_rules" {
  for_each = { for rule in var.email_routing_rules : rule.name => rule }

  zone_id = module.cloudflare_zone.zone_id
  name    = each.value.name
  enabled = each.value.enabled

  matcher {
    type  = "literal"
    field = "to"
    value = each.value.name
  }

  action {
    type  = "forward"
    value = [each.value.to]
  }
}

resource "cloudflare_email_routing_catch_all" "catch_all" {
  zone_id = module.cloudflare_zone.zone_id
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

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = module.cloudflare_zone.account_id
  name       = "GitHub"
  type       = "github"

  config {
    client_id = "Ov23liDFOC6cLvQ2YZM2"
  }
}

resource "cloudflare_zero_trust_access_identity_provider" "onetime" {
  account_id = module.cloudflare_zone.account_id
  type       = "onetimepin"
  name       = "One-Time PIN"
}

resource "cloudflare_zero_trust_access_application" "warp_enrollment_app" {
  account_id                = module.cloudflare_zone.account_id
  session_duration          = "24h"
  name                      = "Warp Login App"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id, cloudflare_zero_trust_access_identity_provider.onetime.id]
  auto_redirect_to_identity = false
  type                      = "warp"
  app_launcher_visible      = false
}

resource "cloudflare_zero_trust_access_policy" "warp_enrollment_employees" {
  application_id = cloudflare_zero_trust_access_application.warp_enrollment_app.id
  account_id     = module.cloudflare_zone.account_id
  name           = "Allow company emails"
  decision       = "allow"
  precedence     = 1

  include {
    email_domain = ["kirillorlov.pro"]
  }
}

resource "cloudflare_zero_trust_dns_location" "default_location" {
  account_id     = module.cloudflare_zone.account_id
  client_default = true
  ecs_support    = false
  name           = "Default Location"
}

resource "cloudflare_zero_trust_gateway_policy" "allow_home_network" {
  account_id  = module.cloudflare_zone.account_id
  action      = "allow"
  description = "default"
  enabled     = true
  filters     = ["l4"]
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
