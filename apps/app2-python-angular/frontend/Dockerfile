# syntax=docker/dockerfile:1
# prod-сборка фронтенда app2-python-angular (Angular) -> nginx.
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json ./
RUN --mount=type=cache,target=/root/.npm npm install

COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime
ARG BUILD_HASH=unknown

COPY --from=builder /app/dist/app2-frontend/browser /usr/share/nginx/html
RUN echo "{\"git_hash\":\"${BUILD_HASH}\"}" > /usr/share/nginx/html/version.json

RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
