variable "namespace" {
  type        = string
  description = "Kubernetes namespace"
  default     = "cloudflared"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "tunnel_id" {
  type        = string
  description = "Tunnel ID"
}

variable "tunnel_token" {
  type        = string
  description = "Tunnel token"
  sensitive   = true
}

variable "certmanager_namespace" {
  type        = string
  description = "Cert-manager namespace"
  default     = "cert-manager"
}