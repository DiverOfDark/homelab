variable "zitadel_domain" {
  description = "ZITADEL domain, e.g. auth.example.com"
  type        = string
}

variable "zitadel_port" {
  description = "ZITADEL port"
  type        = string
  default     = "443"
}

variable "zitadel_insecure" {
  description = "Disable TLS validation for local/dev only"
  type        = bool
  default     = false
}

variable "zitadel_jwt_profile_file" {
  description = "Path to ZITADEL service user key file (JSON)"
  type        = string
}

variable "zitadel_issuer" {
  description = "OIDC issuer URL used by ArgoCD"
  type        = string
}

variable "zitadel_dev_mode" {
  description = "Set true only for local testing"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "ZITADEL project name"
  type        = string
  default     = "homelab"
}

variable "client_name" {
  description = "ZITADEL OIDC app name"
  type        = string
  default     = "argocd"
}

variable "argocd_redirect_uris" {
  description = "Allowed ArgoCD callback URIs"
  type        = list(string)
}

variable "argocd_post_logout_redirect_uris" {
  description = "Allowed ArgoCD post logout redirect URIs"
  type        = list(string)
  default     = []
}

variable "openbao_addr" {
  description = "OpenBao/Vault API address"
  type        = string
}

variable "openbao_token" {
  description = "OpenBao token with write access to KV path"
  type        = string
  sensitive   = true
}

variable "openbao_kv_mount" {
  description = "KV v2 mount in OpenBao"
  type        = string
  default     = "secret"
}

variable "openbao_secret_path" {
  description = "Path where argocd OIDC credentials are stored"
  type        = string
  default     = "apps/argocd/oidc"
}
