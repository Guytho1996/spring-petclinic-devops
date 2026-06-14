# Monitoring and SLO Dashboard

This project includes a Prometheus + Grafana stack for the Petclinic service.

## Local Docker Compose

Start the app, Prometheus, and Grafana:

```bash
docker compose up --build
```

Open:

- Grafana through Nginx HTTPS: https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/
- SLO dashboard: https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/d/spring-petclinic-slo/spring-petclinic-slo-dashboard

Prometheus is kept on the internal Docker network. Grafana reaches it through
the provisioned datasource URL `http://prometheus:9090`.

Default Grafana credentials are `admin` / `admin`. Override them with
`GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`.

The dashboard is provisioned automatically from
`monitoring/grafana/dashboards/slo.json` and uses the Prometheus datasource
defined in `monitoring/grafana/provisioning/datasources/prometheus.yml`.

## Kubernetes

The GitHub Actions rolling-update deploy skips `k8s/monitoring.yaml`.
Prometheus and Grafana currently run on the external OCI monitoring server to
keep the single-node development AKS cluster below its CPU quota.

For a manual in-cluster deployment, deploy the application manifests first,
then deploy monitoring:

```bash
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring.yaml
```

Access Grafana and Prometheus with port-forwarding:

```bash
kubectl -n devops-lab port-forward svc/grafana 3000:3000
kubectl -n devops-lab port-forward svc/prometheus 9090:9090
```

## SLOs and Alerts

The dashboard tracks:

- 99.9% availability SLO based on HTTP 5xx responses.
- Error budget remaining for the selected time range.
- Request rate, HTTP 5xx rate, P99 latency, and active backend pods/targets.
- Error budget burn rate.

Prometheus evaluates these alerts:

- `PetclinicHttp5xxErrorRateHigh`: 5xx rate above 1% for 5 minutes.
- `PetclinicErrorBudgetBurnFast`: 99.9% availability budget burning above 10x.
- `PetclinicLatencyP99High`: P99 latency above 1 second for 10 minutes.
