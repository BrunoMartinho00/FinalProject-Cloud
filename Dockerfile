# Usa uma imagem base com Java
FROM eclipse-temurin:17-jre-jammy

# Copia o jar gerado pelo Maven para dentro do container
# Nota: Ajusta o nome do jar se necessário
COPY target/*.jar app.jar

# Expõe a porta que o teu serviço usa (ex: 8080)
EXPOSE 8080

# Comando para arrancar a aplicação
ENTRYPOINT ["java", "-jar", "/app.jar"]