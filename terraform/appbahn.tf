# appbahn.cloud: AppBahn's public site, served from midgard (traefik-external)
# like kirillorlov.pro. The site's deployment lives in the private
# DiverOfDark/appbahn-dev repository (deploy/site/), synced by
# k3s-apps/appbahn-site.yaml.
resource "cloudflare_zone" "appbahn" {
  account = {
    id = cloudflare_account.account.id
  }
  name = "appbahn.cloud"
  type = "full"
}

# DNS-only, so traefik-external terminates TLS with the cert-manager
# certificate (DNS-01 through acme-issuer).
resource "cloudflare_dns_record" "appbahn_apex" {
  name    = "appbahn.cloud"
  zone_id = cloudflare_zone.appbahn.id
  type    = "A"
  content = hcloud_primary_ip.midgard_v4.ip_address
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "appbahn_www" {
  name    = "www"
  zone_id = cloudflare_zone.appbahn.id
  type    = "A"
  content = hcloud_primary_ip.midgard_v4.ip_address
  ttl     = 300
  proxied = false
}

# The zone existed before this file (created by hand on 2026-02-07, already
# delegated by the registrar) and was imported; these are its name servers.
output "appbahn_name_servers" {
  value = cloudflare_zone.appbahn.name_servers
}

# appbahn.de and appbahn.eu redirect every request to appbahn.cloud (301,
# path and query kept). They serve nothing themselves: the proxied A records
# point at 192.0.2.1 (TEST-NET-1, never reached) only so Cloudflare's edge
# answers for the names, and a zone redirect rule answers before any origin.
# Both zones existed before this file (created by hand on 2026-02-07, already
# delegated by the registrars) and were imported. Neither sends or receives
# mail: null MX, SPF -all and DMARC reject keep the names from being spoofed.
locals {
  appbahn_redirect_zones = {
    "appbahn.de" = "bbe55ee7442a4e2306a0ac0a00246344"
    "appbahn.eu" = "f6535fb6ac6f9dd74290e753c66ad048"
  }
  appbahn_redirect_hosts = merge([
    for zone in keys(local.appbahn_redirect_zones) : {
      for name in [zone, "www"] : "${zone}/${name}" => { zone = zone, name = name }
    }
  ]...)
  appbahn_no_mail = merge([
    for zone in keys(local.appbahn_redirect_zones) : {
      "${zone}/mx"    = { zone = zone, type = "MX", name = zone, content = ".", priority = 0 }
      "${zone}/spf"   = { zone = zone, type = "TXT", name = zone, content = "\"v=spf1 -all\"", priority = null }
      "${zone}/dmarc" = { zone = zone, type = "TXT", name = "_dmarc", content = "\"v=DMARC1; p=reject;\"", priority = null }
    }
  ]...)
}


resource "cloudflare_zone" "appbahn_redirect" {
  for_each = local.appbahn_redirect_zones
  account = {
    id = cloudflare_account.account.id
  }
  name = each.key
  type = "full"
}

resource "cloudflare_dns_record" "appbahn_redirect" {
  for_each = local.appbahn_redirect_hosts
  zone_id  = cloudflare_zone.appbahn_redirect[each.value.zone].id
  name     = each.value.name
  type     = "A"
  content  = "192.0.2.1"
  ttl      = 1
  proxied  = true
}

resource "cloudflare_dns_record" "appbahn_no_mail" {
  for_each = local.appbahn_no_mail
  zone_id  = cloudflare_zone.appbahn_redirect[each.value.zone].id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  priority = each.value.priority
  ttl      = 3600
  proxied  = false
}

resource "cloudflare_ruleset" "appbahn_redirect" {
  for_each = local.appbahn_redirect_zones
  zone_id  = cloudflare_zone.appbahn_redirect[each.key].id
  name     = "Redirect to appbahn.cloud"
  kind     = "zone"
  phase    = "http_request_dynamic_redirect"
  rules = [{
    ref         = "to_appbahn_cloud"
    description = "Every request to https://appbahn.cloud, same path and query"
    expression  = "true"
    action      = "redirect"
    action_parameters = {
      from_value = {
        status_code           = 301
        preserve_query_string = true
        target_url = {
          expression = "concat(\"https://appbahn.cloud\", http.request.uri.path)"
        }
      }
    }
  }]
}
