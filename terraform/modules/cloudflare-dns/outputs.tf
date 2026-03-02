output "dns_records" {
  description = "Created DNS records"
  value       = cloudflare_record.dns_records
}

output "record_ids" {
  description = "IDs of created records"
  value       = [for record in cloudflare_record.dns_records : record.id]
}