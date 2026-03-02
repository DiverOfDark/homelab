# OpenTofu IaC for Cloudflare (homelab)

Модульная конфигурация OpenTofu для Cloudflare + Kubernetes секретов.

## Structure

```text
terraform/
├── versions.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    ├── cloudflare-zone/
    ├── cloudflare-dns/
    ├── cloudflare-tunnel/
    └── kubernetes-secrets/
```

## Usage

```bash
cd terraform
tofu init
tofu plan
tofu apply
```

Секреты передавай через env:

```bash
export TF_VAR_cloudflare_api_token="..."
export TF_VAR_tunnel_secret="..."
```

## Notes

- Старый монолитный `cloudflare.tf` должен быть удалён.
- Провайдер Cloudflare настроен через `api_token`.
- Ingress rules типизированы, включая optional `originRequest`.
