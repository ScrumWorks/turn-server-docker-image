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

config="listening-port=$port
listening-ip=$internalIp
relay-ip=$internalIp
external-ip=$externalIp
realm=$realm
server-name=$realm
fingerprint
no-tls
no-dtls
min-port=25001
max-port=30000
log-file=stdout
verbose"

if [ -n "$TURN_SECRET" ]; then
  config="$config
use-auth-secret
static-auth-secret=$TURN_SECRET"

  echo "$config" | tee /etc/turnserver.conf

  echo "TURN server starting (secret auth). IP: $externalIp, port: $port, realm: $realm"
else
  config="$config
lt-cred-mech
userdb=/var/lib/turn/turndb"

  echo "$config" | tee /etc/turnserver.conf

  turnadmin -a -u "$1" -p "$2" -r "$realm"

  echo "TURN server starting (legacy auth). IP: $externalIp, port: $port, username: $1"
fi

exec turnserver
