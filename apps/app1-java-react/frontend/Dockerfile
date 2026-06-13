# syntax=docker/dockerfile:1
# prod-сборка фронтенда app1-java-react: multi-stage node(pnpm) build -> nginx.

# --- builder ---
FROM node:20-alpine AS builder
WORKDIR /app

# pnpm через corepack
RUN corepack enable

COPY package.json pnpm-lock.yaml* ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --prefer-offline

COPY . .
RUN pnpm run build

# --- runtime ---
FROM nginx:1.27-alpine AS runtime
ARG BUILD_HASH=unknown

COPY --from=builder /app/dist /usr/share/nginx/html
RUN echo "{\"git_hash\":\"${BUILD_HASH}\"}" > /usr/share/nginx/html/version.json

RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
