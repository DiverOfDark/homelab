variable "cloudflare_email" {
  type        = string
  description = "Cloudflare account email"
  default     = "diverofdark@gmail.com"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "tunnel_secret" {
  type        = string
  description = "Cloudflare Tunnel secret"
  sensitive   = true
}

variable "kube_config" {
  type        = string
  description = "Path to kubeconfig file"
  default     = "~/.kube/config"
}

variable "zone_name" {
  type        = string
  description = "Cloudflare zone name"
  default     = "kirillorlov.pro"
}

variable "dns_records" {
  description = "DNS records managed outside tunnel-generated records"
  type = list(object({
    name    = string
    type    = string
    content = string
    ttl     = number
    proxied = bool
  }))
  default = [
    {
      name    = "uptime"
      type    = "CNAME"
      content = "diverofdark.github.io"
      ttl     = 1
      proxied = false
    }
  ]
}

variable "ingress_rules" {
  description = "Cloudflare tunnel ingress rules"
  type = list(object({
    short          = string
    hostname       = string
    service        = string
    proxied        = bool
    originRequest  = optional(object({
      noTLSVerify = optional(bool)
    }))
  }))
  default = [
    {
      short    = "kirillorlov.pro"
      hostname = "kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
      proxied  = true
    },
    {
      short    = "www"
      hostname = "www.kirillorlov.pro"
      service  = "http://homepage.nextcloud.svc.cluster.local"
      proxied  = true
    },
    {
      short    = "cloud"
      hostname = "cloud.kirillorlov.pro"
      service  = "http://nextcloud.nextcloud.svc.cluster.local"
      proxied  = true
    },
    {
      short    = "bonsai"
      hostname = "bonsai.kirillorlov.pro"
      service  = "http://bonsai.bonsai.svc.cluster.local"
      proxied  = true
    },
    {
      short    = "auth"
      hostname = "auth.kirillorlov.pro"
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      proxied  = true
      originRequest = {
        noTLSVerify = true
      }
    },
    {
      short    = "status"
      hostname = "status.kirillorlov.pro"
      service  = "http://homepage.statuspage.svc.cluster.local:3000"
      proxied  = true
    },
    {
      short    = "vaultwarden"
      hostname = "vaultwarden.kirillorlov.pro"
      service  = "http://vaultwarden.vaultwarden.svc.cluster.local"
      proxied  = true
    },
    {
      short    = "dex"
      hostname = "dex.kirillorlov.pro"
      service  = "http://dex.oauth2-proxy.svc.cluster.local:5556"
      proxied  = true
    },
    {
      short    = "logto"
      hostname = "logto.kirillorlov.pro"
      service  = "http://logto.logto.svc.cluster.local:3001"
      proxied  = true
    },
    {
      short    = "ai"
      hostname = "ai.kirillorlov.pro"
      service  = "http://lobechat.lobechat.svc.cluster.local:80"
      proxied  = true
    },
    {
      short    = "search"
      hostname = "search.kirillorlov.pro"
      service  = "http://searxng.lobechat.svc.cluster.local:80"
      proxied  = true
    },
    {
      short    = "money"
      hostname = "money.kirillorlov.pro"
      service  = "http://actualbudget.actualbudget.svc.cluster.local:80"
      proxied  = true
    }
  ]
}

variable "email_routing_rules" {
  type = list(object({
    name    = string
    to      = string
    enabled = bool
  }))
  default = [
    {
      name    = "i@kirillorlov.pro"
      to      = "diverofdark@gmail.com"
      enabled = true
    },
    {
      name    = "me@kirillorlov.pro"
      to      = "diverofdark@gmail.com"
      enabled = true
    }
  ]
}
