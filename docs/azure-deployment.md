# Azure Deployment

The application is published by the main CI/CD workflow with Docker Compose on
the Azure hosts:

- Development: `https://guytho1996-petclinic-dev.eastus2.cloudapp.azure.com`
- Production: `https://guytho1996-petclinic.eastus2.cloudapp.azure.com`

The frontend runs as an Nginx container next to the Spring Boot backend. Nginx
serves the static frontend and proxies application routes such as `/owners`,
`/vets`, and `/actuator` to the internal `petclinic-backend` service.

Runtime frontend configuration is rendered from container environment variables:

- `FRONTEND_APP_ENV`
- `FRONTEND_BACKEND_BASE_URL`, default `same-origin`
- `FRONTEND_GIT_SHA`

The `same-origin` backend setting keeps browser traffic on the Azure hostname
that served the frontend, so changes deployed by the CI/CD pipeline are visible
on the development and production Azure URLs.
