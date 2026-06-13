# Внешние ресурсы

Подборка официальной документации по инструментам и темам контура. Каждая ссылка
сопровождается короткой аннотацией -- зачем к ней обращаться. Внутренние термины
собраны в [Глоссарии](glossary.md).

## werf

- [werf.io](https://werf.io/) -- официальный сайт: обзор инструмента и навигация
  по документации.
- [Getting started](https://werf.io/getting_started/) -- установка через trdl,
  добавление репозитория и значение TUF root-key. Этот ключ берут только отсюда.
- [Документация werf](https://werf.io/docs/latest/) -- справочник по командам
  (`converge`, `dismiss`, `cleanup`), giterminism, stages-storage и секретам.
- [trdl](https://trdl.dev/) -- менеджер версий, которым ставится werf; описывает
  каналы обновлений и проверку целостности.

## Helm и Kubernetes

- [Helm](https://helm.sh/docs/) -- чарты, шаблоны и values. werf-чарт
  helm-совместим, поэтому справочник применим напрямую.
- [Kubernetes](https://kubernetes.io/docs/home/) -- объекты кластера: Deployment,
  StatefulSet, Service, ConfigMap, Secret, Namespace.
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) --
  модель маршрутизации внешнего трафика, на которой строится доступ к продуктам.
- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) -- контроллер
  Ingress, используемый в демо-кластере; аннотации и маршрутизация по пути.
- [nip.io](https://nip.io/) -- wildcard-DNS, дающий внешний хост релиза без
  собственных DNS-записей.

## CI-системы

- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/) -- `.gitlab-ci.yml`, стадии,
  переменные и хранение секретов как masked/protected. См.
  [Подключение к GitLab CI](integrations/gitlab-ci.md).
- [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/) -- `Jenkinsfile`,
  параметризованные сборки и credentials. См.
  [Подключение к Jenkins](integrations/jenkins.md).

## Базы данных

- [PostgreSQL](https://www.postgresql.org/docs/) -- СУБД продуктов; раздел про
  инициализацию и скрипты первого старта релевантен `init.sql`.
- [pgAdmin](https://www.pgadmin.org/docs/) -- веб-клиент к PostgreSQL: настройка
  серверов и режим контейнера.

## Метрики и инженерные практики

- [DORA](https://dora.dev/) -- исследование DevOps Research and Assessment:
  определения и измерение четырёх ключевых метрик поставки.
- [Accelerate (книга)](https://itrevolution.com/product/accelerate/) -- первоисточник
  по DORA-метрикам и связи практик поставки с результатами.

## Связанные документы

- [Глоссарий](glossary.md)
- [Введение в werf](concepts/werf-intro.md)
- [Метрики DORA](integrations/dora-metrics.md)
- [Индекс документации](README.md)
