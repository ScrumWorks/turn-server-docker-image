#!/bin/bash
# ACME certificate manager for coturn
# Handles certificate acquisition, renewal, and coturn reload via SIGUSR2

set -e

TURN_DOMAIN="${TURN_DOMAIN}"
ACME_EMAIL="${ACME_EMAIL}"
CERT_DIR="${TURN_CERT_DIR:-/etc/coturn/certs}"
ACME_HOME="/root/.acme.sh"
ACME_BIN="$ACME_HOME/acme.sh"
RENEWAL_CHECK_INTERVAL="${ACME_RENEWAL_INTERVAL:-21600}" # 6 hours default

CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

if [ -z "$TURN_DOMAIN" ]; then
  echo "ACME: TURN_DOMAIN not set, skipping certificate management"
  exit 0
fi

if [ -z "$ACME_EMAIL" ]; then
  echo "ACME: Error: ACME_EMAIL is required when TURN_DOMAIN is set"
  exit 1
fi

if [ -z "$CF_API_TOKEN" ]; then
  echo "ACME: Error: CF_API_TOKEN is required (Cloudflare scoped API token with Zone:DNS:Edit permission)"
  exit 1
fi

# Export Cloudflare credentials for acme.sh
export CF_Token="$CF_API_TOKEN"

mkdir -p "$CERT_DIR"

acme_server_flag=""
if [ "${ACME_STAGING}" = "1" ] || [ "${ACME_STAGING}" = "true" ]; then
  acme_server_flag="--staging"
  echo "ACME: Using Let's Encrypt staging environment"
fi

issue_certificate() {
  echo "ACME: Issuing certificate for $TURN_DOMAIN via Cloudflare DNS-01 challenge"

  "$ACME_BIN" --issue \
    -d "$TURN_DOMAIN" \
    --dns dns_cf \
    $acme_server_flag \
    --keylength 4096 \
    || {
      echo "ACME: Certificate issuance failed"
      return 1
    }

  install_certificate
}

install_certificate() {
  echo "ACME: Installing certificate to $CERT_DIR"

  "$ACME_BIN" --install-cert -d "$TURN_DOMAIN" \
    --fullchain-file "$CERT_FILE" \
    --key-file "$KEY_FILE" \
    --reloadcmd "acme-reload-coturn"

  chmod 600 "$KEY_FILE"
  chmod 644 "$CERT_FILE"

  echo "ACME: Certificate installed successfully"
}

reload_coturn() {
  # Send SIGUSR2 to coturn to reload certificates without restart
  local pid
  pid=$(pgrep -x turnserver 2>/dev/null || true)
  if [ -n "$pid" ]; then
    echo "ACME: Sending SIGUSR2 to coturn (PID $pid) to reload certificates"
    kill -SIGUSR2 "$pid"
  else
    echo "ACME: coturn not running yet, skipping reload"
  fi
}

# Check if certificate already exists and is still valid
certificate_exists() {
  [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]
}

# Initial certificate acquisition
if certificate_exists; then
  echo "ACME: Existing certificate found in $CERT_DIR"
  # Ensure acme.sh knows about this domain for renewals
  if [ -d "$ACME_HOME/${TURN_DOMAIN}_ecc" ] || [ -d "$ACME_HOME/${TURN_DOMAIN}" ]; then
    echo "ACME: ACME registration found, renewals will be handled automatically"
  fi
else
  echo "ACME: No existing certificate found, requesting new one"
  issue_certificate
fi

# Renewal loop - runs in background
echo "ACME: Starting renewal check loop (every ${RENEWAL_CHECK_INTERVAL}s)"
while true; do
  sleep "$RENEWAL_CHECK_INTERVAL"

  echo "ACME: Checking certificate renewal"
  "$ACME_BIN" --renew -d "$TURN_DOMAIN" \
    --dns dns_cf \
    $acme_server_flag \
    2>&1 || true

  # acme.sh --install-cert reloadcmd handles the reload,
  # but we also check explicitly in case it was missed
  if [ -f "$CERT_FILE" ]; then
    reload_coturn
  fi
done
