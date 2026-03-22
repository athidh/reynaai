# Reyna AI — Backend

FastAPI backend powering the Reyna AI adaptive tutoring app.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | FastAPI + Uvicorn |
| Auth | JWT (python-jose) + bcrypt (passlib) |
| Database | SQLite (async, via SQLAlchemy + aiosqlite) |
| Analytics | OULAD-based 8-feature engagement engine |
| LLM | NVIDIA NIM / Llama 3 (OpenAI fallback) |
| Content | YouTube transcript API + yt-dlp |

## Folder Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI entry point
│   ├── db.py                # Async DB session
│   ├── api/
│   │   ├── auth.py          # POST /auth/signup  POST /auth/login  GET /auth/me
│   │   ├── scraper.py       # GET  /scraper/fetch-content
│   │   ├── tracker.py       # POST /tracker/log-event  GET /tracker/history
│   │   └── tutor.py         # GET  /tutor/profile  /study-plan  POST /tutor/reyna-response
│   ├── core/
│   │   ├── config.py        # Settings (reads .env)
│   │   └── security.py      # Password hash + JWT helpers
│   ├── models/
│   │   ├── user.py          # User table
│   │   └── engagement.py    # EngagementEvent table (OULAD-compatible)
│   └── services/
│       ├── youtube_service.py  # yt-dlp search + transcript extraction
│       ├── oulad_engine.py     # 8-feature analytics + study plan
│       └── llama_service.py    # NIM / OpenAI Socratic dialogue + flashcards
├── .env.example             # Copy to .env and fill in keys
└── requirements.txt
```

## Quick Start

```bash
# 1. Clone / navigate to backend/
cd "D:\Athidh\Reyna Ai\backend"

# 2. Create & activate virtual environment
python -m venv .venv
.venv\Scripts\activate       # Windows

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up environment
copy .env.example .env
# Edit .env and fill in SECRET_KEY, NIM_API_KEY, etc.

# 5. Run
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open **http://localhost:8000/docs** for the interactive Swagger UI.

## API Reference

### Auth
| Method | Route | Description |
|--------|-------|-------------|
| POST | `/auth/signup` | Register (name, email, password, age, education, domain_interest) |
| POST | `/auth/login` | Login → JWT token |
| GET | `/auth/me` | Current user profile |

### Content
| Method | Route | Description |
|--------|-------|-------------|
| GET | `/scraper/fetch-content?query=...` | YouTube search + transcript |

### Engagement Tracker
| Method | Route | Description |
|--------|-------|-------------|
| POST | `/tracker/log-event` | Flutter heartbeat ping (sum_click, time_spent, event_type) |
| GET | `/tracker/history` | Recent events for current user |

### AI Tutor
| Method | Route | Description |
|--------|-------|-------------|
| GET | `/tutor/profile` | Compute 8 OULAD features from event log |
| GET | `/tutor/study-plan` | Deterministic 7-day study plan |
| POST | `/tutor/reyna-response` | Llama 3 Socratic dialogue + 5 flashcards |

## OULAD Features Computed

1. `total_interactions`
2. `days_active`
3. `interactions_first_28_days`
4. `avg_interactions_per_active_day`
5. `recency_days`
6. `weekly_activity_ratio`
7. `submissions_count`
8. `avg_time_per_session`

Scores are benchmarked against the pre-computed `engagement_matrix.csv` from the OULAD dataset.

## Engagement → UI Rank Mapping (Phase 3)

| Score | Level | Rank |
|-------|-------|------|
| 0.00 – 0.32 | Low | Iron |
| 0.33 – 0.65 | Medium | Gold |
| 0.66 – 1.00 | High | Radiant |
