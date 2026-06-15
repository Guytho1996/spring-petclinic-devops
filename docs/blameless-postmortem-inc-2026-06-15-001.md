# Postmortem: INC-2026-06-15-001

## Metadatos

| Campo | Valor |
| --- | --- |
| ID del Incidente | INC-2026-06-15-001 |
| Título | Ruta pública de Grafana no disponible tras la desviación de configuración (drift) del ingress/servicio de Kubernetes |
| Estado | Completado para evidencia del Proyecto Integrador |
| Fecha | 2026-06-15 |
| Entorno | Demo de producción |
| Severidad | SEV2 |
| Duración | 28m 26s, desde 2026-06-15 00:18:05 UTC hasta 2026-06-15 00:46:31 UTC |
| Servicios afectados | Ingress de Kubernetes `/grafana`, servicio externo de Grafana, acceso al panel de SLO/DORA |
| Servicios no afectados | Backend de Spring Petclinic, frontend, datos de PostgreSQL |
| Comandante del incidente | Responsable de DevOps/SRE |
| Responsable del postmortem | Responsable de DevOps/SRE |
| Evidencia relacionada | `monitoring/dora/incidents.json`, `k8s/ingress.yaml`, `k8s/external-grafana.yaml`, `k8s/grafana-root-redirect.yaml` |

## Resumen

El 2026-06-15, la ruta pública de Grafana utilizada por el proyecto DevOps de Spring Petclinic dejó de estar disponible después de que la configuración del ingress y del servicio de Kubernetes para la instancia externa de Grafana se desviara del contrato de la ruta pública de producción. El incidente se detectó durante la verificación posterior al despliegue (post-deploy) cuando el equipo intentó abrir el panel público de SLO en `/grafana`.

Este fue un incidente simulado para el Proyecto Integrador. La aplicación en sí continuó respondiendo al tráfico y no se perdieron datos clínicos ni de clientes. El impacto en la confiabilidad siguió siendo importante porque el equipo perdió temporalmente su panel principal de SLO/DORA durante una ventana de despliegue.

La causa raíz fue la falta de un paso de verificación automatizado para las rutas externas de observabilidad. El flujo de trabajo (pipeline) de CI/CD verificaba la compilación, pruebas, escaneos de seguridad, publicación de imágenes, estado del despliegue (rollout status) de Kubernetes y una URL de prueba de humo (smoke URL) opcional, pero no validaba que cada ruta de ingress pública redirigiera a un servicio existente y a un punto de conexión (endpoint) accesible externamente.

## Impacto

- El acceso público a Grafana y al panel de SLO se vio degradado durante 28m 26s.
- Los interesados (stakeholders) de la demo no pudieron validar el panel de SLO/DORA a través de la URL de producción durante la ventana del incidente.
- Las métricas de Prometheus y el tiempo de ejecución (runtime) de la aplicación no se modificaron intencionadamente por el incidente.
- No hubo pérdida de datos, corrupción de base de datos ni impacto conocido en los flujos de trabajo de propietarios (owners), mascotas (pets), visitas (visits) o veterinarios (vets) de Petclinic.
- El incidente aumentó el riesgo operativo porque el panel utilizado para inspeccionar los SLO no estuvo disponible mientras el equipo diagnosticaba la versión (release).

## Desencadenante

El desencadenante fue un cambio en los manifiestos de Kubernetes que ajustó el nombre del servicio externo de Grafana y la configuración de la ruta de ingress. La secuencia de cambios relevante incluyó:

- `3c40b28`: añadió `external-grafana-service` y la ruta de ingress `/grafana`.
- `7c15ca5`: renombró el servicio/endpoint de Grafana y el backend del ingress a `grafana`.
- `420de24`: añadió una redirección raíz para Grafana que aún hacía referencia al patrón de host local.
- `6dae69c`: normalizó el host público de producción y restauró el contrato de `external-grafana-service` en los manifiestos.

## Detección

La detección fue manual. Durante la verificación posterior al despliegue, la URL pública de Grafana no devolvió el panel esperado. El script de despliegue existente esperaba el estado del rollout de Kubernetes, pero las comprobaciones no cubrían esta ruta externa de Grafana. Eso significa que el despliegue podía aparecer en verde ("green") mientras la ruta del panel seguía rota.

Comandos recomendados utilizados para confirmar este tipo de fallo:

```bash
curl -kI https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/
kubectl -n devops-lab get ingress petclinic-ingress grafana-root-redirect -o wide
kubectl -n devops-lab get svc,endpoints external-grafana-service grafana -o wide
kubectl -n devops-lab describe ingress petclinic-ingress
```

## Línea de tiempo

| Hora (UTC) | Evento |
| --- | --- |
| 2026-06-14 23:35:20 | `3c40b28` añadió `external-grafana-service` y expuso `/grafana` a través del Ingress. |
| 2026-06-14 23:55:44 | `7c15ca5` cambió el servicio, endpoint de Grafana y el nombre del backend del ingress a `grafana`. |
| 2026-06-15 00:18:05 | La ruta pública de Grafana falló en la verificación posterior al despliegue. Se abrió el incidente `INC-2026-06-15-001` con severidad SEV2. |
| 2026-06-15 00:20:00 | Se pausaron los cambios de despliegue no esenciales mientras el equipo comprobaba los recursos de Ingress, Service y Endpoints. |
| 2026-06-15 00:28:00 | El equipo identificó que el estado del rollout no validaba la ruta externa del panel y que el contrato de la ruta se había desviado. |
| 2026-06-15 00:35:02 | Se creó `06e79dd` durante los trabajos de mitigación para actualizar el registro de configuración externa de Grafana. |
| 2026-06-15 00:46:31 | Se restableció el acceso público a Grafana. MTTR registrado para DORA: 28m 26s. |
| 2026-06-15 01:45:20 | `420de24` añadió un manifiesto de redirección raíz de Grafana, exponiendo la deuda restante de configuración de host/ruta. |
| 2026-06-15 02:11:35 | `6dae69c` realizó el seguimiento duradero en los manifiestos utilizando el host de producción y restaurando el contrato de nomenclatura del servicio externo de Grafana. |

## Causa Raíz

### Causa técnica directa

La ruta pública `/grafana` no estaba cubierta por la validación automatizada posterior al despliegue, por lo que se podían aplicar cambios de ingress, servicio, endpoint y redirección incluso cuando la ruta pública del panel no coincidiera con el patrón de acceso de producción.

### Causa raíz sistémica

El proceso de despliegue consideraba el éxito del rollout de Kubernetes como evidencia suficiente de preparación para producción. Eso no era suficiente para esta topología porque Grafana se ejecuta como un servicio externo detrás de objetos Service/Endpoints de Kubernetes y una ruta de Ingress. La ruta dependía de un contrato entre múltiples manifiestos, pero el repositorio no contaba con una prueba de contrato, una política de manifiesto ni una sonda de caja negra (blackbox probe) para esa ruta.

### Factores contribuyentes

- `SMOKE_TEST_URL` solo admitía comprobaciones de URL opcionales y no era obligatorio para el despliegue en producción.
- La ruta pública `/grafana` no estaba incluida en el alcance de la prueba de humo.
- La integración externa de Grafana utilizaba una IP de endpoint estática, lo que hacía que la ruta fuera más sensible a la configuración de Service/Endpoints mantenida manualmente.
- La redirección raíz y la ruta de ingress principal podían desviarse de forma independiente.
- Ninguna comprobación de CI verificaba que cada nombre y puerto de servicio de backend del Ingress existiera en los manifiestos de Kubernetes renderizados.

## 5 Porqués

| ¿Por qué? | Respuesta |
| --- | --- |
| 1. ¿Por qué Grafana no estaba disponible a través de la URL pública? | La ruta pública `/grafana` no se resolvía en el backend externo de Grafana esperado después de los cambios en la configuración de ingress/servicio. |
| 2. ¿Por qué la ruta apuntaba a un contrato de backend/host no válido o inesperado? | Múltiples manifiestos controlaban la ruta, servicio, endpoint y redirección de Grafana, y se modificaron sin que una comprobación automatizada de contrato los cubriera a todos. |
| 3. ¿Por qué la tubería (pipeline) de despliegue permitió que ese cambio llegara a producción? | El pipeline esperaba el estado de rollout del backend/frontend, pero el estado de rollout no demuestra que una ruta de Ingress externa sea accesible. |
| 4. ¿Por qué no hubo una validación a nivel de ruta? | El diseño de la prueba de humo se centró en la ruta de la aplicación y trató las rutas de observabilidad como infraestructura de soporte, no como dependencias de confiabilidad orientadas a producción. |
| 5. ¿Por qué la ruta de observabilidad no se trató como un contrato de entrega (release)? | Las responsabilidades y los criterios de aceptación para los endpoints de monitoreo expuestos externamente no estaban documentados en el manual de despliegue (runbook) ni en las puertas de calidad (quality gates) de CI/CD. |

## Qué salió bien

- El incidente se detectó durante la verificación posterior al despliegue, antes de que la demo dependiera de las capturas de pantalla de Grafana como evidencia final.
- El tráfico de la aplicación y el estado de la base de datos estuvieron aislados del problema de la ruta de Grafana.
- El repositorio ya contaba con almacenamiento de incidentes de DORA, lo que permitía auditar el MTTR y el CFR.
- Los manifiestos de Kubernetes estaban versionados, por lo que el equipo pudo reconstruir la secuencia de cambios a partir del historial de confirmaciones (commits).

## Qué salió mal

- La detección fue manual en lugar de estar basada en alertas.
- El pipeline de despliegue no requería una prueba de humo en producción para `/grafana`.
- La ruta dependía de varios manifiestos, pero el repositorio no tenía validación de que los backends del Ingress hicieran referencia a servicios y puertos existentes.
- El primer trabajo de mitigación no cerró por completo la brecha de configuración duradera; fue necesario un seguimiento posterior para normalizar el nombre del host y del servicio.

## Dónde tuvimos suerte

- El incidente afectó al acceso al panel, no a la ruta de peticiones de Spring Petclinic.
- No implicó ninguna migración de datos ni cambios en la base de datos.
- El modo de fallo era visible a través de una simple comprobación HTTP.
- El historial de manifiestos era lo suficientemente pequeño como para inspeccionarlo rápidamente.

## Acciones a tomar (Action Items)

| ID | Prioridad | Tipo | Responsable | Estado | Fecha de vencimiento | Acción | Criterio de éxito |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PM-2026-06-15-001-A1 | P0 | Mitigar | Responsable de DevOps/SRE | Hecho | 2026-06-15 | Restaurar la ruta pública de Grafana y normalizar la configuración de host/servicio en producción. | `https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/` devuelve una respuesta o redirección válida de Grafana. |
| PM-2026-06-15-001-A2 | P0 | Prevenir | Responsable de DevOps/SRE | Abierto | 2026-06-18 | Hacer obligatorias las pruebas de humo posteriores al despliegue para `/`, `/grafana/` y la URL del panel de SLO en producción. | El despliegue de producción falla automáticamente si alguna ruta requerida devuelve algo distinto de 2xx/3xx o agota el tiempo de espera (timeout). |
| PM-2026-06-15-001-A3 | P1 | Prevenir | Responsable de la plataforma | Abierto | 2026-06-20 | Añadir validación de manifiestos de Kubernetes para nombres y puertos de servicios de backend del Ingress después de renderizar manifiestos. | La integración continua (CI) falla cuando un backend de Ingress hace referencia a un servicio o puerto que está ausente en los manifiestos renderizados. |
| PM-2026-06-15-001-A4 | P1 | Detectar | Responsable de observabilidad | Abierto | 2026-06-21 | Añadir una sonda HTTP de caja negra y una alerta para la ruta pública de Grafana. | La alerta se dispara cuando `/grafana/` no está disponible durante más de 2 minutos. |
| PM-2026-06-15-001-A5 | P2 | Prevenir | Responsable de DevOps/SRE | Abierto | 2026-06-19 | Documentar el contrato de la ruta externa de Grafana en `monitoring/README.md`. | El README lista la URL pública, nombres de los objetos Service/Endpoints de Kubernetes, host esperado y comandos de validación. |

## Lecciones Aprendidas

- El éxito del rollout de Kubernetes demuestra que los despliegues (Deployments) convergieron; no demuestra que cada ruta orientada al usuario u operador funcione.
- Los puntos de conexión (endpoints) de observabilidad forman parte de la superficie de confiabilidad de producción cuando los equipos dependen de ellos para la respuesta a incidentes y evidencia de SLO.
- La revisión libre de culpas debe centrarse en los controles del sistema ausentes: pruebas de humo obligatorias, validación de manifiestos, responsabilidades y alertas.

## Alineación con Google SRE

Este postmortem sigue el enfoque de SRE de Google al documentar el impacto, la línea de tiempo, el desencadenante, la causa raíz, los factores contribuyentes y las acciones medibles con responsables y prioridad. El lenguaje se enfoca intencionadamente en las mejoras del sistema y de los procesos en lugar de asignar culpas personales.

Referencias:

- Libro de SRE de Google, "Postmortem Culture: Learning from Failure": https://sre.google/sre-book/postmortem-culture/
- Libro de trabajo de SRE de Google, "Postmortem Practices for Incident Management": https://sre.google/workbook/postmortem-culture/