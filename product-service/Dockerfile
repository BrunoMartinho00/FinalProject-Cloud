# Stage 1: Build (Compila o código)
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Copia primeiro o pom.xml para aproveitar o cache do Docker
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn dependency:go-offline -B

# Copia o código fonte e faz o build
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn clean package -DskipTests

# Stage 2: Runtime (Corre a aplicação)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Cria um utilizador não-root por questões de segurança
RUN addgroup -S spring && adduser -S spring -G spring

# Copia apenas o JAR final do stage anterior
COPY --from=build /app/target/*.jar app.jar
RUN chown spring:spring app.jar
USER spring:spring

# Expõe a porta do serviço (ALTERAR CONSOANTE O SERVIÇO!)
EXPOSE 8081

# Otimizações da Máquina Virtual Java (JVM) para contentores
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

# Comando de arranque
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]