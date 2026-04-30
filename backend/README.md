# PitCrew Backend — homelab deployment

FastAPI backend for the PitCrew F1 app. Synced from local repo via
`scripts/deploy-backend.sh` in the source repo.

## What's here

- `Dockerfile`, `docker-compose.yml` — build/run definition
- `.env` — secrets (watsonx creds, JWT signing key). **Not in git. Don't lose it.**
- `main.py`, `agents/`, `endpoints/`, `services/`, `models/`, `schemas/`, `core/`, `db/`, `api/` — app code
- `requirements.txt`, `environment.yml` — Python deps

## Where things live at runtime

- Container name: `pitcrew-backend`
- Port: `0.0.0.0:8000` (direct exposure; remove or bind to `127.0.0.1` once Traefik is in front)
- SQLite DB: docker volume `pitcrew-backend_pitcrew_data`, mounted at `/app/data/app.db` inside container
- Network: `proxy` (external; created on first deploy; Traefik will share this network later)

## Common ops

```bash
cd ~/docker/pitcrew-backend

# tail logs
docker compose logs -f

# restart (e.g. after editing .env)
docker compose restart

# rebuild after code change (deploy script does this for you)
docker compose up -d --build

# stop
docker compose down

# nuke db (start fresh — destroys all users/conversations)
docker compose down -v
```

## Quick sanity checks

```bash
curl -s http://localhost:8000/health                    # → {"status":"ok"}
curl -s http://localhost:8000/openapi.json | jq '.paths | keys | length'   # → number of routes
```

## Updating from the laptop

From the source repo on your Mac:

```bash
./scripts/deploy-backend.sh
```

That re-rsyncs, rebuilds the image, and restarts. Idempotent. SQLite volume survives.

## When Traefik gets added

`docker-compose.yml` already has the Traefik labels for host
`pitcrew-backend.pxndey.com` on the `proxy` network. Once Traefik is up on the
same network and DNS for that hostname resolves to this box, it'll Just Work.
At that point, optionally remove the `ports:` block in `docker-compose.yml`
to make the API only reachable via Traefik.

## Reaching it from a phone (right now, no Traefik)

- Tailscale: `http://100.78.23.70:8000` (from any device on your tailnet)
- Same LAN: `http://<homelab-lan-ip>:8000` or `http://homelab:8000` if mDNS works
- Append `/api/...` for app endpoints; WebSocket at `/api/chat/ws`

## Secrets in `.env`

```
WATSONX_API_KEY=...
WATSONX_URL=...
WATSONX_PROJECT_ID=...
SECRET_KEY=...           # JWT signing; rotate to log everyone out
CF_ACCESS_CLIENT_ID=     # leave empty unless API is behind Cloudflare Access (probably don't do this — JWT is the gate)
CF_ACCESS_CLIENT_SECRET=
```

Edit, then `docker compose restart` to pick up changes.
