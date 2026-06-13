# GitHub Pages Frontend

This repository publishes a static frontend from `frontend/` with GitHub Actions.
The Spring Boot backend remains deployed separately through Docker Compose or a
Kubernetes Ingress.

## Runtime Configuration

Set repository variables in GitHub:

- `PAGES_BACKEND_BASE_URL`: public backend URL, for example `https://api.example.com`
- `PAGES_FRONTEND_BASE_PATH`: optional Pages base path, for example `/spring-petclinic-devops/`
- `PAGES_APP_ENV`: label shown in the frontend, for example `production`
- `PAGES_FRONTEND_ORIGIN`: frontend origin allowed by backend CORS, for example `https://guytho1996.github.io`
- `PAGES_CUSTOM_DOMAIN`: optional Pages custom domain, for example `app.example.com`

The Pages artifact also creates `/owners/find/` as a static entry route. Because
GitHub Pages cannot proxy requests to Spring Boot, that route redirects the
browser to `${PAGES_BACKEND_BASE_URL}/owners/find`.

For a custom subdomain, configure GitHub Pages with the custom domain and create
a DNS `CNAME` record that points the subdomain to `guytho1996.github.io`.
When `PAGES_CUSTOM_DOMAIN` is set, the Pages workflow uses `GH_ADMIN_TOKEN` to
apply the custom domain in the repository Pages settings.

## Backend Requirements

The Pages frontend can only call public HTTPS endpoints. The backend should be
published behind an Ingress or reverse proxy and should allow the Pages origin in
CORS when browser calls to `/actuator/health` or future JSON APIs are required.

## Containerized Frontend

The same static frontend can also run as a separate Nginx container:

- `app`: Spring Boot backend container, internal on port `8080`
- `frontend`: Nginx container, public on port `8080` by default

Docker Compose publishes only the frontend. Nginx serves the static files and
proxies backend paths such as `/actuator`, `/owners`, and `/vets` to the internal
`petclinic-backend` service. This keeps the JVM backend off the public Docker
port while preserving the existing Petclinic routes.

In Kubernetes, the frontend and backend have separate Deployments, Services,
HPAs, and PDBs:

- `petclinic-frontend`: Nginx static frontend, scales up to 10 replicas
- `petclinic-backend`: Spring Boot API/app, scales up to 6 replicas
- `petclinic-ingress`: routes public traffic to the frontend service

The frontend container uses runtime variables:

- `FRONTEND_APP_ENV`
- `FRONTEND_BACKEND_BASE_URL`, default `same-origin`
- `FRONTEND_GIT_SHA`
