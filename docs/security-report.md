# Security Report

Este repositorio integra los controles DevSecOps pedidos en la guia del
proyecto: SAST, SCA, escaneo de imagenes, gestion basica de secretos y DAST
con OWASP ZAP.

## Controles en CI/CD

- Pre-commit secrets: `.pre-commit-config.yaml` ejecuta `gitleaks`.
- SAST: `.github/workflows/ci-cd.yml` ejecuta Semgrep con reglas Java y
  `security-audit`.
- SCA: Trivy escanea dependencias Maven con severidad `CRITICAL,HIGH`.
- Container scan: Trivy bloquea imagenes backend/frontend con CVEs
  `CRITICAL,HIGH`.
- DAST: OWASP ZAP Baseline escanea la aplicacion ya desplegada en development.

## OWASP ZAP Baseline

El job `zap-baseline` del workflow `.github/workflows/ci-cd.yml` se ejecuta
despues de `deploy-dev` y antes del approval de produccion. El target se toma
de la variable de repositorio `DEV_ZAP_TARGET_URL`; si no existe, usa:

```text
https://guytho1996-petclinic-dev.eastus2.cloudapp.azure.com
```

El scan usa `zaproxy/action-baseline@v0.15.0` con la imagen
`ghcr.io/zaproxy/zaproxy:stable`. La configuracion esta en `.zap/rules.tsv`.
Las alertas quedan como `WARN` para producir evidencia sin bloquear el
pipeline por hallazgos pasivos esperados. Para convertir una regla en gate,
cambiar su accion de `WARN` a `FAIL`.

## Evidencia de entrega

Cada ejecucion en `master` o `main` publica el artefacto de GitHub Actions
`zap-baseline-security-report`. Ese artefacto contiene el reporte OWASP ZAP en
los formatos generados por la accion, incluido HTML y Markdown cuando estan
disponibles.

Para la demo o informe PDF, descargar el artefacto del workflow y adjuntar:

- Screenshot del job `OWASP ZAP Baseline Scan`.
- Resumen de alertas del reporte Markdown o HTML.
- Decision de tratamiento: corregir, aceptar temporalmente o promover a gate.
