# syntax=docker/dockerfile:1
# prod-сборка бекенда app2-python-angular (FastAPI).
FROM python:3.12-slim AS runtime
WORKDIR /app

# UTF-8 локаль (встроенная C.UTF-8, без пакета locales): корректная работа с
# не-ASCII в логах и I/O.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ARG BUILD_HASH=unknown

# зависимости (кешируется по pyproject через BuildKit cache mount)
COPY pyproject.toml .
RUN --mount=type=cache,target=/root/.cache/pip \
    mkdir -p src/app2 && touch src/app2/__init__.py && pip install .

# приложение
COPY src/ src/
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-deps .

COPY entrypoint.sh .
RUN echo "{\"git_hash\":\"${BUILD_HASH}\"}" > /app/.build-info

# non-root
RUN groupadd -g 10001 app && useradd -u 10001 -g 10001 -r -s /bin/false -d /app app && \
    chown -R app:app /app
EXPOSE 8080
USER app
ENTRYPOINT ["sh", "entrypoint.sh"]
