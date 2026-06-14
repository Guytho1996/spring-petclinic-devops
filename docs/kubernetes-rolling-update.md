# Kubernetes Rolling Update

La tarea del proyecto integrador pide manifiestos Kubernetes con Deployment
usando rolling update, HPA de 2 a 10 replicas, probes, limites de recursos,
ConfigMap, Secrets y PodDisruptionBudget.

En este repositorio el despliegue se divide en dos Deployments:

- `petclinic-backend`: Spring Boot, puerto 8080.
- `petclinic-frontend`: Nginx, puerto 80.

El `petclinic-backend` usa `strategy.type: RollingUpdate` con
`maxUnavailable: 1` y `maxSurge: 0`. En el cluster staging de un solo nodo esto
evita depender de capacidad extra para crear pods temporales durante el
despliegue, manteniendo al menos una replica disponible.

El `petclinic-frontend` usa `maxUnavailable: 0` y `maxSurge: 1`, ya que sus
requests son pequenos y el surge cabe en el nodo actual.

## Ejecucion desde CI/CD

El workflow `.github/workflows/ci-cd.yml` ejecuta el rolling update real en AKS:

- `deploy-dev`: despliegue automatico al cluster de development/staging.
- `deploy-prod`: despliegue al cluster de production, protegido por el
  environment `production` de GitHub Actions.

Ambos jobs ejecutan `scripts/deploy-k8s-rolling-update.sh`. El script:

1. Configura `ConfigMap` y `Secret` desde GitHub Secrets.
2. Renderiza `IMAGE_TAG` con el SHA del commit.
3. Aplica los manifiestos Kubernetes.
4. Ejecuta `kubectl set image`.
5. Espera `kubectl rollout status` para backend y frontend.

Secrets necesarios:

- `AZURE_CREDENTIALS`
- `DEV_POSTGRES_URL`, `DEV_POSTGRES_USER`, `DEV_POSTGRES_PASS`
- `PROD_POSTGRES_URL`, `PROD_POSTGRES_USER`, `PROD_POSTGRES_PASS`

Variables opcionales de environment/repository:

- `DEV_AKS_RESOURCE_GROUP`, `DEV_AKS_CLUSTER_NAME`
- `PROD_AKS_RESOURCE_GROUP`, `PROD_AKS_CLUSTER_NAME`
- `DEV_K8S_NAMESPACE`, `PROD_K8S_NAMESPACE`
- `DEV_INGRESS_HOST`, `PROD_INGRESS_HOST`
- `INGRESS_TLS_SECRET`
- `INGRESS_TLS_CERT_PATH`, `INGRESS_TLS_KEY_PATH`

## Aplicar los manifiestos manualmente

```bash
export IMAGE_TAG=<sha>
export BACKEND_IMAGE=ghcr.io/guytho1996/spring-petclinic-devops
export FRONTEND_IMAGE=ghcr.io/guytho1996/spring-petclinic-devops-frontend
export POSTGRES_URL='jdbc:postgresql://...:5432/petclinic_dev?sslmode=require'
export POSTGRES_USER='<postgres-user>'
export POSTGRES_PASS='<postgres-password>'
export APP_CORS_ALLOWED_ORIGINS='https://guytho1996-petclinic-dev.eastus2.cloudapp.azure.com'

./scripts/deploy-k8s-rolling-update.sh
```

## Desplegar una nueva version

Reemplaza `IMAGE_TAG` por el SHA o tag publicado en GHCR:

```bash
kubectl -n devops-lab set image deployment/petclinic-backend \
  backend=ghcr.io/guytho1996/spring-petclinic-devops:IMAGE_TAG

kubectl -n devops-lab rollout status deployment/petclinic-backend
```

Para el frontend:

```bash
kubectl -n devops-lab set image deployment/petclinic-frontend \
  frontend=ghcr.io/guytho1996/spring-petclinic-devops-frontend:IMAGE_TAG

kubectl -n devops-lab rollout status deployment/petclinic-frontend
```

## Verificar y volver atras

```bash
kubectl -n devops-lab rollout history deployment/petclinic-backend
kubectl -n devops-lab rollout undo deployment/petclinic-backend
kubectl -n devops-lab rollout status deployment/petclinic-backend
```

El `Service` selecciona por `app` y `component`, no por `version`. Esto es
intencional: durante un rolling update deben recibir trafico los pods viejos y
nuevos que ya esten listos.
