# apps -- демо-продукты

Каждый подкаталог -- отдельный продукт, который kube_ci собирает и деплоит
независимо. На этапе 1 здесь только заготовки; исходный код, `Dockerfile` и
`.helm/`-чарты добавляются на следующем этапе.

## Продукты

| Каталог | Фронт | Бек | Хранилище |
|---|---|---|---|
| [app1-java-react](app1-java-react/) | React | Spring Boot (Java) | PostgreSQL + pgAdmin |
| [app2-python-angular](app2-python-angular/) | Angular | FastAPI (Python) | PostgreSQL + pgAdmin |

## Контракт продукта для kube_ci

kube_ci не знает внутренностей продукта -- он работает по контракту. Чтобы
продукт деплоился, в его каталоге должен быть `.helm/`:

```
apps/<product>/
├── .helm/
│   ├── def.sh            # обязательно: окружения как shell-функции
│   ├── Chart.yaml        # werf/helm-чарт
│   ├── templates/        # k8s-манифесты
│   ├── values-<env>.yaml # опционально
│   ├── require.sh        # опционально: хук перед сборкой
│   ├── predeploy.sh      # опционально: хук перед деплоем
│   └── postdeploy.sh     # опционально: хук после деплоя
├── werf.yaml             # описание образов сборки
└── <исходники фронта/бека>
```

### `.helm/def.sh`

Определяет окружения как shell-функции. Имя функции совпадает с именем
окружения в `productlist` (`[<product>]=<env>`). Функция экспортирует
переменные, которые `utils/03-werf-converge.sh` прокидывает в werf:

Одна функция на окружение (dev/prod). Имя функции -- значение в
`productlist` соответствующего окружения:

```bash
#!/bin/bash
dev() {
    export APPNAME=app1-java-react                              # имя приложения (репозиторий образа)
    export ENVNAME=dev                                   # имя окружения
    export NAMESPACE=app1-java-react                             # неймспейс (по умолчанию = APPNAME)
    export CI_URL=app1-java-react-dev-192.168.125.31.nip.io     # хост для ingress (nip.io)
    # любые CI_* переменные пробрасываются в helm через --set (в нижнем регистре)
}

prod() { dev; export ENVNAME=prod; export CI_URL=app1-java-react-prod-192.168.125.31.nip.io; }
```

Минимально обязательны `APPNAME`, `ENVNAME`, `CI_URL`. Остальное -- опционально.
Релиз разворачивается в неймспейс `<NAMESPACE>-<ENVNAME>`, поэтому одно
приложение в обоих окружениях не конфликтует даже на одном кластере.

Дополнительно `03-werf-converge.sh` подхватывает (если есть):
`.helm/values-<ENVNAME>.yaml` (`--values`) и `.helm/secrets-<ENVNAME>.yaml`
(`--secret-values`, требует werf-ключ).

## Подключение в окружении

Продукт попадает в деплой через `productlist` окружения
(`kube_ci/<env>/productlist`, где `<env>` -- dev/prod), формат:
`[<product>]=<env-функция>`. Шаблон -- `productlist_official`.
