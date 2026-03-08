resource "kubernetes_secret_v1" "cloudflared_config" {
  metadata {
    namespace = "cloudflared"
    name = "cloudflare-api-token-secret"
  }
  data = {
    account-id = cloudflare_account.account.id
    api-token = data.vault_kv_secret_v2.cloudflare.data["api_token"]
    tunnel-id = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
    tunnelToken = base64encode(jsonencode({
      a = cloudflare_account.account.id
      t = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
      s = base64encode(data.vault_kv_secret_v2.cloudflare.data["tunnel_secret"])
    }))
  }
}

resource "kubernetes_secret_v1" "certmanager_config" {
  metadata {
    namespace = "cert-manager"
    name = "cloudflare-api-token-secret"
  }
  data = {
    account-id = cloudflare_account.account.id
    api-token = data.vault_kv_secret_v2.cloudflare.data["api_token"]
    tunnel-id = cloudflare_zero_trust_tunnel_cloudflared.kubernetes_account.id
  }
}
