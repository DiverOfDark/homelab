output "zone_id" {
  description = "Cloudflare zone ID"
  value       = module.cloudflare_zone.zone_id
}

output "account_id" {
  description = "Cloudflare account ID"
  value       = module.cloudflare_zone.account_id
}

output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = module.cloudflare_tunnel.tunnel_id
}

output "tunnel_token" {
  description = "Cloudflare tunnel token"
  value       = module.cloudflare_tunnel.tunnel_token
  sensitive   = true
}

output "cname" {
  description = "Cloudflare tunnel CNAME"
  value       = module.cloudflare_tunnel.cname
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.cloudflare_dns.dns_records
}

output "kubernetes_secrets" {
  description = "Created Kubernetes secrets"
  value       = {
    cloudflared = module.kubernetes_secrets.cloudflared_config
    certmanager = module.kubernetes_secrets.certmanager_config
  }
}

output "zone_name" {
  description = "Cloudflare zone name"
  value       = module.cloudflare_zone.zone_name
}

output "account_name" {
  description = "Cloudflare account name"
  value       = module.cloudflare_zone.account_name
}