variable "account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "tunnel_name" {
  type        = string
  description = "Tunnel name"
  default     = "k8s"
}

variable "tunnel_secret" {
  type        = string
  sensitive   = true
  description = "Tunnel secret"
}

variable "ingress_rules" {
  type = list(object({
    hostname = string
    service  = string
  }))
  description = "Ingress rules for tunnel"
  default = []
}