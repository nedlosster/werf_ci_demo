---
title: "Вводная документация по контуру werf+k8s CI"
status: resolved
created: 2026-06-13
last-updated: 2026-06-13
---

# Вводная документация по контуру werf+k8s CI

## Описание

Создать вводную (обучающую) документацию по инструменту и реализации CI с
доставкой в Kubernetes. Документация пишется для разработчиков и девопсов
среднего уровня; формат -- передача отлаженной схемы и практического опыта.

Запрошенные разделы:

1. **werf** -- что это, зачем он нужен; несколько вводных статей.
   - Сравнение с аналогичными инструментами (Helm, Helmfile, ArgoCD/Flux,
     kustomize, skaffold, обычный `docker build` + `kubectl`).
   - Плюсы и минусы.
2. **Kubernetes** -- отдельная папка.
   - Требования к кластеру.
   - Спецификации (манифесты, ресурсы).
   - Важные приёмы и моменты (ingress, неймспейсы, registry и т.д.).
3. **Два приложения** -- стек бекенда и фронтенда каждого:
   - app1-java-react: React + Spring Boot + PostgreSQL + pgAdmin.
   - app2-python-angular: Angular + FastAPI + PostgreSQL + pgAdmin.
4. **Подход dev/prod-окружений** -- как один контур ставит продукты в два
   окружения по общему контракту.
5. **Ingress** -- доступ к продуктам, хосты nip.io.
6. **pgAdmin** -- как подключён, зачем.
7. **Стек и реализация** -- обзор технологий и того, как собрано.
8. **БД PostgreSQL и инициализация** -- схема, init, миграции.
9. **Хранение секретов** -- werf secret / иные подходы.
10. **Версионирование** -- единая версия (контейнеры/бек/фронт).
11. **Интеграция с GitLab CI** -- подключение скриптов kube_ci.
12. **Интеграция с Jenkins** -- аналог.
13. **DORA-метрики** -- как можно реализовать на этом контуре.
14. **Диаграммы** -- визуализация архитектуры: связка apps -> kube_ci ->
    кластер; место контура в большом промышленном CI/CD-конвейере доставки
    (где kube_ci встраивается между VCS/CI-раннерами и кластерами, как
    стыкуется с GitLab/Jenkins, registry, окружениями).

Артефакты: `README.md`, индексы, связанные документы (перелинковка),
Mermaid-диаграммы (`docs/diagrams/*.mmd` -> рендер в `docs/pics/`).

Контекст: часть каркаса docs уже существует (werf-intro.md,
k8s-requirements.md, gitlab-ci.md, versioning.md, dev-in-cluster.md,
runbooks/deploy.md, diagrams/architecture.mmd). Задача -- расширить до
полноценной вводной документации, не дублируя и переиспользуя имеющееся.

Эталон уровня и структуры -- `~/projects/hermes-usage/docs/`:
тематические папки с собственным `README.md`-индексом, корневой `docs/README.md`
с «путём чтения» и таблицей разделов, статьи-эссе на ~100-130 строк
(вводный абзац-карта, предметные секции, блок «Связанные статьи» в конце,
обильная перелинковка), сервисные `glossary.md` / `resources.md` / `news.md`,
отчёты `experience/`. Связная проза для специалиста, не знакомого с темой.

## Drill

Поправка к фактам (важно): приложения -- НЕ пустые заготовки. В каждом есть
реальные `.helm/`-чарты (templates: ingress, pgadmin, db-init-configmap,
backend/frontend dev+prod, secret), `werf.yaml`, `Dockerfile`/`Dockerfile.dev`,
`pom.xml`/`pyproject.toml`/`package.json`, `set-version.sh`, единая версия
через `VERSION`->`CI_TAG`. Минимальна только бизнес-логика фронта/бека.
Поэтому стек, ingress, pgAdmin, init БД, секреты, версии документируются по
реальным артефактам. CLAUDE.md про «только каркас» устарел.

Q1. Структура -> **тематические папки как в hermes** с README-индексами:
`concepts/`, `kubernetes/`, `products/`, `delivery/`, `integrations/`,
`runbooks/`, `demo/` + `diagrams/`, `glossary.md`, `resources.md`. Корневой
`docs/README.md` -- путь чтения + таблица разделов.

Q2. Существующие 6 документов -> **два регистра**: концептуальные/обзорные --
эссе ~120 строк (связная проза); reference/runbook (requirements, deploy,
gitlab) -- остаются сжатыми, переносятся с вводным абзацем и перелинковкой.
werf-intro перерабатывается в эссе.

Q3. Демо-раздел -> **тайминг-план доклада на 40 мин** (поминутная раскладка
по блокам, цели, тезисы). Плюс **банк из 20 Q&A** (названы прямо в задаче,
обязательны). Плюс **вспомогательные слайды** (`demo/slides.md` -- слайд-аутлайн
по блокам доклада; уточнение Архитектора 2026-06-13, ранее были отброшены).
Live-сценарий -- отброшен.

Q4. Плюсы/минусы и безопасность -> **отдельная статья
`security-and-tradeoffs.md` + сквозные врезки** «Плюсы/Минусы/Безопасность»
в конце тематических статей. Разбор: insecure-registry (HTTP/skip-TLS),
loose-giterminism, общий preprod-кластер dev/prod, nip.io, WERF_SECRET_KEY,
dev-SSH-под.

Q5. Стек приложений -> **от реальных артефактов, стек как контекст**: как
собран (werf.yaml, многоступенчатый Dockerfile, prod vs dev), как развёрнут
(templates), почему два контрастных стека; фреймворки описаны как контекст,
честно помечено, что бизнес-логика демонстрационная.

Q6. Runbook'и (добавить к deploy.md) -> **подключение к кластеру** (kubeconfig,
k8s_defs, insecure-registry), **секреты: настройка и ротация**, **первый
деплой продукта с нуля** (end-to-end), **troubleshooting**.

Q7. DORA -> **концепция + привязка к контуру**: 4 метрики и где в этом контуре
брать сигналы (frequency/lead time из пайплайнов/git/converge; CFR/MTTR из
rollback и инцидентов). Без готового кода сбора. (В коде сигналов сейчас нет.)

Q8. Диаграммы (Mermaid -> `docs/pics/`) -> все четыре новые: **встраивание в
промышленный CI/CD**, **поток converge (sequence)**, **анатомия продукта в
кластере**, **DORA-поток метрик**. Плюс существующая `architecture.mmd` = 5.

Q9. Сервисные документы -> **`glossary.md`**, **`resources.md`**, обновить
**корневой README.md и apps/README.md** под новую структуру. `experience/` и
`news.md` -- НЕ делаем (опыта эксплуатации мало).

Q10. PDF -> **два отдельных PDF** навыком `/pdf` в самом конце (уточнение
Архитектора 2026-06-13): (1) документация без раздела demo (титул + оглавление +
разделы в порядке пути чтения, с диаграммами); (2) демо -- план показа +
вспомогательные слайды + qa-bank как backup-слайды.

Доп. дефолт (на подтверждение при resolve): Jenkins -- паритет с gitlab-ci
(полноценный `Jenkinsfile`-пример). Вне скоупа: разворачивание кластеров,
реальная бизнес-логика приложений, отдельные prod-кластеры (временно один).

## Решения

- **Структура** -- тематические папки с README-индексами: `concepts/`,
  `kubernetes/`, `products/`, `delivery/`, `integrations/`, `runbooks/`,
  `demo/` + `diagrams/`, `glossary.md`, `resources.md`. Корневой
  `docs/README.md` -- путь чтения + таблица разделов.
- **Регистр** -- два: концептуальные/обзорные статьи в виде эссе ~120 строк
  (связная проза); reference/runbook -- сжатые, с вводным абзацем и
  перелинковкой. werf-intro перерабатывается в эссе.
- **Опора на факты** -- стек приложений документируется от реальных артефактов
  (`werf.yaml`, `.helm/templates`, Dockerfile, db-init, secret), фреймворки --
  как контекст, бизнес-логика честно помечена демонстрационной.
- **Целевое дерево docs/** (см. ## Реализация ниже):
  - `concepts/`: werf-intro (эссе), werf-vs-alternatives,
    delivery-to-k8s, security-and-tradeoffs.
  - `kubernetes/`: requirements (reference), specifications, ingress.
  - `products/`: overview, app1-java-react, app2-python-angular,
    postgres-and-init, pgadmin.
  - `delivery/`: dev-prod, kube-ci-operations, secrets, versioning,
    dev-in-cluster.
  - `integrations/`: gitlab-ci, jenkins (паритет, Jenkinsfile),
    dora-metrics (концепция + привязка к контуру).
  - `runbooks/`: deploy (есть), cluster-connection, secrets-setup,
    first-deploy, troubleshooting.
  - `demo/`: talk-plan-40min (тайминг доклада), qa-bank (20 Q&A),
    slides (вспомогательные слайды доклада).
- **Безопасность/trade-offs** -- отдельная статья
  `concepts/security-and-tradeoffs.md` + сквозные врезки
  «Плюсы/Минусы/Безопасность» в тематических статьях.
- **Диаграммы** (Mermaid -> `docs/pics/`): industrial-cicd, converge-flow
  (sequence), product-anatomy, dora-flow + существующая architecture = 5.
- **Сервисные** -- `glossary.md`, `resources.md`; обновить корневой
  `README.md` и `apps/README.md`. `experience/` и `news.md` НЕ делаем.
- **PDF** -- два отдельных PDF навыком `/pdf` в самом конце: (1) документация
  без раздела demo (титул + оглавление + разделы по пути чтения, с диаграммами);
  (2) демо -- план показа + вспомогательные слайды (`demo/slides.md`) + qa-bank
  как backup-слайды. Оба с титулом и оглавлением.
- **Вне скоупа** -- разворачивание кластеров, реальная бизнес-логика
  приложений, отдельные prod-кластеры (временно один preprod).

## Фазы реализации

Прогон через Ralph loop (`tools/ralph-teamlead.sh`): одна фаза -- одна итерация
(свежее окно), один PR на весь план, единственная остановка -- merge в master в
конце. Детальный спецификатор каждой статьи -- в `## Решения` (целевое дерево
docs/) выше. Зона записи -- только `/techwriter`.

Сквозное ограничение (всем фазам): сухая техническая проза для специалиста; без
иконок-символов; без слов-маркеров ИИ и ссылок на Claude/Anthropic/AI; слова
"сгенерировано"/"generated" и производные -- запрещены; обязательный прогон
`humanizer` на каждой статье. Опора -- реальные артефакты (`werf.yaml`,
`.helm/templates`, `Dockerfile`, `def.sh`, `values-*.yaml`, `init.sql`,
`set-version.sh`); бизнес-логика честно помечается демонстрационной.

| Фаза | Содержание | Статус | Коммит |
|---|---|---|---|
| Phase 1 | Каркас docs/: дерево папок (`concepts/ kubernetes/ products/ delivery/ integrations/ runbooks/ demo/`); `git mv` существующих в целевые места (werf-intro->concepts/, k8s-requirements->kubernetes/requirements, versioning->delivery/, dev-in-cluster->delivery/, gitlab-ci->integrations/); `docs/README.md` (путь чтения + таблица разделов); README-индекс в каждой папке (перечень будущих статей, фиксирует пути для перелинковки) | done | 1104d58 |
| Phase 2 | `concepts/`: werf-intro переработать в эссе ~120 строк; `werf-vs-alternatives` (Helm/Helmfile/ArgoCD/Flux/kustomize/skaffold/docker+kubectl, плюсы-минусы); `delivery-to-k8s` (как контур ставит приложения); `security-and-tradeoffs` (insecure-registry, loose-giterminism, общий preprod dev/prod, nip.io, WERF_SECRET_KEY, dev-SSH-под) | done | 5cdc931 |
| Phase 3 | `kubernetes/`: `requirements` (reference, дооформить перенесённый) ; `specifications` (манифесты, ресурсы, неймспейсы, registry); `ingress` (хосты nip.io, доступ к продуктам) | done | 68c8239 |
| Phase 4 | `products/`: `overview` (два контрастных стека, почему); `app1-java-react`; `app2-python-angular`; `postgres-and-init` (схема, init.sql, миграции); `pgadmin` (как подключён, зачем) -- от реальных артефактов | done | 1fe1982 |
| Phase 5 | `delivery/`: `dev-prod` (один контур, два окружения по контракту); `kube-ci-operations` (публикация/откат/очистка, utils); `secrets` (werf secret, WERF_SECRET_KEY); `versioning` (дооформить перенесённый, единая VERSION->CI_TAG); `dev-in-cluster` (перенесён) | done | 2bccd18 |
| Phase 6 | `integrations/`: `gitlab-ci` (дооформить перенесённый); `jenkins` (паритет, полноценный `Jenkinsfile`-пример); `dora-metrics` (4 метрики + где брать сигналы в этом контуре, без кода сбора) | done | 0b4f328 |
| Phase 7 | `runbooks/`: `cluster-connection` (kubeconfig, k8s_defs, insecure-registry); `secrets-setup` (настройка и ротация); `first-deploy` (продукт с нуля end-to-end); `troubleshooting`; связать существующий `deploy.md` | done | 464d75c |
| Phase 8 | `demo/`: `talk-plan-40min` (поминутная раскладка доклада, цели, тезисы); `qa-bank` (банк из 20 Q&A) | done | 96f6547 |
| Phase 9 | Диаграммы Mermaid (`docs/diagrams/*.mmd` -> рендер в `docs/pics/` через `scripts/diagrams/render-all.sh`): `industrial-cicd` (встраивание в промышленный CI/CD), `converge-flow` (sequence), `product-anatomy` (анатомия продукта в кластере), `dora-flow`; врезать рендеры в соответствующие статьи | done | 94f804c |
| Phase 10 | Сервисные + сшивка: `glossary.md`, `resources.md`; обновить корневой `README.md` и `apps/README.md` под новую структуру (снять «этап 1/заготовки»); сквозные врезки «Плюсы/Минусы/Безопасность» в тематических статьях; финальная сверка перелинковки и `docs/README.md` | done | 9a5beca |
| Phase 11 | Экспорт в PDF навыком `/pdf` -- ДВА отдельных документа. (1) **Документация без демо**: вся документация в порядке пути чтения, титул + оглавление + разделы с врезкой диаграмм, БЕЗ раздела `demo/`. (2) **Демо**: материалы показа -- план доклада (`demo/talk-plan-40min`) + вспомогательные слайды + `qa-bank` как backup-слайды. Перед сборкой demo-PDF `/techwriter` создаёт `demo/slides.md` -- слайд-аутлайн по блокам доклада (один слайд = заголовок + 3-5 тезисов + ссылка на диаграмму/врезку), затем обновляет `demo/README.md` и путь чтения под новый файл. Оба PDF -- с титулом и оглавлением | planned | - |

## Реализация

_Заполняется при `/todo done NNN`._
