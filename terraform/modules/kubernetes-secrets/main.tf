resource "kubernetes_secret" "cloudflared_config" {
  metadata {
    namespace = var.namespace
    name      = "cloudflare-api-token-secret"
  }

  data = {
    account-id  = var.cloudflare_account_id
    api-token   = var.cloudflare_api_token
    tunnel-id   = var.tunnel_id
    tunnelToken = var.tunnel_token
  }
}

resource "kubernetes_secret" "certmanager_config" {
  metadata {
    namespace = var.certmanager_namespace
    name      = "cloudflare-api-token-secret"
  }

  data = {
    account-id = var.cloudflare_account_id
    api-token  = var.cloudflare_api_token
    tunnel-id  = var.tunnel_id
  }
}

resource "kubernetes_service_account" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = var.namespace
  }
}

resource "kubernetes_role" "cloudflared_role" {
  metadata {
    name      = "cloudflared-role"
    namespace = var.namespace
  }

  rules {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "cloudflared_binding" {
  metadata {
    name      = "cloudflared-role-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cloudflared-role"
  }

  subjects {
    kind      = "ServiceAccount"
    name      = "cloudflared"
    namespace = var.namespace
  }
}

output "cloudflared_config" {
  description = "Cloudflared Kubernetes secret"
  value       = kubernetes_secret.cloudflared_config
}

output "certmanager_config" {
  description = "Cert-manager Kubernetes secret"
  value       = kubernetes_secret.certmanager_config
}

output "service_account" {
  description = "Cloudflared service account"
  value       = kubernetes_service_account.cloudflared
}

output "role" {
  description = "Cloudflared role"
  value       = kubernetes_role.cloudflared_role
}

output "role_binding" {
  description = "Cloudflared role binding"
  value       = kubernetes_role_binding.cloudflared_binding
}
