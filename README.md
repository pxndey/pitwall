# Pitwall

> Your F1 co-watcher — an AI-powered chat assistant that explains strategy, results, standings, and terminology, one turn at a time.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Features](#features)
  - [Chat — Multi-Agent AI](#chat--multi-agent-ai)
  - [H2H Agent](#h2h-agent)
  - [Briefing Agent](#briefing-agent)
  - [Race Schedule](#race-schedule)
  - [Race Detail View & Results](#race-detail-view--results)
  - [Championship Standings Tab](#championship-standings-tab)
  - [Favourite Driver Dashboard](#favourite-driver-dashboard)
  - [Conversation Threads](#conversation-threads)
  - [Circuit-Aware Chat](#circuit-aware-chat)
  - [Chat History with Pagination](#chat-history-with-pagination)
  - [Search Chat History](#search-chat-history)
  - [Share Insights](#share-insights)
  - [Onboarding Flow](#onboarding-flow)
  - [Push Notifications](#push-notifications)
  - [Multi-Language Support](#multi-language-support)
- [Backend Setup](#backend-setup)
- [API Reference](#api-reference)
  - [Auth](#auth)
  - [Chat](#chat)
  - [F1 Data](#f1-data)
  - [Health](#health)
- [Frontend Setup](#frontend-setup)
- [Agent Intent Routing](#agent-intent-routing)
- [Project Structure](#project-structure)

---

## Project Overview

Pitwall is an iOS app that helps F1 fans understand what is happening on track. Users can ask questions in natural language — about driver head-to-heads, championship standings, qualifying results, race recaps, upcoming race previews, or F1 terminology — and receive grounded, data-backed answers powered by IBM Watsonx AI.

The app also provides a full 2025 season schedule with per-race detail pages and past race results, a championship standings tab, a favourite driver dashboard card, conversation threads for organizing chats, circuit-aware AI briefings, full-text search across chat history, message sharing, a first-launch onboarding flow, local push notifications with AI-generated briefings, and multi-language support (English, Spanish, Chinese).

| Layer | Technology |
|---|---|
| iOS frontend | SwiftUI (iOS 17+, Swift 5.9+) |
| Backend API | FastAPI (Python 3.11+) |
| Database | SQLite via SQLAlchemy ORM |
| Auth | JWT (python-jose) + bcrypt passwords |
| LLM | IBM Watsonx AI — `meta-llama/llama-3-3-70b-instruct` |
| F1 data | Jolpica/Ergast REST API (directly via URLSession + FastF1's Ergast client) |
| Notifications | `UNUserNotificationCenter` — local scheduled notifications |

---

## Architecture

```
iOS App (SwiftUI)
    |
    | HTTP + Bearer JWT
    v
FastAPI  (/api/...)
    |
    +-- /auth/*          Authentication & profile management
    |
    +-- /chat/watsonx    Multi-agent AI pipeline
    |       |
    |       v
    |   AgentRouter  (keyword-based intent classification)
    |       |
    |       +---> H2HAgent          (intent: "h2h")
    |       |         |
    |       |         +---> F1DataService  (Ergast via FastF1)
    |       |         +---> IBM Watsonx LLM
    |       |
    |       +---> BriefingAgent     (intent: "briefing" | "general" | "circuit_briefing")
    |                 |
    |                 +---> F1DataService  (Ergast via FastF1)
    |                 +---> IBM Watsonx LLM
    |
    +-- /chat/history    Paginated message history (offset + limit)
    |
    +-- /chat/message    Persist a single message
    |
    +-- /health          Health check (unauthenticated)

iOS ScheduleView
    |
    | URLSession  (direct — no backend proxy)
    v
Jolpica/Ergast API  (https://api.jolpi.ca/ergast/f1/current.json)
    |
    v
RaceDetailView  →  RaceContextChatView  →  /chat/watsonx (circuit_context set)

NotificationManager
    |
    +-- UNUserNotificationCenter (local scheduled)
    +-- /chat/watsonx (pre-fetch AI briefing per session, used as notification body)
```

`AgentRouter` runs keyword matching on every incoming message. If no keyword matches, intent defaults to `"general"` and `BriefingAgent` acts as the catch-all. `F1DataService` wraps all Ergast calls with a simple TTL cache (5 min for standings/schedule, 60 min for historical results).

Circuit context flows from the iOS client (set when the user opens chat from a race detail page) through the `/chat/watsonx` request body into `user_context`, where `BriefingAgent` detects it and upgrades a `general` query into a `circuit_briefing` that fetches historical race and qualifying data for that circuit before calling the LLM.

---

## Features

### Chat — Multi-Agent AI

The **Home** tab is a full-screen chat interface powered by a multi-agent framework backed by IBM Watsonx. Every message is routed by `AgentRouter` to the most appropriate specialist agent, which fetches live F1 data from the Ergast API before sending a structured prompt to the LLM.

- Conversation history is carried forward (last 6 messages) on each call so context is preserved.
- Both the user message and the assistant reply are persisted to the database on every turn.
- On launch, the app loads the latest 30 messages from the server so the conversation is never blank.

---

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
| `circuit_briefing` | _(activated automatically when `circuit_context` is set and no specific sub-intent matched)_ | Historical race + qualifying results for the circuit from the prior season; user's favourite driver's result at that circuit |
| `general` | (catch-all) | No data fetched — open F1 Q&A grounded in LLM knowledge |

The agent injects fetched data as a synthetic prior exchange in the message list so the LLM treats it as verified context rather than training knowledge.

Conversation history: the last 6 messages from the session are carried forward on every call.

---

### Race Schedule

The **Schedule** tab fetches the full 2025 calendar from `https://api.jolpi.ca/ergast/f1/current.json` and renders it as a scrollable list.

- **Country flags** derived from a static map (39 countries covered, with fuzzy fallback).
- **Weekend range** label ("Mar 14–16") computed from race day by subtracting 2 days for Friday.
- **"NEXT RACE" badge** highlights the earliest upcoming race.
- **Past races** are dimmed (opacity 0.6, grey round badge).
- **Bell icon** in the navigation bar schedules local notifications for all remaining upcoming races in a single tap.

---

### Race Detail View & Results

Tapping any race card drills down to a full detail page with:

**Circuit Information section**
- Circuit name (e.g. "Albert Park Grand Prix Circuit")
- Full location string (locality + country)

**Race Weekend section**
- Practice 1 — Friday, with full date e.g. "Mar 14, 2025 (Friday)"
- Practice 2 — Friday
- Practice 3 & Qualifying — Saturday
- Race Day — Sunday
- Race start time (UTC) parsed directly from the Jolpica `time` field

**Race Results section** (past races only)
- Automatically fetched via `GET /api/f1/race-results/{season}/{round}` when the race date is in the past
- Shows finishing position, driver name, constructor, time/gap, points, and status for all classified drivers
- Loading spinner while results are being fetched

**Action buttons**
- **"Ask about this race"** — opens a race-context chat sheet (see [Circuit-Aware Chat](#circuit-aware-chat))
- **"Notify me for all sessions"** — schedules five local notifications for the race weekend; the button greys out and shows a filled bell after scheduling to prevent duplicates

---

### Championship Standings Tab

A dedicated tab (trophy icon) showing live driver and constructor championship standings.

- **Segmented picker** at the top toggles between "Drivers" and "Constructors"
- **Driver standings**: position badge (gold P1, silver P2, bronze P3, red for rest), driver name, constructor name, points and wins
- **Constructor standings**: position badge, team name, points and wins
- **Pull-to-refresh** via `.refreshable`
- Data fetched from `GET /api/f1/standings/drivers` and `GET /api/f1/standings/constructors`

---

### Favourite Driver Dashboard

A persistent card at the top of the Home chat screen showing at-a-glance stats for the user's favourite driver.

- **Championship position** — large badge (e.g. "P1")
- **Championship points** — current season total
- **Last race** — race name and finishing position
- **Next race** — upcoming race name, circuit, and date
- Card is only shown when the user has set a favourite driver in their profile
- Data fetched from `GET /api/f1/driver-dashboard` which composites standings, season results, and schedule data

---

### Conversation Threads

Chat history is organized into named conversations (threads), allowing users to keep different topics separate.

**Backend model**: `Conversation` table with `id`, `title`, `user_id`, `created_at`, `updated_at`. The `ChatHistory` table has an optional `conversation_id` FK.

**Auto-creation**: When a user sends a message without an active conversation, a new conversation is automatically created with the first 50 characters of the message as the title.

**Thread picker**: A list button in the Home nav header opens the conversation list, showing:
- Conversation title and creation date
- Message count badge
- Active conversation highlighted with a red border
- Swipe-to-delete on each conversation
- "New Chat" button to start a fresh thread

**API endpoints**:
- `POST /api/chat/conversations` — create
- `GET /api/chat/conversations` — list (ordered by `updated_at desc`)
- `GET /api/chat/conversations/{id}` — single thread with message count
- `PUT /api/chat/conversations/{id}` — rename
- `DELETE /api/chat/conversations/{id}` — delete thread and all messages
- `GET /api/chat/conversations/{id}/messages` — paginated messages for a thread

---

### Circuit-Aware Chat

When the user taps "Ask about this race" from any race detail page, a full chat sheet opens with the circuit pre-loaded as context. The first message is sent automatically:

```
brief me on <raceName> at <circuitName>
```

The `circuit_context` field is included in every message sent from this sheet. On the backend, `BriefingAgent` detects it:

1. Classifies the normal sub-intent first.
2. If the sub-intent is `general` (i.e. no specific keyword matched), it overrides to `circuit_briefing`.
3. `_fetch_circuit_context` is called, which:
   - Finds the race in the current schedule
   - Fetches the prior season's race results and qualifying for the same round
   - Appends the user's favourite driver's result at that circuit in the prior season
4. This data block is injected into the LLM prompt before the user's question.

The result is answers that are automatically scoped to the selected race without the user needing to ask explicitly.

---

### Chat History with Pagination

**Backend** (`GET /api/chat/history`)

The history endpoint now accepts `offset` and `limit` query parameters, enabling cursor-based forward pagination through the full message history stored in the database.

| Param | Type | Default | Range | Description |
|---|---|---|---|---|
| `offset` | int | 0 | ≥ 0 | Number of messages to skip from the beginning |
| `limit` | int | 50 | 1–500 | Max messages to return |

Messages are returned in ascending chronological order (`created_at ASC`). To page backwards through history, increment `offset` by `limit` on each request.

**Frontend** (`ChatViewModel`)

| Method | Behaviour |
|---|---|
| `loadHistory()` | Called on view appear. Fetches the 30 most recent messages (`offset=0, limit=30`), replaces `messages`, sets `historyOffset = 30`. |
| `loadMoreHistory()` | Called when the user taps "Load earlier messages". Fetches the next 30 messages using the current `historyOffset`, prepends them to `messages`, advances `historyOffset`. Sets `hasMoreHistory = false` when fewer than 30 messages are returned. |

A "Load earlier messages" button appears at the top of the chat list whenever `hasMoreHistory` is `true` and there are messages in the view. While fetching, the button shows a spinner and is disabled to prevent duplicate requests.

---

### Push Notifications

Pitwall schedules **local notifications** (no APNs certificate required) for each session of a race weekend. Notification content is AI-generated — the app calls `/chat/watsonx` in advance and uses the first line of the briefing reply (truncated to 150 characters) as the notification body.

**Permission** is requested at app launch via `UNUserNotificationCenter.requestAuthorization`.

**Session schedule** (times are UTC; used as fixed defaults when the Jolpica API does not supply session-specific times):

| Session | Day | Time (UTC) |
|---|---|---|
| Practice 1 | Friday (Race Day − 2) | 11:30 |
| Practice 2 | Friday | 15:00 |
| Practice 3 | Saturday (Race Day − 1) | 11:30 |
| Qualifying | Saturday | 15:00 |
| Race | Sunday (Race Day) | From Jolpica `time` field, or 14:00 |

Each notification fires **30 minutes before** the session start. Notifications are identified as `pitwall-{round}-{session}` (e.g. `pitwall-5-Qualifying`) so they can be individually cancelled or replaced without affecting other sessions.

**User actions:**
- **Bell icon (Schedule nav bar)** — `scheduleAllUpcoming(races:)` — schedules notifications for every race from the current date onwards in a single tap.
- **"Notify me for all sessions" button (Race Detail)** — `scheduleNotifications(for:)` — schedules all five sessions for that specific race.

**`NotificationManager` public API:**

```swift
// Request UNUserNotificationCenter permission
await NotificationManager.shared.requestPermission()

// Schedule five session notifications for one race
await NotificationManager.shared.scheduleNotifications(for: race)

// Schedule notifications for all upcoming races
await NotificationManager.shared.scheduleAllUpcoming(races: races)

// Cancel all Pitwall notifications
NotificationManager.shared.cancelAll()
```

---

### Search Chat History

Full-text search across all past messages.

**Backend**: `GET /api/chat/search?q=<query>&offset=0&limit=20` performs a case-insensitive `LIKE` search on the `ChatHistory.chat` column, filtered to the authenticated user, ordered by `created_at DESC`.

**Frontend**: A magnifying glass button in the Home nav header toggles a search overlay. As the user types, a debounced search (0.5s) queries the backend and displays matching messages with role indicators and timestamps. Tapping a result dismisses the search overlay.

---

### Share Insights

Long-press any assistant message bubble (in both the Home chat and the race-context chat) to access a "Share" context menu. This presents the standard iOS share sheet (`UIActivityViewController`) with the message text, allowing users to copy, AirDrop, or share to any app.

---

### Onboarding Flow

A 4-page swipeable walkthrough shown on first launch after login:

1. **Welcome** — app logo and tagline
2. **AI Race Engineer** — explains the chat feature
3. **Race Schedule** — explains schedule tracking and notifications
4. **Your Preferences** — prompts the user to set favourite driver/team

The "Get Started" button on the final page sets `hasSeenOnboarding` in UserDefaults and transitions to the main app. The onboarding is only shown once; subsequent launches go directly to the tab interface.

---

### Multi-Language Support

AI responses can be configured to reply in English, Spanish, or Chinese (Simplified).

**Backend**: The `User` model has a `language` column (default `"en"`). Supported values: `"en"`, `"es"`, `"zh"`. The language is passed to both `BriefingAgent` and `H2HAgent` via the `user_context` dict. Each agent injects a language instruction into the LLM system prompt:

```
IMPORTANT: You MUST respond entirely in {language_name}.
```

**Frontend**: A "AI Response Language" picker in the Profile screen's F1 Preferences section. Three options: English, Espanol, Chinese (Simplified). Selecting a language calls `PUT /api/auth/me` with the `language` field.

Note: Only AI-generated responses change language. The app UI (labels, tab names, buttons) remains in English.

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
  ],
  "circuit_context": "string (optional)"
}
```

| Field | Required | Description |
|---|---|---|
| `message` | Yes | The user's current message |
| `history` | No (default `[]`) | Last N conversation turns for context. iOS client sends up to last 10 messages. |
| `circuit_context` | No (default `""`) | Circuit name to scope the briefing agent. Set automatically when the user starts a chat from a race detail page. |

When `circuit_context` is non-empty and no specific sub-intent is detected, `BriefingAgent` activates the `circuit_briefing` sub-intent and fetches historical race and qualifying data for that circuit.

**Response `200`:**
```json
{ "reply": "string" }
```

---

#### `GET /api/chat/history`

Retrieve the authenticated user's message history in chronological order with offset/limit pagination.

**Auth:** Bearer JWT required.

**Query params:**

| Param | Type | Default | Range | Description |
|---|---|---|---|---|
| `offset` | int | 0 | ≥ 0 | Number of rows to skip from the start of the result set |
| `limit` | int | 50 | 1–500 | Max messages to return |

**Pagination pattern:** To load the most recent N messages on launch, call `?offset=0&limit=N`. To load older messages, call again with `offset=N` — prepend the results to the UI list.

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

A response shorter than `limit` indicates that no older messages exist (`hasMoreHistory = false`).

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

### Chat — Conversations

#### `POST /api/chat/conversations`

Create a new conversation thread. **Auth:** Bearer JWT required.

**Request body:** `{ "title": "string (default: 'New Chat')" }`

**Response `201`:** `{ "id": "uuid", "title": "string", "created_at": "datetime", "updated_at": "datetime", "message_count": 0 }`

#### `GET /api/chat/conversations`

List all conversations for the authenticated user, ordered by `updated_at DESC`. Each entry includes a `message_count`. **Auth required.**

#### `PUT /api/chat/conversations/{id}`

Rename a conversation. **Auth required.** Body: `{ "title": "string" }`

#### `DELETE /api/chat/conversations/{id}`

Delete a conversation and all its messages. **Auth required.**

#### `GET /api/chat/conversations/{id}/messages`

Paginated messages for a specific thread. Supports `offset` and `limit` params (same as `/chat/history`). **Auth required.**

---

### Chat — Search

#### `GET /api/chat/search`

Full-text search across the user's chat history. **Auth required.**

| Param | Type | Default | Description |
|---|---|---|---|
| `q` | string | _(required)_ | Search query (min 1 char) |
| `offset` | int | 0 | Pagination offset |
| `limit` | int | 20 | Max results (1-100) |

Results ordered by `created_at DESC`. Response format: `List[ChatMessageOut]`.

---

### F1 Data

#### `GET /api/f1/standings/drivers`

Current driver championship standings. **Auth required.**

| Param | Type | Default | Description |
|---|---|---|---|
| `season` | int | 2025 | Season year |

Returns array of `{ position, givenName, familyName, constructorName, points, wins }`.

#### `GET /api/f1/standings/constructors`

Current constructor championship standings. **Auth required.** Same `season` param.

#### `GET /api/f1/race-results/{season}/{round_num}`

Full race results for a specific round. **Auth required.** Returns `{ race_info: {...}, results: [...] }`.

#### `GET /api/f1/driver-dashboard`

Composite dashboard for the authenticated user's favourite driver. **Auth required.** Returns championship position, points, last race result, and next race info.

#### `GET /api/f1/next-race`

Next upcoming race. **Unauthenticated.** Returns `{ raceName, circuitName, date, round, country }`.

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
| `NotificationManager.swift` | `private let baseURL` | `http://localhost:8000/api` |

Schedule data (`ScheduleView`) is fetched directly via `URLSession` against the Jolpica/Ergast API (`https://api.jolpi.ca/ergast/f1/current.json`) — no backend proxy.

The JWT token is stored in `UserDefaults` under the key `"access_token"` and attached as a `Bearer` header on all authenticated requests.

### Notification permissions

On first launch the app calls `UNUserNotificationCenter.requestAuthorization` (alert + sound + badge). Notifications are scheduled as local `UNCalendarNotificationTrigger` events — no Apple Push Notification service certificate or server-side APNs delivery is required. This means notifications fire even without an internet connection as long as they were scheduled while online.

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
| _(circuit_context set, no keyword matched)_ | `circuit_briefing` |
| _(none of the above)_ | `general` |

---

## Project Structure

```
.
├── backend/
│   ├── agents/
│   │   ├── base.py            # BaseAgent ABC + _call_llm (Watsonx)
│   │   ├── router.py          # AgentRouter — intent classification + dispatch
│   │   ├── briefing.py        # BriefingAgent — F1 info, circuit briefings,
│   │   │                      #   multi-language support
│   │   ├── h2h.py             # H2HAgent — driver/constructor comparisons,
│   │   │                      #   multi-language support
│   │   └── data_service.py    # F1DataService — Ergast wrapper with TTL cache
│   ├── api/
│   │   └── router.py          # Composes auth + chat + f1 routers under /api
│   ├── core/
│   │   └── config.py          # Pydantic-settings config (reads backend/.env)
│   ├── db/
│   │   ├── session.py         # SQLAlchemy engine + session factory
│   │   ├── base.py            # Declarative base
│   │   └── init_db.py         # Creates tables + ALTER TABLE migrations
│   ├── endpoints/
│   │   ├── auth.py            # /auth — signup, login, me CRUD (+ language)
│   │   ├── chat.py            # /chat — watsonx, history, conversations CRUD,
│   │   │                      #   search, message persistence
│   │   ├── f1.py              # /f1 — standings, race-results, driver-dashboard,
│   │   │                      #   next-race, drivers, teams
│   │   └── health.py          # GET /health
│   ├── models/
│   │   ├── user.py            # User ORM (+ language column)
│   │   ├── chat_history.py    # ChatHistory ORM (+ conversation_id FK)
│   │   └── conversation.py    # Conversation ORM (threads)
│   ├── schemas/
│   │   ├── user.py            # UserCreate/Login/Update/Out, Token (+ language)
│   │   ├── chat.py            # ChatMessageCreate/Out (+ conversation_id)
│   │   └── conversation.py    # ConversationCreate/Update/Out
│   ├── services/
│   │   └── auth.py            # Password hashing, JWT, get_current_user
│   ├── main.py                # FastAPI app entry point + lifespan (DB init)
│   └── requirements.txt
└── frontend/
    ├── Package.swift
    └── Sources/Pitwall/
        ├── PitwallApp.swift            # App entry; notification permission
        ├── RootView.swift              # Tab bar: Home, Schedule, Standings, Profile
        ├── SplashView.swift            # Splash → onboarding (first launch) → main
        ├── OnboardingView.swift        # 4-page first-launch walkthrough
        ├── AuthViewModel.swift         # Login / signup / logout
        ├── LoginView.swift             # Login form
        ├── SignUpView.swift            # Registration + F1 preferences
        ├── HomeView.swift              # Chat UI: dashboard card, message bubbles
        │                              #   (share context menu), thread picker,
        │                              #   search overlay, load-more pagination
        ├── ChatViewModel.swift         # Send (circuit_context, conversation_id),
        │                              #   history pagination, conversation CRUD,
        │                              #   search
        ├── ConversationListView.swift  # Thread list: create, switch, delete
        ├── StandingsView.swift         # Driver/constructor standings tab
        ├── ProfileView.swift           # Profile + preferences + language picker
        ├── ScheduleView.swift          # Race calendar, RaceDetailView (+ results),
        │                              #   RaceContextChatView (+ share)
        └── NotificationManager.swift   # Local notifications with AI briefings
```
