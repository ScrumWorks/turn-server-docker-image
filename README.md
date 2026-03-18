# Docker image for TURN server
A Docker container with the [Coturn TURN server](https://github.com/coturn/coturn) (v4.6.1, Ubuntu 24.04).

## Usage

```bash
docker run -d -p 80:80 -p 80:80/udp --restart=always turn-server username password realm
```

## Configuration

The container generates `/etc/turnserver.conf` at startup with these defaults:

- **Listening port:** 80 (TCP + UDP)
- **Relay ports:** 25001-30000
- **Auth:** long-term credentials (`lt-cred-mech`)
- **STUN FINGERPRINT:** enabled
- **TLS/DTLS:** disabled (use `no-tls`, `no-dtls`)

### Environment variables (optional)

| Variable | Description | Default |
|---|---|---|
| `EXTERNAL_IP` | Public IP for relay candidates | auto-detected via `dig` |
| `INTERNAL_IP` | Internal/listening IP | auto-detected via `ip` |

If not set, IPs are detected automatically. For ECS Anywhere with host network mode, auto-detection works out of the box.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 --provenance=false -t <ecr-repo>/turn-server:latest --push .
```

## Testing

```bash
# Run locally
docker run -d --name turn-test -p 3478:80/tcp -p 3478:80/udp turn-server testuser testpass testrealm

# Run test suite
python3 test_turn.py
```
