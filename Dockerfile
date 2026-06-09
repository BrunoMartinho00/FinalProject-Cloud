FROM eclipse-temurin:17-jre-jammy

COPY target/*.jar app.jar

# Expõe a porta que o serviço usa (ex: 8080)
EXPOSE 8080

# Comando para arrancar a aplicação
ENTRYPOINT ["java", "-jar", "/app.jar"]