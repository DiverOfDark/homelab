# OpenBao Provider Configuration
variable "openbao_url" {
  type        = string
  description = "OpenBao instance URL"
}

variable "openbao_root_token" {
  type        = string
  description = "OpenBao root token for authentication"
  sensitive   = true
}

# Project Configuration
variable "project_name" {
  type        = string
  description = "Name of the OpenBao project"
  default     = "homelab"
}

variable "project_description" {
  type        = string
  description = "Description for the OpenBao project"
  default     = "Homelab Infrastructure Project"
}

# ArgoCD OAuth2 Client Configuration
variable "argocd_redirect_uris" {
  type        = list(string)
  description = "List of allowed redirect URIs for ArgoCD OAuth2 client"
}

variable "client_name" {
  type        = string
  description = "Name of the OAuth2 client"
  default     = "argocd"
}

variable "environment" {
  type        = string
  description = "Target environment (dev/prod)"
  default     = "prod"
}

# Kubernetes Configuration
variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for ArgoCD"
  default     = "argocd"
}

# Secrets Configuration
variable "secret_ttl" {
  type        = number
  description = "Time to live for stored secrets in hours"
  default     = 8760  # 1 year
}

# Required providers
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

# Provider configurations
provider "openbao" {
  zitadel_url = var.openbao_url
  api_token   = var.openbao_root_token
}

provider "vault" {
  address = var.openbao_url
  token   = var.openbao_root_token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Enable KV v2 secrets engine
resource "vault_mount" "kv_secrets" {
  path_prefix = "secret"
  type        = "kv"
  options = {
    version = "2"
  }
}

# Create OpenBao project
resource "zitadel_project" "homelab" {
  name        = var.project_name
  description = var.project_description
  
  project_settings {
    allow_list_for_users = false
    allow_list_for_apps  = false
  }
  
  roles {
    role_name     = "admin"
    description   = "Project Administrator"
  }
  
  roles {
    role_name     = "developer"
    description   = "Developer with limited access"
  }
}

# Create OAuth2 client for ArgoCD
resource "zitadel_application_oidc" "argocd" {
  name                = var.client_name
  redirect_uris       = var.argocd_redirect_uris
  trusted_jwt_issuers = []
  allowed_grant_types = ["authorization_code", "refresh_token", "client_credentials"]
  allowed_response_types = ["code"]
  client_id           = "${var.client_name}-${var.environment}"
  
  environment_specific_settings {
    dev {
      redirect_uris = ["https://argocd-dev.example.com/oauth2/callback"]
    }
    prod {
      redirect_uris = var.argocd_redirect_uris
    }
  }
}

# Store credentials in Vault/OpenBao
resource "vault_kv_v2_secret" "argocd_credentials" {
  mount_path = "secret"
  path       = "apps/argocd/${var.environment}/credentials"
  
  data_json = jsonencode({
    client_id     = zitadel_application_oidc.argocd.client_id
    client_secret = zitadel_application_oidc.argocd.client_secret
    project_id    = zitadel_project.homelab.id
    created_at    = timestamp()
    expires_at    = timeadd(timestamp(), "${var.secret_ttl}h")
    environment   = var.environment
    description   = "ArgoCD OAuth2 Client credentials for ${var.project_name} project"
  })
}

# Create Kubernetes ServiceAccount
resource "kubernetes_service_account" "argocd_sa" {
  metadata {
    name      = "argocd-openbao-auth"
    namespace = var.kubernetes_namespace
    
    annotations = {
      "vault.hashicorp.com/agent-inject" = "true"
      "vault.hashicorp.com/role"         = "argocd"
    }
  }
}

# Create Kubernetes Role
resource "kubernetes_role" "argocd_role" {
  metadata {
    name      = "openbao-access"
    namespace = var.kubernetes_namespace
  }
  
  rules {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

# Create Kubernetes RoleBinding
resource "kubernetes_role_binding" "argocd_binding" {
  metadata {
    name      = "argocd-openbao-access"
    namespace = var.kubernetes_namespace
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "openbao-access"
  }
  
  subjects {
    kind      = "ServiceAccount"
    name      = "argocd-openbao-auth"
    namespace = var.kubernetes_namespace
  }
}