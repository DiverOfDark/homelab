# OpenBao (Vault-compatible) provider
provider "vault" {
  address          = "https://openbao.kirillorlov.pro"
  token            = var.openbao_token
  skip_child_token = true
}

# Read Zitadel service account key from OpenBao
data "vault_kv_secret_v2" "zitadel_key" {
  mount = "secret"
  name  = "zitadel/terraform-token"
}

# Zitadel provider using JWT service account key from OpenBao
provider "zitadel" {
  domain           = "auth.kirillorlov.pro"
  jwt_profile_json = data.vault_kv_secret_v2.zitadel_key.data["sa_jwt_key"]
}

resource "zitadel_project" "homelab" {
  name = "Homelab"
}

resource "zitadel_application_oidc" "argocd" {
  project_id                  = zitadel_project.homelab.id
  name                        = "ArgoCD"
  redirect_uris               = ["https://argo.kirillorlov.pro/auth/callback"]
  post_logout_redirect_uris   = ["https://argo.kirillorlov.pro"]
  response_types              = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types                 = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
  app_type                    = "OIDC_APP_TYPE_WEB"
  auth_method_type            = "OIDC_AUTH_METHOD_TYPE_BASIC"
  version                     = "OIDC_VERSION_1_0"
  access_token_type           = "OIDC_TOKEN_TYPE_JWT"
  access_token_role_assertion = true
  id_token_role_assertion     = true
  id_token_userinfo_assertion = true
}

# Write ArgoCD OIDC credentials back to OpenBao
resource "vault_kv_secret_v2" "argocd_credentials" {
  mount = "secret"
  name  = "zitadel/argocd-credentials"

  data_json = jsonencode({
    client_id     = zitadel_application_oidc.argocd.client_id
    client_secret = zitadel_application_oidc.argocd.client_secret
    issuer        = "https://auth.kirillorlov.pro"
    project_id    = zitadel_project.homelab.id
  })
}
