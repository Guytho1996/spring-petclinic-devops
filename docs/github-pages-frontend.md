# GitHub Pages Frontend

This repository publishes a static frontend from `frontend/` with GitHub Actions.
The Spring Boot backend remains deployed separately through Docker Compose or a
Kubernetes Ingress.

## Runtime Configuration

Set repository variables in GitHub:

- `PAGES_BACKEND_BASE_URL`: public backend URL, for example `https://api.example.com`
- `PAGES_APP_ENV`: label shown in the frontend, for example `production`
- `PAGES_FRONTEND_ORIGIN`: frontend origin allowed by backend CORS, for example `https://guytho1996.github.io`
- `PAGES_CUSTOM_DOMAIN`: optional Pages custom domain, for example `app.example.com`

For a custom subdomain, configure GitHub Pages with the custom domain and create
a DNS `CNAME` record that points the subdomain to `guytho1996.github.io`.
When `PAGES_CUSTOM_DOMAIN` is set, the Pages workflow uses `GH_ADMIN_TOKEN` to
apply the custom domain in the repository Pages settings.

## Backend Requirements

The Pages frontend can only call public HTTPS endpoints. The backend should be
published behind an Ingress or reverse proxy and should allow the Pages origin in
CORS when browser calls to `/actuator/health` or future JSON APIs are required.
