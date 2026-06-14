# Azure Deployment

The application is published by the main CI/CD workflow to Azure Kubernetes
Service with Kubernetes rolling updates:

- Development: `https://guytho1996-petclinic-dev.eastus2.cloudapp.azure.com`
- Production: `https://guytho1996-petclinic.eastus2.cloudapp.azure.com`

The frontend runs as an Nginx pod next to the Spring Boot backend Deployment.
Nginx serves the static frontend and proxies application routes such as
`/owners`, `/vets`, and `/actuator` to the internal `petclinic-backend` Service.

Deployment flow:

1. GitHub Actions builds and scans the backend/frontend images.
2. Images are pushed to GHCR with the commit SHA.
3. Development AKS is updated automatically.
4. Production AKS is updated after the `production` environment approval.
5. Kubernetes replaces pods gradually with `RollingUpdate`,
   `maxUnavailable: 0`, and `maxSurge: 1`.

Runtime frontend configuration is rendered from container environment variables:

- `FRONTEND_APP_ENV`
- `FRONTEND_BACKEND_BASE_URL`, default `same-origin`
- `FRONTEND_GIT_SHA`

The `same-origin` backend setting keeps browser traffic on the Azure hostname
that served the frontend, so changes deployed by the CI/CD pipeline are visible
on the development and production Azure URLs.
