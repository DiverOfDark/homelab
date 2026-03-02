variable "zone_id" {
  type        = string
  description = "Cloudflare zone ID"
}

variable "dns_records" {
  type = list(object({
    name    = string
    type    = string
    content = string
    ttl     = number
    proxied = bool
  }))
  description = "List of DNS records to create"
  default = []
}