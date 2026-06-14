# Подключение системы скриптов к Jenkins

Статья показывает, как обернуть операции `kube_ci` в Jenkins-пайплайн. Это
справочник: требования к агенту, credentials Jenkins, маппинг трёх операций на
stage'и и рабочий declarative `Jenkinsfile`. Логика та же, что и для
[GitLab CI](gitlab-ci.md): пайплайн ничего не знает про werf, он лишь вызывает
bash-скрипты `kube_ci` с нужными доступами. Статью читать после раздела о самих
операциях -- [Операции kube_ci](../delivery/kube-ci-operations.md).

kube_ci -- это набор bash-скриптов, которые запускаются вручную из каталога
окружения. Те же скрипты вызываются из stage'ей Jenkins: пайплайн становится
тонкой обёрткой над `00-build-deploy.sh` / `03-rollback.sh` / `01-dismiss.sh` /
`02-purge-stages.sh`.

## Что нужно от агента

Агент (нода) Jenkins, на котором выполняются stage'и, должен нести тот же набор
инструментов, что и рабочая машина:

- `docker` (сборка образов werf);
- `werf` через `trdl` (`trdl use werf 2 stable`) -- см. [werf-intro.md](../concepts/werf-intro.md);
- `kubectl` и `helm`;
- доступ к кластерам окружений и in-cluster registry -- см.
  [requirements.md](../kubernetes/requirements.md).

Агент должен иметь сетевой доступ к кластеру и insecure-registry, аналогично
рабочей машине. Сборка werf не запускается в контейнере без привилегий, поэтому
агент -- это нода с установленным docker, а не контейнерный executor.

## Credentials Jenkins

В Manage Jenkins -> Credentials заводятся:

| Credential | Тип | Назначение |
|---|---|---|
| `kubeconfig` | Secret file | kubeconfig для доступа к кластеру окружения |
| `werf-secret-key` | Secret text | ключ расшифровки `secrets-<env>.yaml` (если используются) |

Контекст кластера и адрес ноды не секретны и задаются параметрами job или
переменными окружения агента: `KUBECONTEXT` -- имя контекста, `K8S_NODE_IP` --
адрес ноды для nip.io-реестра. Оба переопределяют значения по умолчанию из
[`k8s_defs`](../../kube_ci/dev/k8s_defs) соответствующего окружения, поэтому при
едином кластере их можно не задавать вовсе.

Secret file `kubeconfig` Jenkins выкладывает во временный файл, путь к которому
прокидывается в `KUBECONFIG`; secret text `werf-secret-key` -- в
`WERF_SECRET_KEY`. Оба подключаются через `withCredentials` только в тех
stage'ах, где они нужны.

## Маппинг операций на stage'и

Базовые операции kube_ci и два окружения (dev/prod) ложатся на stage'и
пайплайна. Типовой поток: автодеплой в `dev` на ветке `main`, промоут в `prod`
через ручное подтверждение (`input`).

| Операция kube_ci | Stage Jenkins |
|---|---|
| публикация (`00-build-deploy.sh`) | `Deploy dev` / `Deploy prod` |
| откат версии (`03-rollback.sh`) | `Rollback` |
| снос (`01-dismiss.sh`) | `Dismiss` |
| очистка (`02-purge-stages.sh`) | `Purge` |

Ручное подтверждение перед prod через `input` -- паритет с `when: manual` в
GitLab CI: stage не выполнится, пока оператор не подтвердит.

## Пример `Jenkinsfile`

```groovy
pipeline {
    agent { label 'werf' }

    parameters {
        choice(name: 'ENV', choices: ['dev', 'prod'], description: 'окружение')
        string(name: 'PRODUCT', defaultValue: '--all',
               description: 'ключ продукта или --all (для Rollback обязателен)')
    }

    stages {
        stage('Deploy dev') {
            when {
                allOf {
                    branch 'main'
                    expression { params.ENV == 'dev' }
                }
            }
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    string(credentialsId: 'werf-secret-key', variable: 'WERF_SECRET_KEY')
                ]) {
                    sh '''
                        source "$(~/bin/trdl use werf 2 stable)"
                        cd kube_ci/dev
                        ./pull_products.sh
                        ./00-build-deploy.sh --all
                    '''
                }
            }
        }

        stage('Deploy prod') {
            when {
                allOf {
                    branch 'main'
                    expression { params.ENV == 'prod' }
                }
            }
            steps {
                input message: 'Выкатить в prod?', ok: 'Deploy'
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    string(credentialsId: 'werf-secret-key', variable: 'WERF_SECRET_KEY')
                ]) {
                    sh '''
                        source "$(~/bin/trdl use werf 2 stable)"
                        cd kube_ci/prod
                        ./pull_products.sh
                        ./00-build-deploy.sh --all
                    '''
                }
            }
        }

        stage('Rollback') {
            when { expression { params.PRODUCT?.trim() } }
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        source "$(~/bin/trdl use werf 2 stable)"
                        cd "kube_ci/$ENV"
                        ./03-rollback.sh "$PRODUCT" "$REVISION"
                    '''
                }
            }
        }

        stage('Dismiss') {
            when { expression { params.PRODUCT?.trim() } }
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        source "$(~/bin/trdl use werf 2 stable)"
                        cd "kube_ci/$ENV"
                        ./01-dismiss.sh "$PRODUCT"
                    '''
                }
            }
        }

        stage('Purge') {
            steps {
                sh '''
                    source "$(~/bin/trdl use werf 2 stable)"
                    cd "kube_ci/$ENV"
                    ./02-purge-stages.sh
                '''
            }
        }
    }
}
```

В примере публикация, откат, снос и очистка разнесены по разным stage'ам одного
пайплайна; на практике откат, снос и очистку удобнее держать отдельными job-ами с
ручным запуском по параметрам `ENV`/`PRODUCT`/`REVISION`, чтобы не запускать их
при каждой сборке ветки.

## Замечания

- В CI продукты не обязательно тянуть через `pull_products.sh` symlink'ами:
  если каждый продукт -- отдельный репозиторий, его исходники подключаются как
  submodule или отдельным `git clone` в `products/<product>` перед вызовом
  `00-build-deploy.sh`.
- `01-dismiss.sh` и `03-rollback.sh` требуют явного product key -- значение
  передаётся параметром `PRODUCT`, пустое приведёт к отказу с кодом возврата 1.
  В примере stage `Rollback` и `Dismiss` поэтому защищены `when`-условием на
  непустой `PRODUCT`. `03-rollback.sh` без параметра `REVISION` печатает `helm
  history` и кластер не меняет.
- Для werf-cleanup образов в registry по политикам (`werf.yaml: cleanup`)
  заводится отдельный scheduled job с `werf cleanup` (триггер `cron` в job).
- `WERF_SECRET_KEY` подключается только в stage'ах деплоя; откат, снос и очистка
  кеша ключ шифрования не используют.

## Плюсы, минусы, безопасность

Плюсы. `Jenkinsfile` остаётся обёрткой над теми же скриптами `kube_ci`:
доставка не зависит от выбора CI-системы, переезд с GitLab меняет только синтаксис
описания stage'ей. Параметризованный билд переиспользует одну логику для
публикации, отката, сноса и очистки.

Минусы. Агент должен сам нести werf, доступ к registry и kubeconfig, а credentials
заводятся в Jenkins отдельно от репозитория -- их рассинхрон с контуром виден
только на стадии. Откат и снос завязаны на параметр `PRODUCT` и `when`-условие,
пустое значение намеренно валит stage.

Безопасность. `WERF_SECRET_KEY` хранится в Jenkins как secret text и подключается
только в stage'ах деплоя; откат и очистка ключ не получают. Хранение ключа и
боевые послабления разобраны в
[Управлении секретами](../delivery/secrets.md) и
[Компромиссах и безопасности схемы](../concepts/security-and-tradeoffs.md).

## Связанные статьи

- [Подключение к GitLab CI](gitlab-ci.md) -- та же обёртка над скриптами в
  другой CI-системе.
- [Метрики DORA](dora-metrics.md) -- какие сигналы поставки снимаются с job-ов
  пайплайна.
- [Операции kube_ci](../delivery/kube-ci-operations.md) -- что делают скрипты,
  которые вызывает пайплайн.
- [Управление секретами](../delivery/secrets.md) -- ключ werf и хранение его как
  secret text в Jenkins.
- [Требования к Kubernetes-кластеру](../kubernetes/requirements.md) -- доступ
  агента к кластеру и insecure-registry.
