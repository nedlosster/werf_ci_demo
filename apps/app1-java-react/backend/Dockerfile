# syntax=docker/dockerfile:1
# prod-сборка бекенда app1-java-react: multi-stage maven build -> slim JRE.

# --- builder ---
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# Слой зависимостей (кешируется по pom.xml через BuildKit cache mount)
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -e dependency:go-offline

# Слой приложения
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -e package -DskipTests

# --- runtime ---
FROM eclipse-temurin:17-jre AS runtime
WORKDIR /app

# UTF-8 локаль (встроенная C.UTF-8, без пакета locales): корректная работа с
# не-ASCII в логах и I/O. На JRE 17 иначе file.encoding падает в ASCII.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ARG BUILD_HASH=unknown

# non-root
RUN groupadd -g 10001 app && useradd -u 10001 -g 10001 -r -s /bin/false -d /app app

COPY --from=builder /build/target/app.jar /app/app.jar
RUN echo "{\"git_hash\":\"${BUILD_HASH}\"}" > /app/.build-info && chown -R app:app /app

EXPOSE 8080
USER app
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
