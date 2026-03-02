output "account_id" {
  description = "Cloudflare account ID"
  value       = cloudflare_account.account.id
}

output "zone_id" {
  description = "Cloudflare zone ID"
  value       = cloudflare_zone.zone.id
}

output "account_name" {
  description = "Cloudflare account name"
  value       = cloudflare_account.account.name
}

output "zone_name" {
  description = "Cloudflare zone name"
  value       = cloudflare_zone.zone.zone
}