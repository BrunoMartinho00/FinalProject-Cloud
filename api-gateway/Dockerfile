# Stage 1: Compilar
FROM maven:3.8-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Rodar
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# AQUI ESTÁ A CORREÇÃO: Copia o jar do stage 'build'
COPY --from=build /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]