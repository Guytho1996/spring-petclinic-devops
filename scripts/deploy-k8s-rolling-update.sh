#!/usr/bin/env bash

set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
MANIFEST_DIR="${K8S_MANIFEST_DIR:-k8s}"
K8S_NAMESPACE="${K8S_NAMESPACE:-devops-lab}"
IMAGE_TAG="${IMAGE_TAG:-${GITHUB_SHA:-}}"
FRONTEND_APP_ENV="${FRONTEND_APP_ENV:-production}"
FRONTEND_BACKEND_BASE_URL="${FRONTEND_BACKEND_BASE_URL:-same-origin}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-10m}"
INGRESS_HOST="${INGRESS_HOST:-petclinic.local}"
INGRESS_TLS_SECRET="${INGRESS_TLS_SECRET:-petclinic-frontend-tls}"

if [[ -z "${BACKEND_IMAGE:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  BACKEND_IMAGE="${REGISTRY:-ghcr.io}/${GITHUB_REPOSITORY,,}"
fi

if [[ -z "${FRONTEND_IMAGE:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  FRONTEND_IMAGE="${REGISTRY:-ghcr.io}/${GITHUB_REPOSITORY,,}-frontend"
fi

required_vars=(
  IMAGE_TAG
  BACKEND_IMAGE
  FRONTEND_IMAGE
  POSTGRES_URL
  POSTGRES_USER
  POSTGRES_PASS
  APP_CORS_ALLOWED_ORIGINS
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required environment variable: $var_name" >&2
    exit 2
  fi
done

if [[ ! -d "$MANIFEST_DIR" ]]; then
  echo "Kubernetes manifest directory not found: $MANIFEST_DIR" >&2
  exit 2
fi

rendered_dir="$(mktemp -d)"
trap 'rm -rf "$rendered_dir"' EXIT

echo "Deploying ${BACKEND_IMAGE}:${IMAGE_TAG} and ${FRONTEND_IMAGE}:${IMAGE_TAG} to namespace ${K8S_NAMESPACE}"

rollout_status() {
  local deployment_name="$1"

  if ! "$KUBECTL_BIN" -n "$K8S_NAMESPACE" rollout status "deployment/${deployment_name}" --timeout="$ROLLOUT_TIMEOUT"; then
    echo "Rollout failed for deployment/${deployment_name}; collecting Kubernetes diagnostics" >&2
    "$KUBECTL_BIN" -n "$K8S_NAMESPACE" describe "deployment/${deployment_name}" >&2 || true
    "$KUBECTL_BIN" -n "$K8S_NAMESPACE" get deploy,rs,pods,hpa,pdb -o wide >&2 || true
    "$KUBECTL_BIN" -n "$K8S_NAMESPACE" get events --sort-by=.lastTimestamp >&2 || true
    return 1
  fi
}

"$KUBECTL_BIN" create namespace "$K8S_NAMESPACE" --dry-run=client -o yaml | "$KUBECTL_BIN" apply -f -

"$KUBECTL_BIN" -n "$K8S_NAMESPACE" create configmap petclinic-config \
  --from-literal=SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-postgres}" \
  --from-literal=database="${DATABASE:-postgres}" \
  --from-literal=POSTGRES_URL="$POSTGRES_URL" \
  --from-literal=APP_CORS_ALLOWED_ORIGINS="$APP_CORS_ALLOWED_ORIGINS" \
  --from-literal=FRONTEND_APP_ENV="$FRONTEND_APP_ENV" \
  --from-literal=FRONTEND_BACKEND_BASE_URL="$FRONTEND_BACKEND_BASE_URL" \
  --dry-run=client \
  -o yaml | "$KUBECTL_BIN" apply -f -

"$KUBECTL_BIN" -n "$K8S_NAMESPACE" create secret generic petclinic-secrets \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --from-literal=POSTGRES_PASS="$POSTGRES_PASS" \
  --dry-run=client \
  -o yaml | "$KUBECTL_BIN" apply -f -

if [[ -n "${INGRESS_TLS_CERT_PATH:-}" || -n "${INGRESS_TLS_KEY_PATH:-}" ]]; then
  if [[ -z "${INGRESS_TLS_CERT_PATH:-}" || -z "${INGRESS_TLS_KEY_PATH:-}" ]]; then
    echo "Both INGRESS_TLS_CERT_PATH and INGRESS_TLS_KEY_PATH are required when configuring Ingress TLS" >&2
    exit 2
  fi

  "$KUBECTL_BIN" -n "$K8S_NAMESPACE" create secret tls "$INGRESS_TLS_SECRET" \
    --cert="$INGRESS_TLS_CERT_PATH" \
    --key="$INGRESS_TLS_KEY_PATH" \
    --dry-run=client \
    -o yaml | "$KUBECTL_BIN" apply -f -
fi

for manifest in "$MANIFEST_DIR"/*.yaml; do
  manifest_name="$(basename "$manifest")"
  case "$manifest_name" in
    namespace.yaml|configmap.yaml|secrets.yaml|secrets.example.yaml|monitoring.yaml)
      continue
      ;;
  esac

  sed \
    -e "s#namespace: devops-lab#namespace: ${K8S_NAMESPACE}#g" \
    -e "s#ghcr.io/guytho1996/spring-petclinic-devops:IMAGE_TAG#${BACKEND_IMAGE}:${IMAGE_TAG}#g" \
    -e "s#ghcr.io/guytho1996/spring-petclinic-devops-frontend:IMAGE_TAG#${FRONTEND_IMAGE}:${IMAGE_TAG}#g" \
    -e "s#IMAGE_TAG#${IMAGE_TAG}#g" \
    -e "s#petclinic.local#${INGRESS_HOST}#g" \
    -e "s#petclinic-frontend-tls#${INGRESS_TLS_SECRET}#g" \
    "$manifest" > "$rendered_dir/$manifest_name"

  "$KUBECTL_BIN" apply -f "$rendered_dir/$manifest_name"
done

"$KUBECTL_BIN" -n "$K8S_NAMESPACE" set image deployment/petclinic-backend \
  "backend=${BACKEND_IMAGE}:${IMAGE_TAG}"
"$KUBECTL_BIN" -n "$K8S_NAMESPACE" set image deployment/petclinic-frontend \
  "frontend=${FRONTEND_IMAGE}:${IMAGE_TAG}"

rollout_status petclinic-backend
rollout_status petclinic-frontend

"$KUBECTL_BIN" -n "$K8S_NAMESPACE" get deploy,rs,pods,hpa,pdb

if [[ -n "${SMOKE_TEST_URL:-}" ]]; then
  echo "Running smoke test: ${SMOKE_TEST_URL}"
  for attempt in $(seq 1 24); do
    if curl -kfsS "$SMOKE_TEST_URL"; then
      exit 0
    fi
    sleep 5
  done
  echo "Smoke test failed after 24 attempts: ${SMOKE_TEST_URL}" >&2
  exit 1
fi
