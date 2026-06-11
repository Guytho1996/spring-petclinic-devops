# ==========================================
# Etapa 1: Construcción (Builder)
# ==========================================
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app

# Copiamos el pom.xml y el código fuente completo
COPY pom.xml .
COPY src ./src

# Compilamos el proyecto (esto genera un .jar totalmente fresco internamente)
RUN mvn clean package -DskipTests

# ==========================================
# Etapa 2: Producción (Runner)
# ==========================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copiamos ÚNICAMENTE el .jar generado en la etapa anterior (builder)
COPY --from=builder /app/target/*.jar app.jar

# Exponemos el puerto de la aplicación
EXPOSE 8080

# Comando de arranque de Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]