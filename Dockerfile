FROM n8nio/n8n:latest

USER root

# Install python3, pip, and build deps
RUN apk add --no-cache \
      python3 \
      py3-pip \
      py3-virtualenv \
      build-base \
      git \
      bash \
      ca-certificates

RUN mkdir -p /init && chown -R root:root /init

# Custom entrypoint that runs init installs, then starts n8n
COPY <<'ENTRYPOINT_SH' /docker-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

echo "[init] Checking for /init/requirements.txt and /init/package.json..."

if [ -f /init/requirements.txt ]; then
  echo "[init] Installing Python dependencies..."
  pip3 install --no-cache-dir -r /init/requirements.txt --break-system-packages || {
    echo "[init][error] pip install failed"; exit 1;
  }
else
  echo "[init] No Python requirements found."
fi

if [ -f /init/package.json ]; then
  echo "[init] Installing global npm packages from /init..."
  npm install -g /init --unsafe-perm --no-audit --no-fund || {
    echo "[init][warning] npm install failed, retrying with custom prefix..."
    PREFIX_DIR="/root/.npm-global"
    mkdir -p "${PREFIX_DIR}"
    npm config set prefix "${PREFIX_DIR}"
    export PATH="${PREFIX_DIR}/bin:${PATH}"
    npm install -g /init --unsafe-perm --no-audit --no-fund || {
      echo "[init][error] npm install failed completely"
    }
  }
else
  echo "[init] No package.json found."
fi

echo "[init] Starting n8n..."
exec /usr/local/bin/n8n "$@"
ENTRYPOINT_SH

RUN chmod +x /docker-entrypoint.sh

EXPOSE 5678

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
