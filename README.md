# Docker image for TURN server
A Docker container with the [Coturn TURN server](https://github.com/coturn/coturn) (v4.6.1, Ubuntu 24.04) with optional automatic TLS via ACME (Let's Encrypt).

## Usage

### Recommended: REST API shared secret

```bash
docker run -d -p 80:80 -p 80:80/udp --restart=always \
  -e TURN_SECRET=your-shared-secret \
  -e TURN_REALM=turn.example.com \
  turn-server
```

Clients generate temporary credentials using HMAC-SHA1 over the shared secret. The username is a Unix timestamp (expiry time), and the password is `base64(HMAC-SHA1(secret, username))`. See the [Coturn REST API docs](https://github.com/coturn/coturn/wiki/turnserver#turn-rest-api) for details.

### With TLS (ACME auto-renewal via Cloudflare DNS)

```bash
docker run -d --restart=always \
  -p 80:80 -p 80:80/udp \
  -p 5349:5349 -p 5349:5349/udp \
  -v /opt/coturn/certs:/etc/coturn/certs \
  -e TURN_SECRET=your-shared-secret \
  -e TURN_REALM=turn.example.com \
  -e TURN_DOMAIN=turn.example.com \
  -e ACME_EMAIL=admin@example.com \
  -e CF_API_TOKEN=your-cloudflare-api-token \
  turn-server
```

When `TURN_DOMAIN` is set, the container will:
1. Automatically obtain a TLS certificate from Let's Encrypt via Cloudflare DNS-01 challenge
2. Enable TLS on port 5349 (configurable via `TURN_TLS_PORT`) for both TCP and UDP (DTLS)
3. Check for renewal every 6 hours and automatically renew when needed
4. Reload coturn via SIGUSR2 signal after renewal (zero-downtime)
5. Store certificates in `/etc/coturn/certs/` (mount externally for persistence across restarts)

**`CF_API_TOKEN` is required** — a Cloudflare scoped API token with `Zone:DNS:Edit` permission.

### Legacy: static credentials

```bash
docker run -d -p 80:80 -p 80:80/udp --restart=always turn-server username password realm
```

## Configuration

The container generates `/etc/turnserver.conf` at startup with these defaults:

- **Listening port:** 80 (TCP + UDP), configurable via `TURN_PORT`
- **TLS port:** 5349 (TCP + UDP), configurable via `TURN_TLS_PORT` (only when `TURN_DOMAIN` is set)
- **Relay ports:** 25001-30000
- **Auth:** `use-auth-secret` (recommended) or `lt-cred-mech` (legacy)
- **STUN FINGERPRINT:** enabled
- **TLS/DTLS:** auto-enabled when `TURN_DOMAIN` is set, disabled otherwise

### Environment variables

| Variable | Description | Default |
|---|---|---|
| `TURN_SECRET` | Shared secret for REST API auth (recommended) | — |
| `TURN_PORT` | Listening port (TCP + UDP) | `80` |
| `TURN_REALM` | TURN realm | `turn.example.com` (secret mode) or positional arg `$3` (legacy) |
| `EXTERNAL_IP` | Public IP for relay candidates | auto-detected via `dig` |
| `INTERNAL_IP` | Internal/listening IP | auto-detected via `ip` |
| `TURN_DOMAIN` | Domain name for TLS certificate (enables TLS when set) | — |
| `ACME_EMAIL` | Email for ACME/Let's Encrypt registration (required with `TURN_DOMAIN`) | — |
| `CF_API_TOKEN` | Cloudflare scoped API token with `Zone:DNS:Edit` permission (required with `TURN_DOMAIN`) | — |
| `TURN_TLS_PORT` | TLS listening port | `5349` |
| `TURN_CERT_DIR` | Certificate storage directory | `/etc/coturn/certs` |
| `ACME_STAGING` | Use Let's Encrypt staging environment (`1` or `true`) | — |
| `ACME_RENEWAL_INTERVAL` | Seconds between renewal checks | `21600` (6 hours) |

If not set, IPs are detected automatically. For ECS Anywhere with host network mode, auto-detection works out of the box.

### Certificate persistence

Mount `/etc/coturn/certs` to a host directory or named volume to persist certificates across container restarts:

```bash
-v /opt/coturn/certs:/etc/coturn/certs
```

On restart, the container will reuse existing certificates and only renew when they are close to expiration.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 --provenance=false -t <ecr-repo>/turn-server:latest --push .
```

## Testing

```bash
# Secret auth mode
docker run -d --name turn-test -p 3478:80/tcp -p 3478:80/udp \
  -e TURN_SECRET=testsecret -e TURN_REALM=test.local turn-server

# With TLS (staging for testing)
docker run -d --name turn-test \
  -p 80:80 -p 80:80/udp -p 5349:5349 -p 5349:5349/udp \
  -v ./certs:/etc/coturn/certs \
  -e TURN_SECRET=testsecret -e TURN_REALM=turn.test.local \
  -e TURN_DOMAIN=turn.test.local -e ACME_EMAIL=test@test.local \
  -e CF_API_TOKEN=your-cloudflare-token \
  -e ACME_STAGING=1 turn-server

# Legacy mode
docker run -d --name turn-test -p 3478:80/tcp -p 3478:80/udp \
  turn-server testuser testpass testrealm

# Run test suite
python3 test_turn.py
```
