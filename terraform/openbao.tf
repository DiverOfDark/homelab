# ESO policy and role
resource "vault_policy" "eso" {
  name   = "eso-policy"
  policy = <<-EOT
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  backend                          = "kubernetes"
  role_name                        = "eso-role"
  bound_service_account_names      = ["eso-external-secrets"]
  bound_service_account_namespaces = ["eso"]
  token_policies                   = [vault_policy.eso.name]
}

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

# Mailgun SMTP credentials from OpenBao
# Expected keys: user, password
data "vault_kv_secret_v2" "mailgun" {
  mount = "secret"
  name  = "mailgun"
}

# Twilio credentials from OpenBao
# Expected keys: sid, token, sender_number
data "vault_kv_secret_v2" "twilio" {
  mount = "secret"
  name  = "twilio"
}

# OpenBao backup read-only policy and role
resource "vault_policy" "openbao_backup" {
  name   = "openbao-backup-policy"
  policy = <<-EOT
    path "secret/metadata" {
      capabilities = ["list", "read"]
    }
    path "secret/metadata/*" {
      capabilities = ["list", "read"]
    }
    path "secret/data/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "openbao_backup" {
  backend                          = "kubernetes"
  role_name                        = "openbao-backup-role"
  bound_service_account_names      = ["openbao-backup-sa"]
  bound_service_account_namespaces = ["openbao-backup"]
  token_policies                   = [vault_policy.openbao_backup.name]
  token_ttl                        = 600
}
