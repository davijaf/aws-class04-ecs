# API Spring Boot (class3) — containerizacao Java 21, porta 8080
# Pre-requisito: gerar o JAR antes -> mvn clean package -DskipTests
FROM eclipse-temurin:21-jre

# Tag/versao deployada — passada no build (--build-arg APP_TAG=v1) e exposta em /health
ARG APP_TAG=dev
ENV APP_TAG=${APP_TAG}

WORKDIR /app

# JAR "fat" gerado pelo spring-boot-maven-plugin
COPY target/class3-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
