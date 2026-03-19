internalIp="${INTERNAL_IP:-$(ip a 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)}"
externalIp="${EXTERNAL_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)}"
externalIp="${externalIp:-$internalIp}"

if [ -n "$TURN_SECRET" ]; then
  realm="${TURN_REALM:-turn.example.com}"

  echo "listening-port=80
listening-ip=$internalIp
relay-ip=$internalIp
external-ip=$externalIp
realm=$realm
server-name=$realm
use-auth-secret
static-auth-secret=$TURN_SECRET
fingerprint
no-tls
no-dtls
min-port=25001
max-port=30000
log-file=stdout
verbose
" | tee /etc/turnserver.conf

  echo "TURN server starting (secret auth). IP: $externalIp, realm: $realm"
elif [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
  realm="${TURN_REALM:-$3}"

  echo "listening-port=80
listening-ip=$internalIp
relay-ip=$internalIp
external-ip=$externalIp
realm=$realm
server-name=$realm
lt-cred-mech
fingerprint
no-tls
no-dtls
userdb=/var/lib/turn/turndb
min-port=25001
max-port=30000
log-file=stdout
verbose
" | tee /etc/turnserver.conf

  turnadmin -a -u "$1" -p "$2" -r "$realm"

  echo "TURN server starting (legacy auth). IP: $externalIp, username: $1"
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

exec turnserver
