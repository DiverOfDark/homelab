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

# The zitadel provider has no write-only attributes, so these secrets sit in
# regular state-persisted arguments — they come in as TF_VARs from OpenBao
# (exported by flake.nix) instead of deprecated vault data sources.
variable "google_oauth_client_id" {
  description = "Google OAuth client id (OpenBao secret/google/oauth; exported by flake.nix)"
  type        = string
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret (OpenBao secret/google/oauth; exported by flake.nix)"
  type        = string
  sensitive   = true
}

variable "mailgun_user" {
  description = "Mailgun SMTP user (OpenBao secret/mailgun; exported by flake.nix)"
  type        = string
}

variable "mailgun_password" {
  description = "Mailgun SMTP password (OpenBao secret/mailgun; exported by flake.nix)"
  type        = string
  sensitive   = true
}

variable "twilio_sid" {
  description = "Twilio SID (OpenBao secret/twilio; exported by flake.nix)"
  type        = string
  sensitive   = true
}

variable "twilio_token" {
  description = "Twilio token (OpenBao secret/twilio; exported by flake.nix)"
  type        = string
  sensitive   = true
}

variable "twilio_sender_number" {
  description = "Twilio sender number (OpenBao secret/twilio; exported by flake.nix)"
  type        = string
}

resource "zitadel_project" "homelab" {
  name   = "Homelab"
  org_id = var.zitadel_org_id
}

# --- Google Identity Provider ---



resource "zitadel_org_idp_google" "google" {
  org_id              = var.zitadel_org_id
  name                = "Google"
  client_id           = var.google_oauth_client_id
  client_secret       = var.google_oauth_client_secret
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
  redirect_uris               = ["dev.phos.android://callback", "http://localhost:3000/callback"]
  post_logout_redirect_uris   = ["dev.phos.android://callback", "http://localhost:3000"]
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

resource "zitadel_application_oidc" "appbahn_platform" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "AppBahn Platform"
  redirect_uris               = ["https://appbahn.kirillorlov.pro/login/oauth2/code/appbahn"]
  post_logout_redirect_uris   = ["https://appbahn.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "headscale" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Headscale"
  redirect_uris               = ["https://headscale.kirillorlov.pro/oidc/callback"]
  post_logout_redirect_uris   = ["https://headscale.kirillorlov.pro"]
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

resource "zitadel_application_oidc" "headplane" {
  org_id                      = var.zitadel_org_id
  project_id                  = zitadel_project.homelab.id
  name                        = "Headplane"
  redirect_uris               = ["https://headplane.kirillorlov.pro/admin/oidc/callback"]
  post_logout_redirect_uris   = ["https://headplane.kirillorlov.pro/admin"]
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

resource "zitadel_application_saml" "ceph_dashboard" {
  org_id       = var.zitadel_org_id
  project_id   = zitadel_project.homelab.id
  name         = "Ceph Dashboard"
  metadata_xml = <<-EOT
<?xml version="1.0"?>
<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
                     entityID="https://ceph.kirillorlov.pro/auth/saml2/metadata">
    <md:SPSSODescriptor AuthnRequestsSigned="false"
                        WantAssertionsSigned="false"
                        protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <md:NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</md:NameIDFormat>
        <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                                     Location="https://ceph.kirillorlov.pro/auth/saml2"
                                     index="1" />
        <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                                Location="https://ceph.kirillorlov.pro/auth/saml2/logout" />
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
  user             = var.mailgun_user
  password         = var.mailgun_password
  reply_to_address = "auth@kirillorlov.pro"
  description      = "Mailgun SMTP"
  set_active       = true
}

# --- SMS Provider (Twilio) ---

resource "zitadel_sms_provider_twilio" "twilio" {

  sid           = var.twilio_sid
  sender_number = var.twilio_sender_number
  token         = var.twilio_token
  set_active    = true
}

# --- Store all OIDC credentials in OpenBao ---

locals {
  zitadel_apps = {
    argocd           = zitadel_application_oidc.argocd
    grafana          = zitadel_application_oidc.grafana
    velero           = zitadel_application_oidc.velero
    actual_budget    = zitadel_application_oidc.actual_budget
    vaultwarden      = zitadel_application_oidc.vaultwarden
    readur           = zitadel_application_oidc.readur
    phos             = zitadel_application_oidc.phos
    phos_android     = zitadel_application_oidc.phos_android
    appbahn_platform = zitadel_application_oidc.appbahn_platform
    harbor           = zitadel_application_oidc.harbor
    # Consumed by ansible (roles/headscale) via `bao kv get secret/zitadel/headscale-credentials`
    headscale        = zitadel_application_oidc.headscale
    # Consumed in-cluster by ESO (k3s-userapps/headplane/externalsecret.yaml)
    headplane        = zitadel_application_oidc.headplane
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

