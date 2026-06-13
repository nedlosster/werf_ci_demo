# Управление секретами

Пароли продуктов -- БД и pgAdmin -- хранятся в репозитории в зашифрованном виде и
расшифровываются werf при выкатке. Эта статья описывает, как устроено шифрование:
где лежат зашифрованные значения, по какому ключу werf их читает, как контур
подмешивает секреты в релиз и что нельзя коммитить. Настройка и ротация ключа
даны кратко -- детальный сценарий планируется в
[runbook настройки секретов](../runbooks/secrets-setup.md). Поток выкатки, в
котором секреты подмешиваются, разобран в [Доставке в Kubernetes](../concepts/delivery-to-k8s.md);
исходный набор файлов -- в `apps/<product>/.helm/secrets/readme.md`.

## Что шифруется и где лежит

Секреты продукта -- пароль БД и учётные данные pgAdmin -- хранятся
зашифрованными в `.helm/secrets-<env>.yaml` (`secrets-dev.yaml`,
`secrets-prod.yaml`). Эти файлы коммитятся: их содержимое зашифровано и без ключа
бесполезно. Раскладка файлов:

| Файл | В git | Назначение |
|---|---|---|
| `.helm/secret-values.yaml.example` | да | шаблон с плейсхолдерами `CHANGE_ME` |
| `.helm/secrets-<env>.yaml` | да (зашифрован) | секреты окружения dev/prod |
| `.helm/secrets/values.yaml` | нет (`.gitignore`) | plaintext для редактирования |
| `.helm/secrets/{encrypt,decrypt}.sh` | да | обёртки шифрования |

Plaintext-копия `secrets/values.yaml` и сам ключ в git не попадают -- они в
[`.gitignore`](../../.gitignore). Шаблон
[`secret-values.yaml.example`](../../apps/app1-java-react/.helm/secret-values.yaml.example)
показывает структуру (`secrets.dbPassword`, `secrets.pgadminEmail`,
`secrets.pgadminPassword`) с заглушками вместо реальных значений.

## Ключ шифрования

Шифрует и расшифровывает значения werf по симметричному ключу. werf ищет ключ по
приоритету:

1. переменная окружения `WERF_SECRET_KEY`;
2. файл `.werf_secret_key` в корне продукта (в `.gitignore`);
3. стандартный файл ключа в домашнем каталоге `~/.werf/` (точное имя и полный
   порядок поиска -- в
   [памятке продукта](../../apps/app1-java-react/.helm/secrets/readme.md)).

Создать ключ -- `werf helm secret generate-secret-key`, дальше положить вывод в
один из этих путей. Ключ в репозиторий не коммитится ни в каком виде:
владелец ключа читает все секреты продукта, а его компрометация обесценивает
шифрование разом. Конкретное значение ключа в документации не приводится.

## Рабочий цикл

Создание секретов из шаблона:

```bash
cd .helm/secrets
cp ../secret-values.yaml.example values.yaml   # plaintext, в .gitignore
vim values.yaml                                # заполнить значения
./encrypt.sh dev                               # -> ../secrets-dev.yaml (зашифрован)
```

[`encrypt.sh`](../../apps/app1-java-react/.helm/secrets/encrypt.sh) вызывает
`werf helm secret values encrypt` и кладёт результат в `secrets-<env>.yaml`.
Правка существующих значений -- через
[`decrypt.sh`](../../apps/app1-java-react/.helm/secrets/decrypt.sh): он
расшифровывает `secrets-<env>.yaml` обратно в `values.yaml`, после правки файл
снова шифруют `encrypt.sh`. Аргумент скриптов -- окружение (`dev` по умолчанию,
допустимо `prod`).

## Как секрет попадает в релиз

При выкатке функция `deploy()` из
[`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh)
автоматически добавляет `--secret-values=.helm/secrets-<ENVNAME>.yaml`, если файл
есть. werf расшифровывает значения по ключу прямо в ходе converge и подставляет
их в чарт как `.Values.secrets.*`. Шаблон
[`011-secret.yaml`](../../apps/app1-java-react/.helm/templates/011-secret.yaml)
заводит из них Kubernetes-Secret'ы (`DB_PASSWORD`, `PGADMIN_DEFAULT_EMAIL`,
`PGADMIN_DEFAULT_PASSWORD`). Если `secrets-<env>.yaml` не задан, чарт берёт
демо-дефолты из `values.yaml` -- это допустимо только для показа, не для прода.

## Настройка и ротация

Первичная настройка сводится к созданию ключа, его размещению в одном из путей
поиска и шифрованию `values.yaml` в `secrets-<env>.yaml`. Ротация ключа -- это
перешифровка: расшифровать секреты старым ключом (`decrypt.sh`), сменить ключ,
зашифровать заново (`encrypt.sh`) и закоммитить обновлённые `secrets-<env>.yaml`.
Развёрнутый пошаговый сценарий настройки и ротации планируется отдельным
[runbook'ом](../runbooks/secrets-setup.md).

## Плюсы, минусы, безопасность

Плюсы. Зашифрованные секреты лежат рядом с кодом и версионируются git, без
внешнего секрет-хранилища; werf подмешивает их в converge без ручных шагов.

Минусы. Подход рассчитан на один ключ на продукт без встроенной ротации и
разграничения доступа по полям; смена ключа требует ручной перешифровки всех
`secrets-<env>.yaml`.

Безопасность. Риск сосредоточен в ключе: хранение его на машине сборки и
отсутствие ротации повышают цену компрометации. Смягчение -- держать ключ в
защищённом хранилище CI (masked/protected-переменная, см.
[Подключение к GitLab CI](../integrations/gitlab-ci.md)), ограничивать доступ и
регулярно ротировать. Демо-дефолты паролей в `values.yaml` -- только для показа.
Полный разбор -- в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [Один контур, два окружения](dev-prod.md)
- [Операции kube_ci](kube-ci-operations.md)
- [Версионирование](versioning.md)
- [Доставка в Kubernetes](../concepts/delivery-to-k8s.md)
- [Компромиссы и безопасность схемы](../concepts/security-and-tradeoffs.md)
- [pgAdmin](../products/pgadmin.md)
- [Подключение к GitLab CI](../integrations/gitlab-ci.md)
