# ==========================================
# Etapa 2: Producción (Runner)
# ==========================================
# Forzamos explícitamente una imagen de Ubuntu 22.04 LTS (Jammy)
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Copiamos el .jar generado en la etapa anterior
COPY --from=builder /app/target/*.jar app.jar

# Exponemos el puerto
EXPOSE 8080

# Comando de arranque
ENTRYPOINT ["java", "-jar", "app.jar"]