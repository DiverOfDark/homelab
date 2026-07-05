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

# Cloudflare provider credentials from OpenBao (ephemeral — feeds only the
# provider config). Keys that land in state-persisted resource attributes
# (api_token, tunnel_secret) come in as TF_VARs instead — see flake.nix — since
# ephemeral values are rejected there.
# Expected keys: email, api_key, api_token, tunnel_secret
ephemeral "vault_kv_secret_v2" "cloudflare" {
  mount = "secret"
  name  = "cloudflare"
}

# Wasabi credentials from OpenBao (ephemeral — only feeds the aws provider
# config, never persisted to state/plan)
# Expected keys: access_key, secret_key
ephemeral "vault_kv_secret_v2" "wasabi" {
  mount = "secret"
  name  = "wasabi"
}

# Bunny.net API key from OpenBao (ephemeral — only feeds the provider config)
# Expected keys: api_key
ephemeral "vault_kv_secret_v2" "bunny" {
  mount = "secret"
  name  = "bunny"
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
