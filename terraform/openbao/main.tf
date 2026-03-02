terraform {
  required_providers {
    openbao = {
      source  = "zitadel/zitadel"
      version = "~> 0.4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
  }
}

# OpenBao Provider Configuration
provider "openbao" {
  # Адрес OpenBao instance
  zitadel_url = var.openbao_url
  
  # Аутентификация через root token
  # В production лучше использовать Kubernetes auth method
  api_token = var.openbao_root_token
}

# Vault Provider Configuration for storing secrets
provider "vault" {
  address = var.openbao_url
  
  # Используем тот же токен для Vault/OpenBao
  token = var.openbao_root_token
}

# Kubernetes Provider for cluster info
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Enable KV v2 secrets engine in Vault/OpenBao
resource "vault_mount" "kv_secrets" {
  path_prefix = "secret"
  type        = "kv"
  options = {
    version = "2"
  }
}

# Create OpenBao Project "homelab"
resource "zitadel_project" "homelab" {
  name = "homelab"
  description = "Homelab Infrastructure Project"
  
  # Project settings
  project_settings {
    allow_list_for_users = false
    allow_list_for_apps  = false
  }
  
  # Project roles
  roles {
    role_name = "admin"
    description = "Project Administrator"
  }
  
  roles {
    role_name = "developer"
    description = "Developer with limited access"
  }
}

# Create OAuth2 Client "argocd"
resource "zitadel_application_oidc" "argocd" {
  name                = "argocd"
  redirect_uris       = ["https://argocd.example.com/oauth2/callback"]
  trusted_jwt_issuers = []
  allowed_grant_types = ["authorization_code", "refresh_token", "client_credentials"]
  allowed_response_types = ["code"]
  
  # Client metadata
  client_id = "argocd-client"
  
  # Environment specific settings
  environment_specific_settings {
    dev {
      redirect_uris = ["https://argocd-dev.example.com/oauth2/callback"]
    }
    prod {
      redirect_uris = ["https://argocd.example.com/oauth2/callback"]
    }
  }
}

# Store client credentials in Vault/OpenBao
resource "vault_kv_v2_secret" "argocd_credentials" {
  mount_path = "secret"
  path       = "apps/argocd/credentials"
  
  data_json = jsonencode({
    client_id     = zitadel_application_oidc.argocd.client_id
    client_secret = zitadel_application_oidc.argocd.client_secret
    project_id    = zitadel_project.homelab.id
    created_at    = timestamp()
    
    # Additional metadata
    description = "ArgoCD OAuth2 Client credentials for Homelab project"
    expires_at  = "2027-03-02T00:00:00Z"  # 1 год
  })
}

# Create Kubernetes ServiceAccount for ArgoCD
resource "kubernetes_service_account" "argocd_sa" {
  metadata {
    name      = "argocd-openbao-auth"
    namespace = "argocd"
    
    annotations = {
      "vault.hashicorp.com/agent-inject" = "true"
      "vault.hashicorp.com/agent-inject-secret-args" = "VAULT_ADDR=${var.openbao_url} VAULT_TOKEN=vault:secret/data/apps/argocd/credentials#client_id:VAULT_CLIENT_ID vault:secret/data/apps/argocd/credentials#client_secret:VAULT_CLIENT_SECRET"
      "vault.hashicorp.com/role" = "argocd"
    }
  }
}

# Create Kubernetes Role for ArgoCD
resource "kubernetes_role" "argocd_role" {
  metadata {
    name = "openbao-access"
    namespace = "argocd"
  }
  
  rules {
    api_groups = [""]
    resources = ["secrets"]
    verbs = ["get", "list", "watch"]
  }
}

# Create Kubernetes RoleBinding
resource "kubernetes_role_binding" "argocd_binding" {
  metadata {
    name = "argocd-openbao-access"
    namespace = "argocd"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "openbao-access"
  }
  
  subjects {
    kind = "ServiceAccount"
    name = "argocd-openbao-auth"
    namespace = "argocd"
  }
}