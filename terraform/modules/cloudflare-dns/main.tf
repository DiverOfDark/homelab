resource "cloudflare_record" "dns_records" {
  for_each = { for idx, record in var.dns_records : idx => record }

  zone_id  = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = each.value.ttl
  proxied = each.value.proxied
}