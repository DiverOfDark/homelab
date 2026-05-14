provider "bunnynet" {
  api_key = data.vault_kv_secret_v2.bunny.data["api_key"]
}

resource "bunnynet_storage_zone" "homelab" {
  name      = "diverofdark-homelab-backups"
  region    = "DE"
  zone_tier = "Standard"
  type      = "S3"
}

# S3-compatible credentials for the storage zone, written back to OpenBao so
# workloads (ESO/Velero/CNPG) can consume them. For Bunny's S3 API the access
# key is the storage zone name and the secret key is the zone password.
resource "vault_kv_secret_v2" "bunny_storage" {
  mount = "secret"
  name  = "bunny/storage"

  data_json = jsonencode({
    access_key         = bunnynet_storage_zone.homelab.name
    secret_key         = bunnynet_storage_zone.homelab.password
    read_only_password = bunnynet_storage_zone.homelab.password_readonly
    hostname           = bunnynet_storage_zone.homelab.hostname
  })
}
