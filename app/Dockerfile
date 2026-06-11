# ==========================================
# Etapa 1: Construcción
# ==========================================
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# ==========================================
# Etapa 2: Producción
# ==========================================
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Usamos la referencia exacta al alias definido arriba
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]