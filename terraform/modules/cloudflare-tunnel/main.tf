resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  account_id = var.account_id
  name       = var.tunnel_name
  secret     = base64encode(var.tunnel_secret)
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id

  config {
    dynamic "ingress_rule" {
      for_each = var.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }
    
    # Default 404 response
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_virtual_network" "default_network" {
  account_id         = var.account_id
  name               = "HomeNetwork"
  is_default_network = true
}

resource "cloudflare_zero_trust_tunnel_route" "home_network" {
  account_id         = var.account_id
  tunnel_id          = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
  network            = "192.168.0.0/16"
  comment            = "HomeNetwork route"
  virtual_network_id = cloudflare_zero_trust_tunnel_virtual_network.default_network.id
}

output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
}

output "tunnel_token" {
  description = "Cloudflare tunnel token"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.tunnel_token
  sensitive   = true
}

output "cname" {
  description = "Cloudflare tunnel CNAME"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.cname
}