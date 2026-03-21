# Docker image for TURN server
A Docker container with the [Coturn TURN server](https://github.com/coturn/coturn) (v4.6.1, Ubuntu 24.04).

## Usage

### Recommended: REST API shared secret

```bash
docker run -d -p 80:80 -p 80:80/udp --restart=always \
  -e TURN_SECRET=your-shared-secret \
  -e TURN_REALM=turn.example.com \
  turn-server
```

Clients generate temporary credentials using HMAC-SHA1 over the shared secret. The username is a Unix timestamp (expiry time), and the password is `base64(HMAC-SHA1(secret, username))`. See the [Coturn REST API docs](https://github.com/coturn/coturn/wiki/turnserver#turn-rest-api) for details.

### Legacy: static credentials

```bash
docker run -d -p 80:80 -p 80:80/udp --restart=always turn-server username password realm
```

## Configuration

The container generates `/etc/turnserver.conf` at startup with these defaults:

- **Listening port:** 80 (TCP + UDP), configurable via `TURN_PORT`
- **Relay ports:** 25001-30000
- **Auth:** `use-auth-secret` (recommended) or `lt-cred-mech` (legacy)
- **STUN FINGERPRINT:** enabled
- **TLS/DTLS:** disabled (use `no-tls`, `no-dtls`)

### Environment variables

| Variable | Description | Default |
|---|---|---|
| `TURN_SECRET` | Shared secret for REST API auth (recommended) | — |
| `TURN_PORT` | Listening port (TCP + UDP) | `80` |
| `TURN_REALM` | TURN realm | `turn.example.com` (secret mode) or positional arg `$3` (legacy) |
| `EXTERNAL_IP` | Public IP for relay candidates | auto-detected via `dig` |
| `INTERNAL_IP` | Internal/listening IP | auto-detected via `ip` |

If not set, IPs are detected automatically. For ECS Anywhere with host network mode, auto-detection works out of the box.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 --provenance=false -t <ecr-repo>/turn-server:latest --push .
```

## Testing

```bash
# Secret auth mode
docker run -d --name turn-test -p 3478:80/tcp -p 3478:80/udp \
  -e TURN_SECRET=testsecret -e TURN_REALM=test.local turn-server

# Legacy mode
docker run -d --name turn-test -p 3478:80/tcp -p 3478:80/udp \
  turn-server testuser testpass testrealm

# Run test suite
python3 test_turn.py
```
