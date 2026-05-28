# Stage 1: Compilar dentro do Docker
FROM maven:3.8-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Rodar (imagem leve)
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# Copia o JAR do stage 'build' para esta imagem final
COPY --from=build /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]