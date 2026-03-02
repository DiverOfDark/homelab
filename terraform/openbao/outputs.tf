output "project_id" {
  description = "ID of the created OpenBao project"
  value       = zitadel_project.homelab.id
}

output "project_name" {
  description = "Name of the created OpenBao project"
  value       = zitadel_project.homelab.name
}

output "client_id" {
  description = "Client ID of the created ArgoCD OAuth2 client"
  value       = zitadel_application_oidc.argocd.client_id
  sensitive   = true
}

output "client_secret" {
  description = "Client secret of the created ArgoCD OAuth2 client"
  value       = zitadel_application_oidc.argocd.client_secret
  sensitive   = true
}

output "secret_path" {
  description = "Vault/OpenBao secret path where credentials are stored"
  value       = vault_kv_v2_secret.argocd_credentials.path
}

output "service_account_name" {
  description = "Name of the created Kubernetes ServiceAccount"
  value       = kubernetes_service_account.argocd_sa.metadata.0.name
}

output "service_account_namespace" {
  description = "Namespace of the created Kubernetes ServiceAccount"
  value       = kubernetes_service_account.argocd_sa.metadata.0.namespace
}

output "argo_oauth_config" {
  description = "Complete OAuth2 configuration for ArgoCD"
  value = {
    client_id     = zitadel_application_oidc.argocd.client_id
    client_secret = zitadel_application_oidc.argocd.client_secret
    redirect_uris = zitadel_application_oidc.argocd.redirect_uris
    token_endpoint = "${var.openbao_url}/oauth2/token"
    auth_endpoint = "${var.openbao_url}/oauth2/auth"
  }
  sensitive   = true
}

output "terraform_state" {
  description = "Terraform state information"
  value = {
    project_created = zitadel_project.homelab.id != null
    client_created  = zitadel_application_oidc.argocd.client_id != null
    secrets_stored  = vault_kv_v2_secret.argocd_credentials.path != null
  }
}

# Output for verification
output "verification_commands" {
  description = "Commands to verify the setup"
  value = [
    "echo 'OpenBao Project created:'",
    "echo 'Project ID: ${zitadel_project.homelab.id}'",
    "echo 'Project Name: ${zitadel_project.homelab.name}'",
    "",
    "echo 'ArgoCD OAuth2 Client created:'",
    "echo 'Client ID: ${zitadel_application_oidc.argocd.client_id}'",
    "echo 'Redirect URIs: ${join(", ", zitadel_application_oidc.argocd.redirect_uris)}'",
    "",
    "echo 'Credentials stored in:'",
    "echo 'Path: ${vault_kv_v2_secret.argocd_credentials.path}'",
    "",
    "echo 'Kubernetes ServiceAccount created:'",
    "echo 'Name: ${kubernetes_service_account.argocd_sa.metadata.0.name}'",
    "echo 'Namespace: ${kubernetes_service_account.argocd_sa.metadata.0.namespace}'",
    "",
    "echo 'To test the setup:'",
    "curl -X POST '${var.openbao_url}/oauth2/token' \\",
    "  -H 'Content-Type: application/x-www-form-urlencoded' \\",
    "  -d 'grant_type=client_credentials&client_id=${zitadel_application_oidc.argocd.client_id}&client_secret=${zitadel_application_oidc.argocd.client_secret}'"
  ]
}

output "next_steps" {
  description = "Next steps for configuration"
  value = [
    "1. Update ArgoCD configuration to use the OAuth2 client:",
    "   - Set OIDC client ID: ${zitadel_application_oidc.argocd.client_id}",
    "   - Set OIDC client secret: [stored in OpenBao]",
    "   - Set redirect URI: ${var.argocd_redirect_uris[0]}",
    "",
    "2. Configure ArgoCD to use OpenBao as identity provider:",
    "   - Enable OIDC authentication",
    "   - Configure client credentials flow",
    "   - Set appropriate scopes",
    "",
    "3. Test the authentication flow:",
    "   - Access ArgoCD UI",
    "   - Click 'Login with OpenBao'",
    "   - Verify successful authentication",
    "",
    "4. Update Kubernetes RBAC if needed:",
    "   - ArgoCD service account permissions",
    "   - OpenBao project roles",
    "   - Secret access policies"
  ]
}