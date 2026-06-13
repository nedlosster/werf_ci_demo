# Секреты app2-python-angular (werf helm secret)

Пароли (БД, pgAdmin) хранятся зашифрованными в `.helm/secrets-<env>.yaml`.
Шифрование -- werf. Механизм взят из cmdb.

## Ключ шифрования

werf ищет ключ по приоритету:
1. `WERF_SECRET_KEY` (env)
2. `.werf_secret_key` в корне продукта (в .gitignore)
3. `~/.werf/global_secret_key`

Генерация: `werf helm secret generate-secret-key` -> записать в один из путей.

## Рабочий цикл

```bash
cd .helm/secrets
cp ../secret-values.yaml.example values.yaml   # plaintext (в .gitignore)
vim values.yaml                                # заполнить значения
./encrypt.sh dev                               # -> ../secrets-dev.yaml (зашифрован)
```

Правка существующих: `./decrypt.sh dev` -> правка `values.yaml` -> `./encrypt.sh dev`.

## Деплой

`kube_ci/utils/03-werf-converge.sh` автоматически добавляет
`--secret-values .helm/secrets-<env>.yaml`, если файл есть. Чарт читает значения
из `.Values.secrets.*`; если файла нет -- используются демо-дефолты из `values.yaml`.

## Файлы

| Файл | В git | Назначение |
|------|-------|-----------|
| `secret-values.yaml.example` | да | шаблон с CHANGE_ME |
| `secrets-<env>.yaml` | да (зашифрован) | секреты окружения dev/prod |
| `secrets/values.yaml` | нет (.gitignore) | plaintext для редактирования |
| `secrets/{encrypt,decrypt}.sh` | да | обёртки шифрования |
