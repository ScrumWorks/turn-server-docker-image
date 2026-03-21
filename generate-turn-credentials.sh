#!/bin/bash
# Generate temporary TURN credentials using HMAC-SHA1 (RFC 5389 long-term credentials)
# Usage: ./generate-turn-credentials.sh <secret> [lifetime_seconds]

SECRET="${1:?Usage: $0 <secret> [lifetime_seconds]}"
LIFETIME="${2:-86400}"

EXPIRY=$(( $(date +%s) + LIFETIME ))
PASSWORD=$(echo -n "$EXPIRY" | openssl dgst -sha1 -hmac "$SECRET" -binary | base64)

echo "username: $EXPIRY"
echo "password: $PASSWORD"
echo "expires:  $(date -r "$EXPIRY" 2>/dev/null || date -d "@$EXPIRY" 2>/dev/null)"
