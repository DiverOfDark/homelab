variable "openbao_url" {
  type        = string
  description = "OpenBao instance URL"
  default     = "https://openbao.example.com"
  sensitive   = false
}

variable "openbao_root_token" {
  type        = string
  description = "OpenBao root token for authentication"
  sensitive   = true
}

variable "argocd_redirect_uris" {
  type        = list(string)
  description = "List of allowed redirect URIs for ArgoCD OAuth2 client"
  default     = [
    "https://argocd.example.com/oauth2/callback",
    "https://argocd-dev.example.com/oauth2/callback"
  ]
}

variable "project_name" {
  type        = string
  description = "Name of the OpenBao project"
  default     = "homelab"
}

variable "client_name" {
  type        = string
  description = "Name of the OAuth2 client"
  default     = "argocd"
}

variable "project_description" {
  type        = string
  description = "Description for the OpenBao project"
  default     = "Homelab Infrastructure Project"
}

variable "environment" {
  type        = string
  description = "Target environment (dev/prod)"
  default     = "prod"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'"
  }
}

variable "secret_ttl" {
  type        = number
  description = "Time to live for stored secrets in hours"
  default     = 8760  # 1 year
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for ArgoCD"
  default     = "argocd"
}