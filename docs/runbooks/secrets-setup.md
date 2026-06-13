---
title: Настройка секретов и ротация ключа
status: stable
last-updated: 2026-06-13
area: runbooks
---

# Runbook: настройка секретов и ротация ключа

Пароли продуктов (БД, pgAdmin) хранятся зашифрованными в
`apps/<product>/.helm/secrets-<env>.yaml` и расшифровываются werf при выкатке по
ключу `WERF_SECRET_KEY`. Этот runbook -- только процедуры: создать ключ,
завести и отредактировать зашифрованные значения, провести ротацию ключа.

Модель секретов werf и раскладка файлов разобраны в
[Управлении секретами](../delivery/secrets.md); риски ключа и общий preprod -- в
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md). Сводка
трёх базовых операций -- в [deploy.md](deploy.md).

Реальные значения ключа в этот документ не выносятся -- везде плейсхолдеры.

## Ключ WERF_SECRET_KEY

werf шифрует и расшифровывает значения симметричным ключом. Создать его:

```bash
werf helm secret generate-secret-key
```

Вывод -- это сам ключ. Хранить его как переменную окружения или как
masked/protected-переменную CI, не в git:

```bash
export WERF_SECRET_KEY=<секретный-ключ>
```

Альтернатива переменной -- файл `.werf_secret_key` в корне продукта (он в
`.gitignore`) или файл ключа в `~/.werf/`; полный порядок поиска ключа werf -- в
памятке продукта `apps/<product>/.helm/secrets/readme.md`. При выкатке функция
`deploy()` из [`utils/03-werf-converge.sh`](../../kube_ci/utils/03-werf-converge.sh)
добавляет `--secret-values=.helm/secrets-<ENVNAME>.yaml`, если файл есть, и werf
расшифровывает значения по ключу прямо в ходе converge. Без ключа рендер секретов
падает -- см. [troubleshooting.md](troubleshooting.md).

## Создание и правка зашифрованных значений

Работа идёт из каталога `.helm` продукта. Завести зашифрованные значения
окружения через интерактивный редактор:

```bash
cd apps/<product>/.helm
export WERF_SECRET_KEY=<секретный-ключ>
werf helm secret values edit secrets-dev.yaml     # для prod -- secrets-prod.yaml
```

`edit` расшифровывает файл во временный буфер, открывает редактор и шифрует
обратно при сохранении. Структура значений -- `secrets.dbPassword`,
`secrets.pgadminEmail`, `secrets.pgadminPassword` (образец --
[`secret-values.yaml.example`](../../apps/app1-java-react/.helm/secret-values.yaml.example)).

Отдельный зашифрованный файл шифруют и расшифровывают командами:

```bash
werf helm secret file encrypt plain.txt -o secret.enc
werf helm secret file decrypt secret.enc -o plain.txt
```

В продуктах для удобства есть обёртки
[`encrypt.sh`](../../apps/app1-java-react/.helm/secrets/encrypt.sh) и
[`decrypt.sh`](../../apps/app1-java-react/.helm/secrets/decrypt.sh) (аргумент --
окружение, `dev` по умолчанию): они гоняют plaintext `secrets/values.yaml`
(в `.gitignore`) в `secrets-<env>.yaml` и обратно. Зашифрованный
`secrets-<env>.yaml` коммитится, plaintext-копия -- нет.

## Ротация ключа

Ротация перешифровывает все секреты продукта с одного ключа на другой. werf
делает это командой `rotate-secret-key`: старый ключ передаётся через
`WERF_OLD_SECRET_KEY`, новый -- через `WERF_SECRET_KEY`.

1. Создать новый ключ:

   ```bash
   werf helm secret generate-secret-key
   ```

2. Перешифровать секреты окружения. Команда принимает список зашифрованных
   файлов; повторить для каждого окружения (`secrets-dev.yaml`,
   `secrets-prod.yaml`):

   ```bash
   cd apps/<product>/.helm
   export WERF_OLD_SECRET_KEY=<старый-ключ>
   export WERF_SECRET_KEY=<новый-ключ>
   werf helm secret rotate-secret-key secrets-dev.yaml secrets-prod.yaml
   ```

3. Заменить ключ в хранилище: обновить env-переменную или CI-переменную на
   новое значение, убрать старый ключ из всех мест.

4. Закоммитить перешифрованные `secrets-<env>.yaml` (значения изменились, так как
   зашифрованы новым ключом).

5. Перевыкатить продукт с новым ключом, чтобы релиз получил секреты под актуальным
   шифрованием -- см. [deploy.md](deploy.md) и [first-deploy.md](first-deploy.md):

   ```bash
   cd kube_ci/dev
   ./00-build-deploy.sh <product>
   ```

После ротации старый ключ нигде не должен оставаться: он по-прежнему расшифровывал
бы прежние коммиты `secrets-<env>.yaml` в истории git.

## Связанные статьи

- [Управление секретами](../delivery/secrets.md) -- модель шифрования и раскладка
  файлов
- [first-deploy.md](first-deploy.md) -- где настройка секретов в общей
  последовательности
- [deploy.md](deploy.md) -- три базовые операции kube_ci
- [troubleshooting.md](troubleshooting.md) -- сбой рендера при отсутствии ключа
- [Компромиссы и безопасность схемы](../concepts/security-and-tradeoffs.md)
