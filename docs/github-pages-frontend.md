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

The Pages frontend can only call public HTTPS endpoints with a browser-trusted
certificate. A raw IP address with a self-signed certificate will still fail in
the browser, even if `curl -k` works.

For the Azure VM deployment in this repository, assign a DNS label to the public
IP and issue a Let's Encrypt certificate:

```bash
AZURE_DNS_LABEL=guytho1996-petclinic \
LETSENCRYPT_EMAIL=you@example.com \
./scripts/setup-azure-https.sh
```

The script configures the public IP DNS label, opens NSG ports `80` and `443`,
requests the certificate, mounts it into the frontend container through `.env`,
and installs a Certbot renewal hook that reloads Nginx.

After the certificate is active, set the Pages backend variable to the trusted
HTTPS hostname. The Pages build rejects `http://` backend URLs because browsers
block those calls from GitHub Pages.

```bash
gh variable set PAGES_BACKEND_BASE_URL \
  --repo Guytho1996/spring-petclinic-devops \
  --body https://guytho1996-petclinic.eastus2.cloudapp.azure.com
```

The backend should allow the Pages origin in CORS when browser calls to
`/owners`, `/actuator/health`, or future JSON APIs are required.

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
