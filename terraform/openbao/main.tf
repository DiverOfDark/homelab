resource "zitadel_project" "homelab" {
  name = var.project_name
}

resource "zitadel_application_oidc" "argocd" {
  project_id                  = zitadel_project.homelab.id
  name                        = var.client_name
  redirect_uris               = var.argocd_redirect_uris
  response_types              = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types                 = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE", "OIDC_GRANT_TYPE_REFRESH_TOKEN"]
  app_type                    = "OIDC_APP_TYPE_WEB"
  auth_method_type            = "OIDC_AUTH_METHOD_TYPE_BASIC"
  post_logout_redirect_uris   = var.argocd_post_logout_redirect_uris
  dev_mode                    = var.zitadel_dev_mode
  access_token_type           = "OIDC_TOKEN_TYPE_BEARER"
  access_token_role_assertion = false
  id_token_role_assertion     = false
  id_token_userinfo_assertion = false
}

resource "vault_kv_secret_v2" "argocd_oidc" {
  mount = var.openbao_kv_mount
  name  = var.openbao_secret_path

  data_json = jsonencode({
    client_id     = zitadel_application_oidc.argocd.client_id
    client_secret = zitadel_application_oidc.argocd.client_secret
    project_id    = zitadel_project.homelab.id
    project_name  = var.project_name
    issuer        = var.zitadel_issuer
    created_by    = "opentofu"
  })
}
