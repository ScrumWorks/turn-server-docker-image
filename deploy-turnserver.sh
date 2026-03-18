echo $1
echo $2
echo $3

internalIp="${INTERNAL_IP:-$(ip a 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)}"
externalIp="${EXTERNAL_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)}"
externalIp="${externalIp:-$internalIp}"

echo "listening-port=80
listening-ip="$internalIp"
relay-ip="$internalIp"
external-ip="$externalIp"
realm=$3
server-name=$3
lt-cred-mech
fingerprint
no-tls
no-dtls
userdb=/var/lib/turn/turndb
min-port=25001
max-port=30000
log-file=stdout
verbose
"  | tee /etc/turnserver.conf


turnadmin -a -u $1 -p $2 -r $3

turnserver

echo "TURN server running. IP: "$externalIp" Username: $1, password: $2"
