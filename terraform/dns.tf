# Legacy path: proxied CNAME -> cloudflared tunnel. Hostnames listed in
# local.migrated_hostnames are excluded — they get DNS-only A records to the
# Hetzner edge below.
resource "cloudflare_dns_record" "records" {
  for_each = { for rules in local.ingress_rules : rules.short => rules if !contains(local.migrated_hostnames, rules.short) }
  name    = each.value.short

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# New path: DNS-only WILDCARD A -> midgard (traefik-external). Covers every
# subdomain without a more-specific record (headscale, the remaining tunnel
# CNAMEs for auth/appbahn, and mail records all win over the wildcard).
# Actual exposure is controlled by the kirillorlov.pro/expose=external
# ingress label (Kyverno generates the traefik-external ingress); names
# without one just get traefik-external's default-cert 404.
resource "cloudflare_dns_record" "public_wildcard" {
  name    = "*"
  zone_id = cloudflare_zone.zone.id
  type    = "A"
  content = hcloud_primary_ip.midgard_v4.ip_address
  ttl     = 300
  proxied = false
}

# Wildcards don't cover the zone apex.
resource "cloudflare_dns_record" "public_apex" {
  name    = "kirillorlov.pro"
  zone_id = cloudflare_zone.zone.id
  type    = "A"
  content = hcloud_primary_ip.midgard_v4.ip_address
  ttl     = 300
  proxied = false
}

# The apex A record already exists in state under the old per-hostname
# resource — rename instead of destroy+create (avoids the 81054 create/delete
# race we hit during the first flip).
moved {
  from = cloudflare_dns_record.public_a["kirillorlov.pro"]
  to   = cloudflare_dns_record.public_apex
}

resource "cloudflare_dns_record" "backup" {
  name    = "yggdrasil"

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "backup-s" {
  name    = "yggdrasil-s"

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.yggdrasil.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# headscale on bifrost — MUST be DNS-only (tailscale control + DERP cannot sit
# behind the Cloudflare proxy).
resource "cloudflare_dns_record" "headscale" {
  name    = "headscale"
  zone_id = cloudflare_zone.zone.id
  type    = "A"
  content = hcloud_primary_ip.bifrost_v4.ip_address
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "uptime1" {
    name = "uptime"
    zone_id = cloudflare_zone.zone.id
    type = "CNAME"
    content = "diverofdark.github.io"
    ttl = 1
    proxied = false
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = cloudflare_zone.zone.id
  content = "v=DMARC1; p=none; rua=mailto:aae0da00a1dc4478bfd42740df319d8f@dmarc-reports.cloudflare.net,mailto:dmarc@kirillorlov.pro; aspf=r;"
  name    = "_dmarc"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_dns_record" "mailgun-txt" {
  zone_id = cloudflare_zone.zone.id
  content = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8FNoH2XVc2hlcoBoalxE9K1Q71wEGvwS2gtQMMO2yIq6cb+O/aJktZl1LtxOgabmOAyCSOXt2fVbwcZHo4+t+6E4JLHCUQUQ4YAAt4qRp/kdCG/HRi2de768tMUWloOPI4a4/66RxxbQIdwOsUN+MqMP9CIT6zarfOutsDW73vwIDAQAB"
  name    = "s1._domainkey.kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_dns_record" "spf" {
  zone_id = cloudflare_zone.zone.id
  content = "v=spf1 a mx include:_spf.google.com include:_spf.mx.cloudflare.net include:mailgun.org ~all"
  name    = "kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "TXT"
}

resource "cloudflare_dns_record" "email-cname" {
  zone_id = cloudflare_zone.zone.id
  content = "eu.mailgun.org"
  name    = "email.kirillorlov.pro"
  proxied = false
  ttl     = 1
  type    = "CNAME"
}
