# Cloudflare credentials from OpenBao
# Expected keys: email, api_key, api_token, tunnel_secret
data "vault_kv_secret_v2" "cloudflare" {
  mount = "secret"
  name  = "cloudflare"
}

# Google OAuth credentials from OpenBao
# Expected keys: client_id, client_secret
data "vault_kv_secret_v2" "google_oauth" {
  mount = "secret"
  name  = "google/oauth"
}
