# Kubernetes Rolling Update

La tarea del proyecto integrador pide manifiestos Kubernetes con Deployment
usando rolling update, HPA de 2 a 10 replicas, probes, limites de recursos,
ConfigMap, Secrets y PodDisruptionBudget.

En este repositorio el despliegue se divide en dos Deployments:

- `petclinic-backend`: Spring Boot, puerto 8080.
- `petclinic-frontend`: Nginx, puerto 80.

Ambos usan `strategy.type: RollingUpdate` con `maxUnavailable: 0` y
`maxSurge: 1`. Esto mantiene la capacidad actual mientras Kubernetes crea un
pod nuevo, espera a que su `readinessProbe` pase y luego elimina un pod de la
version anterior.

## Aplicar los manifiestos

```bash
kubectl apply -f k8s/
kubectl get pods,hpa,pdb -n devops-lab
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
