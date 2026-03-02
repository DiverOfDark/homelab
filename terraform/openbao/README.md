# ZITADEL -> OpenBao via OpenTofu

Этот стек делает ровно одно:
1. Создаёт проект `homelab` в ZITADEL
2. Создаёт OIDC client `argocd` в этом проекте
3. Складывает `client_id`/`client_secret` в OpenBao KV v2

## Почему так
- ZITADEL ресурсы создаются провайдером `zitadel`
- OpenBao секреты пишутся провайдером `vault` (OpenBao совместим с Vault API)
- Никакого лишнего Kubernetes/RBAC в этом стеке

## Пример запуска

```bash
cd terraform/openbao

export TF_VAR_zitadel_domain="auth.kirillorlov.pro"
export TF_VAR_zitadel_jwt_profile_file="$HOME/.secrets/zitadel-admin-sa.json"
export TF_VAR_zitadel_issuer="https://auth.kirillorlov.pro"

export TF_VAR_argocd_redirect_uris='["https://argocd.kirillorlov.pro/auth/callback"]'

export TF_VAR_openbao_addr="https://openbao.kirillorlov.pro"
export TF_VAR_openbao_token="..."

# OpenTofu

tofu init
tofu plan
tofu apply
```

После apply секрет лежит в:
`secret/apps/argocd/oidc`
