#!/bin/bash
# Инициализация dev-пода app1-java-react: каталоги кешей в persistent-volume,
# ssh-ключ, однократный клон монорепо werf_ci_demo в /workspace.
# Запускается init-контейнером при старте пода. Идемпотентен (маркер .gitclone).
set -e

# 1. Каталоги кешей и vscode-server в PVC homeapp (переживают перезапуск)
for d in .m2 .npm .cache .vscode-server .config; do
    mkdir -p "/home/app/homeapp/$d"
    chown -R app "/home/app/homeapp/$d" 2>/dev/null || true
done

# 2. ssh-ключ для приватного clone (если смонтирован Secret id-rsa-vcs)
if [ -f /home/app/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    cp -f /home/app/.ssh/id_rsa /root/.ssh/id_rsa
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/id_rsa
    ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true
fi

# 3. Однократный клон монорепо в workspace-volume
DIR=/workspace
if [ ! -f "$DIR/.gitclone" ]; then
    echo "Клонирую werf_ci_demo в $DIR"
    cd "$DIR"
    git clone git@github.com:nedlosster/werf_ci_demo.git \
        || git clone https://github.com/nedlosster/werf_ci_demo.git \
        || { echo "ВНИМАНИЕ: clone не удался (нет ключа/токена) -- склонируйте вручную в $DIR"; }
    [ -d "$DIR/werf_ci_demo" ] && { chown -R app "$DIR/werf_ci_demo" 2>/dev/null || true; touch "$DIR/.gitclone"; }
fi

# git-identity из env (converge -> StatefulSet -> sudo -E): проставляем в рабочую
# копию, чтобы коммиты из dev-пода шли под автором машины деплоя. Запускаем как app.
if [ -d "$DIR/werf_ci_demo/.git" ]; then
    [ -n "${GIT_USER_NAME:-}" ]  && sudo -u app git -C "$DIR/werf_ci_demo" config user.name  "$GIT_USER_NAME"  2>/dev/null || true
    [ -n "${GIT_USER_EMAIL:-}" ] && sudo -u app git -C "$DIR/werf_ci_demo" config user.email "$GIT_USER_EMAIL" 2>/dev/null || true
fi

echo "init-dev-env: рабочая копия в $DIR/werf_ci_demo/apps/app1-java-react"
