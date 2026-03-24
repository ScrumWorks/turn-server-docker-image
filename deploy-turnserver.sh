#!/bin/bash

internalIp="${INTERNAL_IP:-$(ip a 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)}"
externalIp="${EXTERNAL_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)}"
externalIp="${externalIp:-$internalIp}"

if [ -n "$TURN_SECRET" ]; then
  realm="${TURN_REALM:-turn.example.com}"
elif [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
  realm="${TURN_REALM:-$3}"
else
  echo "Error: No authentication configured."
  echo ""
  echo "Usage (recommended - REST API secret):"
  echo "  docker run -e TURN_SECRET=<secret> -e TURN_REALM=<realm> ..."
  echo ""
  echo "Usage (legacy - static credentials):"
  echo "  docker run ... turn-server <username> <password> <realm>"
  exit 1
fi

port="${TURN_PORT:-80}"
certDir="${TURN_CERT_DIR:-/etc/coturn/certs}"
certFile="$certDir/fullchain.pem"
keyFile="$certDir/privkey.pem"

config="listening-port=$port
listening-ip=$internalIp
relay-ip=$internalIp
external-ip=$externalIp
realm=$realm
server-name=$realm
fingerprint
min-port=25001
max-port=30000
log-file=stdout
verbose"

# TLS configuration
if [ -n "$TURN_DOMAIN" ]; then
  tlsPort="${TURN_TLS_PORT:-5349}"

  # Start ACME manager in background to obtain/renew certificates
  bash /app/acme-manager.sh &
  acmePid=$!

  # Wait for certificate to become available (up to 120 seconds)
  echo "Waiting for TLS certificate..."
  waited=0
  while [ ! -f "$certFile" ] || [ ! -f "$keyFile" ]; do
    if [ $waited -ge 120 ]; then
      echo "Error: Timed out waiting for TLS certificate"
      exit 1
    fi
    # Check if ACME manager is still running
    if ! kill -0 "$acmePid" 2>/dev/null; then
      echo "Error: ACME manager exited before obtaining certificate"
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo "TLS certificate ready"

  config="$config
tls-listening-port=$tlsPort
cert=$certFile
pkey=$keyFile"
else
  config="$config
no-tls
no-dtls"
fi

if [ -n "$TURN_SECRET" ]; then
  config="$config
use-auth-secret
static-auth-secret=$TURN_SECRET"

  echo "$config" | tee /etc/turnserver.conf

  echo "TURN server starting (secret auth). IP: $externalIp, port: $port, realm: $realm"
  [ -n "$TURN_DOMAIN" ] && echo "TLS enabled on port ${tlsPort} for domain $TURN_DOMAIN"
else
  config="$config
lt-cred-mech
userdb=/var/lib/turn/turndb"

  echo "$config" | tee /etc/turnserver.conf

  turnadmin -a -u "$1" -p "$2" -r "$realm"

  echo "TURN server starting (legacy auth). IP: $externalIp, port: $port, username: $1"
  [ -n "$TURN_DOMAIN" ] && echo "TLS enabled on port ${tlsPort} for domain $TURN_DOMAIN"
fi

exec turnserver
