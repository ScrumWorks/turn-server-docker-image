FROM ubuntu:24.04

# Set the working directory to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

EXPOSE 80 80/udp

RUN apt-get update && apt-get install -y \
    dnsutils \
    iproute2 \
    coturn \
  && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["bash", "deploy-turnserver.sh"]
