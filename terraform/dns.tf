resource "cloudflare_dns_record" "records" {
  for_each = { for rules in local.ingress_rules: rules.short => rules }
  name    = each.value.short

  zone_id = cloudflare_zone.zone.id
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
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
