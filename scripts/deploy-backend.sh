#!/usr/bin/env bash
#
# Sync backend/ to homelab:~/docker/pitcrew-backend and (re)build+start it.
# Re-runnable. Prereq: SSH access to `homelab` (defined in ~/.ssh/config),
# Docker installed there.
#
set -euo pipefail

REMOTE_HOST="homelab"
# Tilde expansion works in rsync paths (expands on remote side).
REMOTE_DIR="docker/pitcrew-backend"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/backend"

if [ ! -f "$LOCAL_DIR/Dockerfile" ]; then
  echo "ERROR: $LOCAL_DIR doesn't look like the backend dir (no Dockerfile)" >&2
  exit 1
fi

if [ ! -f "$LOCAL_DIR/.env" ]; then
  echo "ERROR: $LOCAL_DIR/.env is missing — backend won't start without secrets" >&2
  exit 1
fi

echo "==> Ensuring remote dir exists"
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_DIR"

echo "==> Syncing $LOCAL_DIR -> $REMOTE_HOST:$REMOTE_DIR"
rsync -avz --delete \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='*.pyo' \
  --exclude='.pytest_cache/' \
  --exclude='.mypy_cache/' \
  --exclude='.ruff_cache/' \
  --exclude='.venv/' \
  --exclude='venv/' \
  --exclude='app.db' \
  --exclude='*.sqlite' \
  --exclude='*.sqlite3' \
  --exclude='.DS_Store' \
  "$LOCAL_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"

echo "==> Building and starting container on $REMOTE_HOST"
ssh "$REMOTE_HOST" bash <<EOF
  set -euo pipefail
  cd $REMOTE_DIR

  # Ensure the 'proxy' network exists (will be reused by Traefik later).
  if ! docker network inspect proxy >/dev/null 2>&1; then
    echo "Creating 'proxy' docker network"
    docker network create proxy
  fi

  echo "Pulling base images and building..."
  docker compose build
  docker compose up -d
  sleep 3
  docker compose ps
EOF

echo "==> Health check"
ssh "$REMOTE_HOST" 'curl -sS --max-time 5 http://localhost:8000/health || echo "(no /health response yet — check `docker compose logs` on homelab)"'

echo
echo "==> Done. From your phone (same network or via tailscale): http://homelab:8000"
echo "==> Logs: ssh $REMOTE_HOST 'cd $REMOTE_DIR && docker compose logs -f'"
