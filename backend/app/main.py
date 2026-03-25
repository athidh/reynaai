"""FastAPI Entry Point — Reyna AI Backend (MongoDB Atlas edition).

Run:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db import init_db
from app.api import auth, scraper, tracker, tutor, analytics, voice


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Connect to MongoDB Atlas and initialise Beanie on startup."""
    await init_db()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Reyna AI backend — FastAPI + MongoDB Atlas powering personalized AI tutoring "
        "with OULAD-based engagement analytics, YouTube transcript scraping, "
        "and Llama 3 / NVIDIA NIM Socratic dialogue generation."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(scraper.router)
app.include_router(tracker.router)
app.include_router(tutor.router)
app.include_router(voice.router)
# R8 Analytics feature
app.include_router(analytics.router, prefix="/api/v1")


@app.get("/", tags=["health"])
async def root():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}


@app.get("/health", tags=["health"])
async def health():
    return {"status": "healthy"}
