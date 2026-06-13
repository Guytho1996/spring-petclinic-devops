# ========================================================
# Stage 1: BUILD (Maven + JDK 17)
# ========================================================
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Copiar pom.xml para descargar dependencias en cache
COPY pom.xml .
RUN mvn dependency:go-offline -q --no-transfer-progress

# Copiar código fuente y compilar
COPY src ./src
RUN mvn package -DskipTests -Dmaven.test.skip=true --no-transfer-progress

# Extraer capas del JAR para optimizar la cache de Docker
RUN java -Djarmode=layertools -jar target/*.jar extract

# ========================================================
# Stage 2: RUNTIME (JRE 17 mínimo)
# ========================================================
FROM eclipse-temurin:17-jre-alpine AS runtime

# Crear usuario y grupo no root para mejorar la seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
WORKDIR /app

# Copiar capas desde la fase anterior
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/internal-dependencies/ ./
COPY --from=builder /app/application/ ./

# Exponer el puerto por defecto de Spring Boot
EXPOSE 8080

# Usar el JarLauncher de Spring Boot para iniciar desde las capas
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
