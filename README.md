# F1 Pitwall

> Your F1 co-watcher, guiding you through the technicalities of F1, one turn at a time.

## Overview

Pitwall is an iOS app that helps F1 fans understand what's happening on track in real time — explaining strategy calls, tyre deg, DRS zones, and team radio through an AI-powered chat interface.

## Stack

| Layer | Technology |
|-------|-----------|
| iOS frontend | SwiftUI (iOS 17+, Swift 6) |
| Backend API | FastAPI (Python 3.11+) |
| Database | SQLite via SQLAlchemy ORM |
| Auth | JWT (python-jose) + bcrypt passwords |

## Project Structure

```
.
├── backend/
│   ├── api/          # API router composition
│   ├── core/         # App config (pydantic-settings)
│   ├── db/           # SQLAlchemy engine, session, base, init
│   ├── endpoints/    # Route handlers (health, auth)
│   ├── models/       # ORM models (User, ChatHistory)
│   ├── schemas/      # Pydantic request/response schemas
│   ├── services/     # Business logic (auth: hashing, JWT)
│   └── main.py       # FastAPI app entry point
└── frontend/
    └── Sources/Pitwall/
        ├── PitwallApp.swift      # App entry, injects AuthViewModel
        ├── SplashView.swift      # Animated splash screen
        ├── AuthViewModel.swift   # Login/signup/logout state
        ├── LoginView.swift       # Login form
        ├── SignUpView.swift      # Registration form
        ├── HomeView.swift        # Dummy home screen
        └── ContentView.swift
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Health check |
| POST | `/api/auth/signup` | No | Create account |
| POST | `/api/auth/login` | No | Login, returns JWT |
| GET | `/api/auth/me` | Bearer JWT | Get current user |
| PUT | `/api/auth/me` | Bearer JWT | Update profile |
| DELETE | `/api/auth/me` | Bearer JWT | Delete account |

## Running locally

### Backend

```bash
cd backend
conda activate pitwall-backend
uvicorn main:app --reload
# API available at http://localhost:8000
# Docs at http://localhost:8000/docs
```

### Frontend

Open the `frontend/` directory in Xcode and run on an iOS 17+ simulator.
