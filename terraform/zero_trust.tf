resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = cloudflare_account.account.id
  name       = "GitHub"
  type       = "github"
  config = {
    client_id = "Ov23liDFOC6cLvQ2YZM2"
  }
}

resource "cloudflare_zero_trust_access_identity_provider" "onetime" {
  account_id = cloudflare_account.account.id
  type       = "onetimepin"
  name       = "One-Time PIN"
  config     = {}
}

resource "cloudflare_zero_trust_access_policy" "warp_allow" {
  account_id = cloudflare_account.account.id
  name       = "Allow company emails"
  decision   = "allow"
  include = [{
    email_domain = {
      domain = "kirillorlov.pro"
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "warp_enrollment_app" {
  account_id                = cloudflare_account.account.id
  session_duration          = "24h"
  name                      = "Warp Login App"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id, cloudflare_zero_trust_access_identity_provider.onetime.id]
  auto_redirect_to_identity = false
  type                      = "warp"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.warp_allow.id
    precedence = 1
  }]
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
  filters     = ["l4"]
  name        = "allow localnet"
  traffic     = "net.dst.ip in {192.168.0.0/16}"

  # Workaround for cloudflare provider v5 bug: computed fields cause perpetual diff
  # https://github.com/cloudflare/terraform-provider-cloudflare/issues/5839
  lifecycle {
    ignore_changes = [precedence, rule_settings]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "kubernetes_account" {
  account_id = cloudflare_account.account.id
  name       = "k8s"
  tunnel_secret = base64encode(var.tunnel_secret)
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "yggdrasil" {
  account_id = cloudflare_account.account.id
  name       = "yggdrasil"
  tunnel_secret = base64encode(var.tunnel_secret)
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_virtual_network" "kubernetes_virtual_network" {
  account_id         = cloudflare_account.account.id
  name               = "HomeNetwork"
  is_default_network = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "example" {
  account_id         = cloudflare_account.account.id
  tunnel_id          = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
  network            = "192.168.0.0/16"
  comment            = "HomeNetwork route"
  virtual_network_id = cloudflare_zero_trust_tunnel_cloudflared_virtual_network.kubernetes_virtual_network.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "yggdrasil_config" {
  account_id = cloudflare_account.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.id

  config = {
    ingress = [
      {
        hostname = "yggdrasil.kirillorlov.pro"
        service  = "http://127.0.0.1"
      },
      {
        hostname = "yggdrasil-s.kirillorlov.pro"
        service  = "ssh://127.0.0.1"
      },
      {
        # Respond with a `404` status code when the request does not match any of the previous hostnames.
        service = "http_status:404"
      }
    ]
    origin_request = {}
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kubernetes_account_config" {
  account_id = cloudflare_account.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id

  config = {
    ingress = concat(
      [for rule in local.ingress_rules : {
        hostname = rule.hostname
        service  = rule.service
      }],
      [{
        # Respond with a `404` status code when the request does not match any of the previous hostnames.
        service = "http_status:404"
      }]
    )
    origin_request = {}
    warp_routing = {
      enabled = true
    }
  }
}
