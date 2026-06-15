# Blameless Postmortem: INC-2026-06-15-001

## Metadata

| Field | Value |
| --- | --- |
| Incident ID | INC-2026-06-15-001 |
| Title | Public Grafana route unavailable after Kubernetes ingress/service configuration drift |
| Status | Completed for Proyecto Integrador evidence |
| Date | 2026-06-15 |
| Environment | Production demo |
| Severity | SEV2 |
| Duration | 28m 26s, from 2026-06-15 00:18:05 UTC to 2026-06-15 00:46:31 UTC |
| Services affected | Kubernetes Ingress `/grafana`, external Grafana service, SLO/DORA dashboard access |
| Services not affected | Spring Petclinic backend, frontend, PostgreSQL data |
| Incident commander | DevOps/SRE owner |
| Postmortem owner | DevOps/SRE owner |
| Related evidence | `monitoring/dora/incidents.json`, `k8s/ingress.yaml`, `k8s/external-grafana.yaml`, `k8s/grafana-root-redirect.yaml` |

## Summary

On 2026-06-15, the public Grafana route used by the Spring Petclinic
DevOps project became unavailable after Kubernetes ingress and service
configuration for the external Grafana instance drifted from the public
production route contract. The incident was detected during post-deploy
verification when the team attempted to open the public SLO dashboard at
`/grafana`.

This was a simulated incident for the Proyecto Integrador. The application
itself continued serving traffic, and no customer or clinical data was lost.
The reliability impact was still important because the team temporarily lost
its main SLO/DORA dashboard during a deployment window.

The root cause was a missing automated verification step for external
observability routes. The CI/CD pipeline verified build, tests, security scans,
image publication, Kubernetes rollout status, and an optional smoke URL, but it
did not validate that every public ingress path routed to an existing service
and externally reachable endpoint.

## Impact

- Public access to Grafana and the SLO dashboard was degraded for 28m 26s.
- Demo stakeholders could not validate the SLO/DORA dashboard through the
  production URL during the incident window.
- Prometheus metrics and application runtime were not intentionally changed by
  the incident.
- There was no data loss, no database corruption, and no known impact to
  Petclinic owner, pet, visit, or vet workflows.
- The incident increased operational risk because the dashboard used to inspect
  SLOs was unavailable while the team was diagnosing the release.

## Trigger

The trigger was a Kubernetes manifest change that adjusted the external Grafana
service naming and ingress route configuration. The relevant change sequence
included:

- `3c40b28`: added `external-grafana-service` and the `/grafana` ingress path.
- `7c15ca5`: renamed the Grafana service/endpoint and ingress backend to
  `grafana`.
- `420de24`: added a root redirect for Grafana that still referenced the local
  host pattern.
- `6dae69c`: normalized the public production host and restored the
  `external-grafana-service` contract in the manifests.

## Detection

Detection was manual. During post-deploy verification, the public Grafana URL
did not return the expected dashboard. The existing deployment script waited
for Kubernetes rollout status, but the checks did not cover this external
Grafana route. That means the deployment could be "green" while the dashboard
path was still broken.

Recommended commands used to confirm this class of failure:

```bash
curl -kI https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/
kubectl -n devops-lab get ingress petclinic-ingress grafana-root-redirect -o wide
kubectl -n devops-lab get svc,endpoints external-grafana-service grafana -o wide
kubectl -n devops-lab describe ingress petclinic-ingress
```

## Timeline

| Time (UTC) | Event |
| --- | --- |
| 2026-06-14 23:35:20 | `3c40b28` added `external-grafana-service` and exposed `/grafana` through Ingress. |
| 2026-06-14 23:55:44 | `7c15ca5` changed the Grafana service, endpoint, and ingress backend name to `grafana`. |
| 2026-06-15 00:18:05 | The public Grafana route failed post-deploy verification. Incident `INC-2026-06-15-001` was opened as SEV2. |
| 2026-06-15 00:20:00 | Non-essential deployment changes were paused while the team checked Ingress, Service, and Endpoints resources. |
| 2026-06-15 00:28:00 | The team identified that rollout status did not validate the external dashboard route and that the route contract had drifted. |
| 2026-06-15 00:35:02 | `06e79dd` was created during mitigation work to update the external Grafana configuration record. |
| 2026-06-15 00:46:31 | Public Grafana access was restored. MTTR recorded for DORA: 28m 26s. |
| 2026-06-15 01:45:20 | `420de24` added a Grafana root redirect manifest, exposing remaining host/route configuration debt. |
| 2026-06-15 02:11:35 | `6dae69c` made the durable manifest follow-up by using the production host and restoring the external Grafana service naming contract. |

## Root Cause

### Direct technical cause

The public `/grafana` route was not covered by automated post-deploy validation,
so ingress, service, endpoint, and redirect changes could be applied even when
the public dashboard route did not match the production access pattern.

### Systemic root cause

The deployment process treated Kubernetes rollout success as sufficient
evidence of production readiness. That was not enough for this topology because
Grafana runs as an external service behind Kubernetes Service/Endpoints objects
and an Ingress path. The route depended on a contract across multiple manifests,
but the repository did not have a contract test, manifest policy, or blackbox
probe for that path.

### Contributing factors

- `SMOKE_TEST_URL` supported only optional URL checks and was not required for
  production deployment.
- The public `/grafana` route was not included in the smoke-test scope.
- The external Grafana integration used a static endpoint IP, which made the
  route more sensitive to manually maintained Service/Endpoints configuration.
- The root redirect and main ingress route could drift independently.
- No CI check verified that every Ingress backend service name and port existed
  in the rendered Kubernetes manifests.

## 5 Whys

| Why | Answer |
| --- | --- |
| 1. Why was Grafana unavailable through the public URL? | The public `/grafana` route did not resolve to the expected external Grafana backend after ingress/service configuration changes. |
| 2. Why did the route point to an invalid or unexpected backend/host contract? | Multiple manifests controlled the Grafana route, service, endpoint, and redirect, and they were changed without one automated contract check covering all of them. |
| 3. Why did the deployment pipeline allow that change to reach production? | The pipeline waited for backend/frontend rollout status, but rollout status does not prove that an external Ingress path is reachable. |
| 4. Why was there no route-level validation? | The smoke-test design focused on the application path and treated observability routes as supporting infrastructure, not production-facing reliability dependencies. |
| 5. Why was the observability route not treated as a release contract? | Ownership and acceptance criteria for externally exposed monitoring endpoints were not documented in the deployment runbook or CI/CD quality gates. |

## What Went Well

- The incident was detected during post-deploy verification, before the demo
  relied on Grafana screenshots as final evidence.
- Application traffic and database state were isolated from the Grafana route
  issue.
- The repo already had DORA incident storage, making MTTR and CFR auditable.
- Kubernetes manifests were versioned, so the team could reconstruct the change
  sequence from commit history.

## What Went Poorly

- Detection was manual instead of alert-driven.
- The deployment pipeline did not require a production smoke test for
  `/grafana`.
- The route depended on several manifests, but the repo had no validation that
  Ingress backends referenced existing Services and ports.
- The first mitigation work did not fully close the durable configuration gap;
  a later follow-up was needed to normalize host and service naming.

## Where We Got Lucky

- The incident affected dashboard access, not the Spring Petclinic request path.
- No data migration or database change was involved.
- The failure mode was visible through a simple HTTP check.
- The manifest history was small enough to inspect quickly.

## Action Items

| ID | Priority | Type | Owner | Status | Due date | Action | Success criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PM-2026-06-15-001-A1 | P0 | Mitigate | DevOps/SRE owner | Done | 2026-06-15 | Restore public Grafana route and normalize production host/service configuration. | `https://guytho1996-petclinic.eastus2.cloudapp.azure.com/grafana/` returns a valid Grafana response or redirect. |
| PM-2026-06-15-001-A2 | P0 | Prevent | DevOps/SRE owner | Open | 2026-06-18 | Make post-deploy smoke tests mandatory for `/`, `/grafana/`, and the SLO dashboard URL in production. | Production deploy fails automatically if any required route returns non-2xx/3xx or times out. |
| PM-2026-06-15-001-A3 | P1 | Prevent | Platform owner | Open | 2026-06-20 | Add Kubernetes manifest validation for Ingress backend service names and ports after rendering manifests. | CI fails when an Ingress backend references a Service or port that is absent from the rendered manifests. |
| PM-2026-06-15-001-A4 | P1 | Detect | Observability owner | Open | 2026-06-21 | Add a blackbox HTTP probe and alert for the public Grafana route. | Alert fires when `/grafana/` is unavailable for more than 2 minutes. |
| PM-2026-06-15-001-A5 | P2 | Prevent | DevOps/SRE owner | Open | 2026-06-19 | Document the external Grafana route contract in `monitoring/README.md`. | README lists the public URL, Kubernetes Service/Endpoints object names, expected host, and validation commands. |

## Lessons Learned

- Kubernetes rollout success proves that Deployments converged; it does not
  prove that every user-facing or operator-facing route works.
- Observability endpoints are part of the production reliability surface when
  teams depend on them for incident response and SLO evidence.
- Blameless review should focus on the missing system controls: mandatory smoke
  tests, manifest validation, ownership, and alerting.

## Google SRE Alignment

This postmortem follows the Google SRE approach by documenting impact,
timeline, trigger, root cause, contributing factors, and measurable action
items with ownership and priority. The language intentionally focuses on system
and process improvements instead of assigning personal blame.

References:

- Google SRE Book, "Postmortem Culture: Learning from Failure": https://sre.google/sre-book/postmortem-culture/
- Google SRE Workbook, "Postmortem Practices for Incident Management": https://sre.google/workbook/postmortem-culture/