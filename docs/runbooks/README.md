# Runbook'и

Раздел собирает пошаговые сценарии эксплуатации: подключение к кластеру,
настройка секретов, первый деплой, публикация, откат версии, снос, разбор
типовых сбоев. Каждый runbook самодостаточен и рассчитан на выполнение по шагам.

Концептуальная база операций -- в [../delivery/](../delivery/README.md).

## Статьи

- [deploy.md](deploy.md) -- публикация, снос и очистка демо в окружениях
  dev / prod.
- [rollback.md](rollback.md) -- откат версии релиза на ранее опубликованную
  ревизию через `helm rollback`, список версий, ограничение по БД.
- [cluster-connection.md](cluster-connection.md) -- подключение к кластеру,
  kubeconfig, контекст kubectl и insecure-registry.
- [secrets-setup.md](secrets-setup.md) -- генерация ключа `WERF_SECRET_KEY`,
  правка зашифрованных значений и ротация ключа.
- [first-deploy.md](first-deploy.md) -- первый деплой продукта с нуля,
  end-to-end, с чеклистом проверки.
- [troubleshooting.md](troubleshooting.md) -- разбор типовых сбоев деплоя.
