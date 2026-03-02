output "zitadel_project_id" {
  value       = zitadel_project.homelab.id
  description = "Created ZITADEL project ID"
}

output "argocd_client_id" {
  value       = zitadel_application_oidc.argocd.client_id
  sensitive   = true
  description = "ArgoCD OIDC client_id"
}

output "openbao_secret_ref" {
  value       = "${var.openbao_kv_mount}/${var.openbao_secret_path}"
  description = "OpenBao KV reference where OIDC creds were saved"
}
