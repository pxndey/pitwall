# Pitwall

> Your F1 co-watcher — an AI-powered chat assistant that explains strategy, results, standings, and terminology, one turn at a time.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Features](#features)
  - [H2H Agent](#h2h-agent)
  - [Briefing Agent](#briefing-agent)
- [Backend Setup](#backend-setup)
- [API Reference](#api-reference)
- [Frontend Setup](#frontend-setup)
- [Agent Intent Routing](#agent-intent-routing)
- [Project Structure](#project-structure)

---

## Project Overview

Pitwall is an iOS app that helps F1 fans understand what is happening on track. Users can ask questions in natural language — about driver head-to-heads, championship standings, qualifying results, race recaps, upcoming race previews, or F1 terminology — and receive grounded, data-backed answers powered by IBM Watsonx AI.

| Layer | Technology |
|---|---|
| iOS frontend | SwiftUI (iOS 17+, Swift 5.9+) |
| Backend API | FastAPI (Python 3.11+) |
| Database | SQLite via SQLAlchemy ORM |
| Auth | JWT (python-jose) + bcrypt passwords |
| LLM | IBM Watsonx AI — `meta-llama/llama-3-3-70b-instruct` |
| F1 data | Jolpica/Ergast API via FastF1's Ergast interface |

---

## Architecture

```
iOS App (SwiftUI)
    |
    | HTTP + Bearer JWT
    v
FastAPI  (/api/chat/watsonx)
    |
    v
AgentRouter  (keyword-based intent classification)
    |
    +---> H2HAgent          (intent: "h2h")
    |         |
    |         +---> F1DataService  (Ergast via FastF1)
    |         +---> IBM Watsonx LLM
    |
    +---> BriefingAgent     (intent: "briefing" | "general")
              |
              +---> F1DataService  (Ergast via FastF1)
              +---> IBM Watsonx LLM
```

`AgentRouter` runs keyword matching on every incoming message. If no keyword matches, intent defaults to `"general"` and `BriefingAgent` acts as the catch-all. `F1DataService` wraps all Ergast calls with a simple TTL cache (5 min for standings/schedule, 60 min for historical results).

---

## Features

### H2H Agent

Handles driver vs driver and constructor vs constructor comparisons across an entire season (defaults to 2025; year can be specified in the message).

**Driver comparison** returns, per driver:
- Total points, wins, podiums, DNFs, average finishing position
- Qualifying head-to-head count (how many rounds each driver out-qualified the other)
- Race head-to-head count (how many rounds each driver finished ahead)
- Full per-race-weekend breakdown: finishing position, grid slot, points, status

**Constructor comparison** returns, per team:
- Total points, wins, podiums, DNFs, average best-driver finishing position
- Qualifying H2H based on each team's best-placed driver per round
- Race H2H based on each team's best-placed driver per round
- Full per-race-weekend breakdown: best position, combined points

**Smart name resolution** — the agent understands aliases and first names before querying the driver/constructor list:

| Input | Resolved to |
|---|---|
| Max | verstappen |
| Checo | perez |
| Lando | norris |
| Charles | leclerc |
| Lewis | hamilton |
| Ollie / Oliver | bearman |
| Kimi / Andrea | antonelli |
| RB / Visa RB / VCARB | rb |
| Aston / AM | aston_martin |
| Kick Sauber / Sauber | sauber |

**Single-entity fallback** — if only one driver or team is named, the agent compares it against the user's saved favourite driver or team.

**Season targeting** — a four-digit year (2000–2029) anywhere in the message overrides the default 2025 season (e.g. "Verstappen vs Hamilton 2021").

---

### Briefing Agent

Handles all informational and general F1 queries. Classifies messages into sub-intents to decide which F1 data to fetch before calling the LLM.

| Sub-intent | Trigger keywords | Data fetched |
|---|---|---|
| `driver_standings` | standing, championship, leaderboard, points table | Current driver championship table (top 20) |
| `constructor_standings` | standing/championship + constructor/team | Current constructor championship table |
| `qualifying` | pole, qualifying, quali, grid | Qualifying result for the latest completed round (Q1/Q2/Q3 times, grid positions) |
| `race_result` | race result, who won, race winner, podium, how did the race go | Race results for the latest completed round (positions, times, points, status) |
| `next_race` | next race, upcoming, brief me, briefing, preview | Upcoming race name/circuit/date + top 10 results from the same round in the prior season + user's favourite driver's result at that circuit in the prior season |
| `personal` | my driver, my team, favourite, favorite | User's favourite driver's round-by-round results this season + their team's current constructor standing |
| `terminology` | what is, what does, explain, meaning, definition, terminology, drs, ers, tyre, tire, undercut, overcut, safety car, vsc, pit stop, slipstream, dirty air, parc ferme, formation lap, delta, blue flag, yellow flag, red flag, black flag | No data fetched — LLM uses its own F1 knowledge |
| `practice_summary` | practice, fp1, fp2, fp3, free practice | Qualifying + race results for the same weekend (Ergast does not expose practice timing; the LLM uses weekend context to generate a practice briefing) |
| `session_summary` | summary, summarize, what happened, recap, session | Combined qualifying + race results for the latest completed round |
| `general` | (catch-all) | No data fetched — open F1 Q&A grounded in LLM knowledge |

The agent injects fetched data as a synthetic prior exchange in the message list so the LLM treats it as verified context rather than training knowledge.

Conversation history: the last 6 messages from the session are carried forward on every call.

---

## Backend Setup

### Prerequisites

- Python 3.11+
- Conda (recommended) or any virtual environment manager
- An IBM Watsonx account with a project and API key

### Install

```bash
conda create -n pitwall-backend python=3.11
conda activate pitwall-backend
pip install -r backend/requirements.txt
```

**`backend/requirements.txt` installs:**
`fastapi`, `uvicorn[standard]`, `langchain`, `pandas`, `sqlalchemy`, `pydantic-settings`, `passlib[bcrypt]`, `python-jose[cryptography]`, `ibm-watsonx-ai`, `fastf1`

### Environment variables

Create `backend/.env`:

```dotenv
DATABASE_URL=sqlite:///./app.db
SECRET_KEY=your_secret_key_here
WATSONX_API_KEY=your_ibm_watsonx_api_key
WATSONX_PROJECT_ID=your_watsonx_project_id
WATSONX_URL=https://us-south.ml.cloud.ibm.com
```

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./app.db` | SQLAlchemy database URL |
| `SECRET_KEY` | `change-me-in-production` | JWT signing key |
| `WATSONX_API_KEY` | _(required)_ | IBM Cloud API key |
| `WATSONX_PROJECT_ID` | _(required)_ | Watsonx project ID |
| `WATSONX_URL` | `https://us-south.ml.cloud.ibm.com` | Watsonx regional endpoint |

JWT tokens expire after 7 days (`access_token_expire_minutes = 10080`).

### Run

```bash
cd backend
uvicorn main:app --reload --port 8000
```

- API root: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs`

The database is initialised automatically on first startup via the FastAPI lifespan handler (`db/init_db.py`).

---

## API Reference

All endpoints under `/api` require a `Bearer <token>` header unless marked as public.

### Auth

#### `POST /api/auth/signup`

Create a new account. Returns a JWT.

**Request body:**
```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "name": "string (optional)",
  "fav_driver": "string (optional)",
  "fav_team": "string (optional)"
}
```

**Response `201`:**
```json
{
  "access_token": "string",
  "token_type": "bearer"
}
```

---

#### `POST /api/auth/login`

Authenticate and receive a JWT.

**Request body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response `200`:**
```json
{
  "access_token": "string",
  "token_type": "bearer"
}
```

---

#### `GET /api/auth/me`

Return the authenticated user's profile.

**Auth:** Bearer JWT required.

**Response `200`:**
```json
{
  "id": "uuid",
  "username": "string",
  "name": "string | null",
  "email": "string",
  "fav_driver": "string | null",
  "fav_team": "string | null",
  "created_at": "datetime"
}
```

---

#### `PUT /api/auth/me`

Update profile fields. All fields are optional; only provided fields are updated.

**Auth:** Bearer JWT required.

**Request body:**
```json
{
  "name": "string (optional)",
  "email": "string (optional)",
  "password": "string (optional)",
  "fav_driver": "string (optional)",
  "fav_team": "string (optional)"
}
```

**Response `200`:** Updated `UserOut` object (same shape as `GET /api/auth/me`).

---

#### `DELETE /api/auth/me`

Delete the authenticated user's account.

**Auth:** Bearer JWT required.

**Response `200`:**
```json
{ "detail": "account deleted" }
```

---

### Chat

#### `POST /api/chat/watsonx`

Send a message through the multi-agent pipeline. The `AgentRouter` classifies intent, fetches relevant F1 data, calls `meta-llama/llama-3-3-70b-instruct` on IBM Watsonx, and returns the reply. Both the user message and assistant reply are persisted to the database.

**Auth:** Bearer JWT required.

**Request body:**
```json
{
  "message": "string",
  "history": [
    { "role": "user", "content": "string" },
    { "role": "assistant", "content": "string" }
  ]
}
```

`history` is optional (defaults to `[]`). Send the last N conversation turns so the agents can maintain context. The iOS client sends up to the last 10 messages.

**Response `200`:**
```json
{ "reply": "string" }
```

---

#### `GET /api/chat/history`

Retrieve the authenticated user's message history in chronological order.

**Auth:** Bearer JWT required.

**Query params:**

| Param | Type | Default | Range | Description |
|---|---|---|---|---|
| `limit` | int | 50 | 1–500 | Max messages to return |

**Response `200`:**
```json
[
  {
    "id": "uuid",
    "role": "user | assistant",
    "content": "string",
    "created_at": "datetime"
  }
]
```

---

#### `POST /api/chat/message`

Persist a single message to the database without going through the agent pipeline. Useful for storing client-side messages directly.

**Auth:** Bearer JWT required.

**Request body:**
```json
{
  "role": "user | assistant",
  "content": "string"
}
```

**Response `201`:**
```json
{
  "id": "uuid",
  "role": "string",
  "content": "string",
  "created_at": "datetime"
}
```

---

### Health

#### `GET /health`

Unauthenticated health check.

**Response `200`:** `{ "status": "ok" }`

---

## Frontend Setup

### Requirements

- Xcode 15+
- iOS 17+ simulator or device
- Swift 5.9+

### Run

1. Open the `frontend/` directory in Xcode (it is a Swift Package project with `Package.swift`).
2. Select an iOS 17+ simulator.
3. Build and run (`Cmd+R`).

### Configuration

The base URL is hardcoded in each networking ViewModel. Change it if you are running the backend on a different host or port.

| File | Variable | Default |
|---|---|---|
| `ChatViewModel.swift` | `private let baseURL` | `http://localhost:8000/api` |
| `AuthViewModel.swift` | Base URL constant | `http://localhost:8000/api` |

Schedule data (`ScheduleView`) is fetched directly via `URLSession` against the Jolpica/Ergast API — the JolpicaKit Swift package dependency has been removed from the project.

The JWT token is stored in `UserDefaults` under the key `"access_token"` and attached as a `Bearer` header on all authenticated requests.

---

## Agent Intent Routing

The `AgentRouter.classify_intent` method runs a single pass of keyword matching. The first group that matches wins; unmatched messages fall through to `"general"`.

### Top-level routing

| Keywords (any match) | Intent | Handled by |
|---|---|---|
| `head to head`, `h2h`, `versus`, ` vs `, `compare`, `comparison`, `better than`, `who is faster`, `who beats`, `matchup` | `h2h` | `H2HAgent` |
| `standings`, `championship`, `pole`, `qualifying`, `race result`, `summary`, `briefing`, `what happened`, `session`, `practice`, `explain`, `what is`, `what does`, `terminology`, `meaning`, `history`, `my team`, `my driver`, `drs`, `tyre`, `tire`, `strategy`, `pit stop`, `undercut`, `overcut`, `safety car` | `briefing` | `BriefingAgent` |
| _(none of the above)_ | `general` | `BriefingAgent` (catch-all) |

### BriefingAgent sub-intent routing

| Keywords (any match) | Sub-intent |
|---|---|
| `standing`, `championship`, `leaderboard`, `points table` + `constructor` or `team` | `constructor_standings` |
| `standing`, `championship`, `leaderboard`, `points table` (no team keyword) | `driver_standings` |
| `pole`, `qualifying`, `quali`, `grid` | `qualifying` |
| `race result`, `who won`, `race winner`, `podium`, `how did the race go` | `race_result` |
| `next race`, `upcoming`, `brief me`, `briefing`, `preview` | `next_race` |
| `my driver`, `my team`, `favourite`, `favorite` | `personal` |
| `what is`, `what does`, `explain`, `meaning`, `definition`, `terminology`, `drs`, `ers`, `tyre`, `tire`, `undercut`, `overcut`, `safety car`, `vsc`, `pit stop`, `slipstream`, `dirty air`, `parc ferme`, `formation lap`, `delta`, `blue flag`, `yellow flag`, `red flag`, `black flag` | `terminology` |
| `practice`, `fp1`, `fp2`, `fp3`, `free practice` | `practice_summary` |
| `summary`, `summarize`, `what happened`, `recap`, `session` | `session_summary` |
| _(none of the above)_ | `general` |

---

## Project Structure

```
.
├── backend/
│   ├── agents/
│   │   ├── base.py          # BaseAgent ABC + _call_llm (Watsonx)
│   │   ├── router.py        # AgentRouter — intent classification + dispatch
│   │   ├── briefing.py      # BriefingAgent — F1 info, standings, results, terminology
│   │   ├── h2h.py           # H2HAgent — driver and constructor comparisons
│   │   └── data_service.py  # F1DataService — Ergast wrapper with TTL cache
│   ├── api/
│   │   └── router.py        # Composes auth + chat routers under /api
│   ├── core/
│   │   └── config.py        # Pydantic-settings config (reads backend/.env)
│   ├── db/
│   │   ├── session.py       # SQLAlchemy engine + session factory
│   │   ├── base.py          # Declarative base
│   │   └── init_db.py       # Creates all tables on startup
│   ├── endpoints/
│   │   ├── auth.py          # /auth — signup, login, me CRUD
│   │   ├── chat.py          # /chat — watsonx, history, message
│   │   ├── f1.py            # /f1 — drivers, teams (Jolpica, auxiliary)
│   │   └── health.py        # GET /health
│   ├── models/
│   │   ├── user.py          # User ORM model
│   │   └── chat_history.py  # ChatHistory ORM model
│   ├── schemas/
│   │   ├── user.py          # UserCreate, UserLogin, UserUpdate, UserOut, Token
│   │   └── chat.py          # ChatMessageCreate, ChatMessageOut
│   ├── services/
│   │   └── auth.py          # hash_password, verify_password, create_access_token, get_current_user
│   ├── main.py              # FastAPI app entry point
│   └── requirements.txt
└── frontend/
    ├── Package.swift
    └── Sources/Pitwall/
        ├── PitwallApp.swift        # App entry, injects AuthViewModel
        ├── RootView.swift          # Authenticated root, tab bar
        ├── SplashView.swift        # Animated splash screen
        ├── AuthViewModel.swift     # Login / signup / logout state
        ├── LoginView.swift         # Login form
        ├── SignUpView.swift        # Registration form
        ├── HomeView.swift          # Home tab
        ├── ChatViewModel.swift     # Chat session state, Watsonx integration
        ├── ProfileView.swift       # User profile + favourite driver/team
        └── ScheduleView.swift      # Upcoming race calendar
```
