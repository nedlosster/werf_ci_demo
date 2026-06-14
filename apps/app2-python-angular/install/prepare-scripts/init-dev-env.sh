#!/bin/bash
# Инициализация dev-пода app2-python-angular: каталоги кешей, ssh-ключ,
# однократный клон монорепо werf_ci_demo в /workspace. Идемпотентен.
set -e

for d in .cache .npm .local .vscode-server .config; do
    mkdir -p "/home/app/homeapp/$d"
    chown -R app "/home/app/homeapp/$d" 2>/dev/null || true
done

if [ -f /home/app/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    cp -f /home/app/.ssh/id_rsa /root/.ssh/id_rsa
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/id_rsa
    ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true
fi

DIR=/workspace
if [ ! -f "$DIR/.gitclone" ]; then
    echo "Клонирую werf_ci_demo в $DIR"
    cd "$DIR"
    git clone git@github.com:nedlosster/werf_ci_demo.git \
        || git clone https://github.com/nedlosster/werf_ci_demo.git \
        || { echo "ВНИМАНИЕ: clone не удался -- склонируйте вручную в $DIR"; }
    [ -d "$DIR/werf_ci_demo" ] && { chown -R app "$DIR/werf_ci_demo" 2>/dev/null || true; touch "$DIR/.gitclone"; }
fi

echo "init-dev-env: готово. Рабочая копия: $DIR/werf_ci_demo/apps/app2-python-angular"
