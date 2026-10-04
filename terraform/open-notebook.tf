# open-notebook (k3s-userapps/open-notebook): generated credentials, stored in
# OpenBao at secret/open-notebook for the in-cluster ExternalSecret.

# Encrypts the AI provider keys saved via the UI. Must stay stable for the
# lifetime of the SurrealDB data — rotating it makes stored keys unreadable.
resource "random_password" "open_notebook_encryption_key" {
  length  = 32
  special = false
}

# Login password for the web UI (the app has no OIDC support).
resource "random_password" "open_notebook_password" {
  length  = 24
  special = false
}

resource "random_password" "open_notebook_surreal" {
  length  = 24
  special = false
}

resource "vault_kv_secret_v2" "open_notebook" {
  mount = "secret"
  name  = "open-notebook"

  data_json = jsonencode({
    encryption_key   = random_password.open_notebook_encryption_key.result
    password         = random_password.open_notebook_password.result
    surreal_password = random_password.open_notebook_surreal.result
  })
}
