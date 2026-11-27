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

# The registrar must delegate appbahn.cloud to these name servers.
output "appbahn_name_servers" {
  value = cloudflare_zone.appbahn.name_servers
}
