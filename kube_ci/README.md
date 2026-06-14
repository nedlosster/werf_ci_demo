# kube_ci (адаптированная копия)

Оркестрация сборки и деплоя продуктов через [werf](https://werf.io) в **уже
развёрнутые** кластеры. Это упрощённая копия рабочего проекта `kube_ci`,
сведённая к базовому набору операций для демо: **публикация, откат, очистка**.

Развёртывание самих кластеров в скоп демо не входит -- требования к среде
описаны в [../docs/kubernetes/requirements.md](../docs/kubernetes/requirements.md).

## Окружения dev / prod

Два параллельных самодостаточных каталога окружений -- `dev/` и `prod/`.
Каждое запускается независимо и отличается только своим `k8s_defs`
(кластер) и `productlist` (какую env-функцию `.helm/def.sh` использует продукт).

ВРЕМЕННО оба `k8s_defs` указывают на один физический preprod-кластер.
Продукты при этом различаются неймспейсом
(`<NAMESPACE>-dev`, `-prod`). Когда появятся отдельные кластеры dev/prod --
меняется только `KUBECONTEXT`/`REGISTRY` в соответствующем `k8s_defs`.

## Отличия от исходного kube_ci

| Аспект | Исходный kube_ci | Эта копия |
|---|---|---|
| Окружения | 4 (minikube + 3 удалённых k8s) | два -- `dev/`, `prod/` |
| Источник продуктов | клонирование `git@github.com:welltime/<product>` | локальные `../../apps/<product>` (symlink) |
| werf | разнобой: `trdl werf 2`, `trdl werf 1.2`, `multiwerf` | единый `trdl use werf 2 stable` |
| Доп. сервисы | kafka, zeebe, efk, grafana | нет |
| Провижининг кластера | setup-скрипты (containerd, ssh на ноду) | вынесен в docs/kubernetes/requirements.md |
| Набор операций | полный | публикация, откат, очистка |

## Структура

```
kube_ci/
├── utils/                       # общие bash-функции (библиотеки)
│   ├── 03-werf-converge.sh      # deploy() -- werf converge (build + deploy)
│   ├── 04-dismiss.sh            # dismiss() -- werf dismiss
│   ├── 05-purge-stages-local.sh # purge_stages_local() -- сброс stages
│   └── 10-purge-werf-registry.sh# полная очистка werf-кеша и образов
└── <env>/                       # dev/ | prod/ -- одинаковый набор:
    ├── 00-build-deploy.sh       # публикация (werf converge)
    ├── 01-dismiss.sh            # откат (требует product key или --all)
    ├── 02-purge-stages.sh       # очистка
    ├── pull_products.sh         # связать apps/<product> -> products/
    ├── k8s_defs                 # REGISTRY (nip.io) / KUBECONTEXT / KUBECONFIG
    ├── productlist_official      # шаблон списка продуктов
    └── .gitignore
```

Каждый файл `utils/*.sh` защищён от двойного выполнения
(`[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && return`), поэтому работает и как
библиотека (`source`), и как самостоятельный скрипт.

## Запуск

См. [../docs/runbooks/deploy.md](../docs/runbooks/deploy.md).

Команды запускать из каталога окружения (`cd dev/`, `cd prod/`):
пути резолвятся через `$BASH_SOURCE`, а `source productlist`/`source k8s_defs` --
относительно `$PWD`.

## Контракт продукта

kube_ci работает по контракту `.helm/def.sh` -- см.
[../apps/README.md](../apps/README.md).
