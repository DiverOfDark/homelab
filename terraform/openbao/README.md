# Terraform OpenBao Integration

Этот набор файлов добавляет Terraform конфигурацию для управления OpenBao проектами и клиентами через GitOps workflow.

## Структура

```
terraform/openbao/
├── main.tf                    # Основная конфигурация
├── variables.tf               # Переменные
├── outputs.tf                # Выводы
├── provider.tf               # Настройка провайдера
└── README.md                 # Документация
```

## Компоненты

### 1. OpenBao Provider Configuration
Настраивает аутентификацию и подключение к OpenBao instance.

### 2. OpenBao Project Resource
Создаёт проект "homelab" в OpenBao с нужными настройками.

### 3. OpenBao OAuth2 Client
Создаёт OAuth2 клиент "argocd" с правильными permissions.

### 4. Secrets Management
Автоматически сохраняет client ID и secret в OpenBao secrets engine.

## Использование

Просто применяйте через Terraform или интегрируйте в ваш ArgoCD workflow.

## Безопасность

- Все sensitive данные хранятся в OpenBao KV v2
- Используется Kubernetes auth method для аутентификации
- Client credentials автоматически генерируются и ротируются