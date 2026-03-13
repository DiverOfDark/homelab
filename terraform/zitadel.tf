# OpenBao (Vault-compatible) provider
provider "vault" {
  address          = "https://openbao.kirillorlov.pro"
  token            = var.openbao_token
  skip_child_token = true
}

# Read Zitadel service account key from OpenBao
ephemeral "vault_kv_secret_v2" "zitadel_key" {
  mount = "secret"
  name  = "zitadel/terraform-token"
}

# Zitadel provider using JWT service account key from OpenBao
provider "zitadel" {
  domain           = "auth.kirillorlov.pro"
  jwt_profile_json = ephemeral.vault_kv_secret_v2.zitadel_key.data["sa_jwt_key"]
}

resource "zitadel_project" "homelab" {
  name   = "Homelab"
  org_id = var.zitadel_org_id
}

# --- Google Identity Provider ---

resource "zitadel_org_idp_google" "google" {
  org_id              = var.zitadel_org_id
  name                = "Google"
  client_id           = data.vault_kv_secret_v2.google_oauth.data["client_id"]
  client_secret       = data.vault_kv_secret_v2.google_oauth.data["client_secret"]
  scopes              = ["openid", "profile", "email"]
  is_linking_allowed  = true
  is_creation_allowed = false
  is_auto_creation    = false
  is_auto_update      = true
  auto_linking        = "AUTO_LINKING_OPTION_EMAIL"
}

# --- OIDC Applications ---

resource "zitadel_application_oidc" "argocd" {
  org_id                      = var.zitadel_org_id
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

resource "zitadel_application_oidc" "grafana" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Grafana"
  redirect_uris               = ["https://grafana.kirillorlov.pro/login/generic_oauth"]
  post_logout_redirect_uris   = ["https://grafana.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "velero" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Velero"
  redirect_uris               = ["https://velero.kirillorlov.pro/login"]
  post_logout_redirect_uris   = ["https://velero.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "actual_budget" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Actual Budget"
  redirect_uris               = ["https://money.kirillorlov.pro/openid/callback"]
  post_logout_redirect_uris   = ["https://money.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "vaultwarden" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Vaultwarden"
  redirect_uris               = ["https://vaultwarden.kirillorlov.pro/identity/connect/oidc-signin"]
  post_logout_redirect_uris   = ["https://vaultwarden.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "readur" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Readur"
  redirect_uris               = ["https://readur.kirillorlov.pro/auth/callback"]
  post_logout_redirect_uris   = ["https://readur.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "phos" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Phos"
  redirect_uris               = ["https://phos.kirillorlov.pro/api/auth/callback"]
  post_logout_redirect_uris   = ["https://phos.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "phos_android" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Phos Android"
  redirect_uris               = ["dev.phos.android://callback"]
  post_logout_redirect_uris   = ["dev.phos.android://callback"]
  response_types              = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types                 = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
  app_type                    = "OIDC_APP_TYPE_NATIVE"
  auth_method_type            = "OIDC_AUTH_METHOD_TYPE_NONE"
  version                     = "OIDC_VERSION_1_0"
  access_token_type           = "OIDC_TOKEN_TYPE_JWT"
  access_token_role_assertion = true
  id_token_role_assertion     = true
  id_token_userinfo_assertion = true
}

resource "zitadel_application_saml" "ceph_dashboard" {
  org_id       = var.zitadel_org_id
  project_id   = zitadel_project.homelab.id
  name         = "Ceph Dashboard"
  metadata_xml = <<-EOT
<?xml version="1.0"?>
<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
                     entityID="https://ceph.kirillorlov.pro">
    <md:SPSSODescriptor AuthnRequestsSigned="false"
                        WantAssertionsSigned="true"
                        protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <md:NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified</md:NameIDFormat>
        <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                                     Location="https://ceph.kirillorlov.pro/auth/saml2/sso/ceph-dashboard"
                                     index="1" />
    </md:SPSSODescriptor>
</md:EntityDescriptor>
EOT
}

# --- Email Provider (Mailgun SMTP) ---

resource "zitadel_email_provider_smtp" "mailgun" {
  sender_address   = "auth@kirillorlov.pro"
  sender_name      = "Homelab Auth"
  tls              = true
  host             = "smtp.eu.mailgun.org:587"
  user             = data.vault_kv_secret_v2.mailgun.data["user"]
  password         = data.vault_kv_secret_v2.mailgun.data["password"]
  reply_to_address = "auth@kirillorlov.pro"
  description      = "Mailgun SMTP"
  set_active       = true
}

# --- SMS Provider (Twilio) ---

resource "zitadel_sms_provider_twilio" "twilio" {

  sid           = data.vault_kv_secret_v2.twilio.data["sid"]
  sender_number = data.vault_kv_secret_v2.twilio.data["sender_number"]
  token         = data.vault_kv_secret_v2.twilio.data["token"]
  set_active    = true
}

# --- Store all OIDC credentials in OpenBao ---

locals {
  zitadel_apps = {
    argocd        = zitadel_application_oidc.argocd
    grafana       = zitadel_application_oidc.grafana
    velero        = zitadel_application_oidc.velero
    actual_budget = zitadel_application_oidc.actual_budget
    vaultwarden   = zitadel_application_oidc.vaultwarden
    readur        = zitadel_application_oidc.readur
    phos          = zitadel_application_oidc.phos
    phos_android  = zitadel_application_oidc.phos_android
  }
}

resource "vault_kv_secret_v2" "zitadel_credentials" {
  for_each = local.zitadel_apps

  mount = "secret"
  name  = "zitadel/${each.key}-credentials"

  data_json = jsonencode({
    client_id     = each.value.client_id
    client_secret = each.value.client_secret
    issuer        = "https://auth.kirillorlov.pro"
    project_id    = zitadel_project.homelab.id

  })
}
