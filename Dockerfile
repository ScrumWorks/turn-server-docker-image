FROM ubuntu:24.04

# Set the working directory to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

# TURN/STUN ports: 80 (TCP/UDP), 443 (TLS), 5349 (TLS/DTLS)
# Relay ports: 25001-30000 (UDP)
EXPOSE 80 80/udp 443 443/udp 5349 5349/udp

RUN apt-get update && apt-get install -y \
    dnsutils \
    iproute2 \
    coturn \
    curl \
    procps \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL https://get.acme.sh | sh -s email=placeholder@example.com \
  && mkdir -p /etc/coturn/certs \
  && chmod +x /app/acme-manager.sh /app/acme-reload-coturn \
  && ln -s /app/acme-reload-coturn /usr/local/bin/acme-reload-coturn

# Certificate storage - mount externally for persistence
VOLUME /etc/coturn/certs

ENTRYPOINT ["bash", "deploy-turnserver.sh"]
