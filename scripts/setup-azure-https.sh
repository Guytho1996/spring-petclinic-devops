#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-dev-ops}"
PUBLIC_IP_NAME="${AZURE_PUBLIC_IP_NAME:-dev-ops-project-ip}"
NSG_NAME="${AZURE_NSG_NAME:-dev-ops-project-nsg}"
DNS_LABEL="${AZURE_DNS_LABEL:-guytho1996-petclinic}"
TLS_DIR="${PETCLINIC_TLS_DIR:-/etc/petclinic/tls}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

sudo_if_needed() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

docker_compose() {
  if docker ps >/dev/null 2>&1; then
    docker compose "$@"
  else
    sudo docker compose "$@"
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  touch "$ENV_FILE"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

create_or_update_nsg_rule() {
  local name="$1"
  local priority="$2"
  local port="$3"

  if az network nsg rule show \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "$name" >/dev/null 2>&1; then
    az network nsg rule update \
      --resource-group "$RESOURCE_GROUP" \
      --nsg-name "$NSG_NAME" \
      --name "$name" \
      --priority "$priority" \
      --access Allow \
      --direction Inbound \
      --protocol Tcp \
      --source-address-prefixes Internet \
      --source-port-ranges '*' \
      --destination-address-prefixes '*' \
      --destination-port-ranges "$port" >/dev/null
  else
    az network nsg rule create \
      --resource-group "$RESOURCE_GROUP" \
      --nsg-name "$NSG_NAME" \
      --name "$name" \
      --priority "$priority" \
      --access Allow \
      --direction Inbound \
      --protocol Tcp \
      --source-address-prefixes Internet \
      --source-port-ranges '*' \
      --destination-address-prefixes '*' \
      --destination-port-ranges "$port" >/dev/null
  fi
}

wait_for_dns() {
  local fqdn="$1"
  local expected_ip="$2"
  local resolved=""

  for _ in $(seq 1 30); do
    resolved="$(getent ahostsv4 "$fqdn" | awk '{ print $1; exit }' || true)"
    if [[ "$resolved" == "$expected_ip" ]]; then
      return 0
    fi
    sleep 5
  done

  echo "DNS for $fqdn did not resolve to $expected_ip in time. Last value: ${resolved:-none}" >&2
  exit 1
}

install_certbot() {
  if command -v certbot >/dev/null 2>&1; then
    return 0
  fi

  sudo_if_needed apt-get update
  sudo_if_needed env DEBIAN_FRONTEND=noninteractive apt-get install -y certbot
}

install_cert_files() {
  local fqdn="$1"

  sudo_if_needed install -d -m 0755 "$TLS_DIR"
  sudo_if_needed install -m 0644 "/etc/letsencrypt/live/$fqdn/fullchain.pem" "$TLS_DIR/nginx.crt"
  sudo_if_needed install -m 0600 "/etc/letsencrypt/live/$fqdn/privkey.pem" "$TLS_DIR/nginx.key"
}

install_renewal_hook() {
  local fqdn="$1"
  local hook_path="/etc/letsencrypt/renewal-hooks/deploy/petclinic-frontend.sh"

  sudo_if_needed install -d -m 0755 "$(dirname "$hook_path")"
  sudo_if_needed tee "$hook_path" >/dev/null <<HOOK
#!/usr/bin/env bash
set -euo pipefail

case " \${RENEWED_DOMAINS:-} " in
  *" $fqdn "*) ;;
  *) exit 0 ;;
esac

install -d -m 0755 "$TLS_DIR"
install -m 0644 "/etc/letsencrypt/live/$fqdn/fullchain.pem" "$TLS_DIR/nginx.crt"
install -m 0600 "/etc/letsencrypt/live/$fqdn/privkey.pem" "$TLS_DIR/nginx.key"

cd "$REPO_DIR"
if docker ps >/dev/null 2>&1; then
  docker compose exec -T frontend nginx -s reload || docker compose up -d frontend
else
  sudo docker compose exec -T frontend nginx -s reload || sudo docker compose up -d frontend
fi
HOOK
  sudo_if_needed chmod 0755 "$hook_path"
}

request_certificate() {
  local fqdn="$1"
  local args=(
    certonly
    --standalone
    --non-interactive
    --agree-tos
    --preferred-challenges
    http
    -d
    "$fqdn"
  )

  if [[ -n "$LETSENCRYPT_EMAIL" ]]; then
    args+=(--email "$LETSENCRYPT_EMAIL")
  else
    args+=(--register-unsafely-without-email)
  fi

  sudo_if_needed certbot "${args[@]}"
}

main() {
  require_command az
  require_command getent
  require_command awk
  require_command docker

  echo "Assigning Azure DNS label '$DNS_LABEL' to $PUBLIC_IP_NAME..."
  az network public-ip update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --dns-name "$DNS_LABEL" >/dev/null

  local public_ip
  local fqdn
  public_ip="$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query ipAddress -o tsv)"
  fqdn="$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query dnsSettings.fqdn -o tsv)"

  if [[ -z "$fqdn" ]]; then
    echo "Azure did not return a DNS hostname for $PUBLIC_IP_NAME." >&2
    exit 1
  fi

  echo "Opening Azure NSG ports 80 and 443..."
  create_or_update_nsg_rule Allow-HTTP-80 1000 80
  create_or_update_nsg_rule Allow-HTTPS-443 1010 443

  echo "Waiting for DNS: $fqdn -> $public_ip..."
  wait_for_dns "$fqdn" "$public_ip"

  echo "Installing certbot if required..."
  install_certbot

  echo "Requesting Let's Encrypt certificate for $fqdn..."
  request_certificate "$fqdn"

  echo "Installing certificate files into $TLS_DIR..."
  install_cert_files "$fqdn"
  install_renewal_hook "$fqdn"

  set_env_value FRONTEND_TLS_CERT_PATH "$TLS_DIR/nginx.crt"
  set_env_value FRONTEND_TLS_KEY_PATH "$TLS_DIR/nginx.key"
  set_env_value FRONTEND_APP_ENV production
  set_env_value FRONTEND_BACKEND_BASE_URL same-origin

  echo "Recreating frontend with the trusted certificate mounted..."
  cd "$REPO_DIR"
  docker_compose up -d frontend

  echo "HTTPS backend is ready: https://$fqdn"
}

main "$@"
