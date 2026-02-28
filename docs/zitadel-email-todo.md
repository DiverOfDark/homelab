# Задача: Настройка mail sender для Zitadel

## Описание
Необходимо найти и настроить email sender для Zitadel. Zitadel (идентификационная платформа) требует настройки email sender для отправки:
- Подтверждений регистрации
- Сброса паролей
- Уведомлений безопасности
- Прочих системных писем

## Исследовать варианты

### 1. Встроенные возможности Zitadel
- Проверить документацию Zitadel на предмет встроенных email настроек
- Изучить конфигурацию через Helm values или environment variables

### 2. Внешние решения
- **Mailgun**: Managed SMTP service
- **SendGrid**: Cloud-based email platform  
- **Postfix**: Self-hosted SMTP сервер
- **Harbor**: Если уже используется, возможно настроить relay

## Шаги для настройки

### Шаг 1: Исследование
- [ ] Изучить документацию Zitadel по email настройкам
- [ ] Проверить текущий Helm chart для Zitadel
- [ ] Определить, какой вариант предпочтительнее для homelab

### Шаг 2: Выбор решения
- [ ] Встроенные возможности Zitadel + external SMTP
- [ ] Полностью самохостинг (Postfix + DKIM)
- [ ] Managed service (Mailgun/SendGrid)

### Шаг 3: Реализация
- [ ] Создать конфигурацию для выбранного решения
- [ ] Настроить DNS (если требуется SPF/DKIM/DMARC)
- [ ] Протестировать отправку писем

### Шаг 4: Интеграция с ArgoCD
- [ ] Создать ArgoCD Application для нового сервиса
- [ ] Настроить секреты для email credentials
- [ ] Обновить monitoring для email delivery

## Дополнительные требования
- [ ] Настроить email шаблоны (если требуется кастомизация)
- [ ] Включить логирование email отправки
- [ ] Настроить уведомления о проблемах с email delivery

## Файлы для создания
- `k3s-apps/zitadel/email-smtp.yaml` - конфигурация SMTP relay
- `k3s-apps/zitadel/email-secrets.yaml` - secrets для email credentials
- `docs/zitadel-email-setup.md` - документация по настройке

## Примеры команд для тестирования
```bash
# Тестовая отправка письма
kubectl exec -it <zitadel-pod> -- wget -qO- --post-data="to=test@example.com&subject=Test&body=Test message" http://localhost:8080/email/send

# Проверка логов email доставки
kubectl logs -f <zitadel-pod> | grep email
```

## Ссылки для исследования
- [Zitadel Documentation - Email Configuration](https://zitadel.com/docs)
- [Mailgun Setup Guide](https://documentation.mailgun.com/en/latest)
- [Postfix Configuration](https://www.postfix.org/configuration.html)

## Приоритет: Medium
Срок: В ближайшие 2-3 недели