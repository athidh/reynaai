"""Tracker route: /log-event, /history, /flashcard-stats — MongoDB version.

Receives Flutter heartbeat pings (sum_click, time_spent, event_type)
and stores them in the engagement_events MongoDB collection.
Also handles flashcard performance stats (avg_recognition_time, correct_answers).
"""
from typing import List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.deps import get_current_user_id
from app.models.engagement import EngagementEvent

router = APIRouter(prefix="/tracker", tags=["tracker"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class LogEventRequest(BaseModel):
    content_id: Optional[str] = None
    activity_type: Optional[str] = "video"
    sum_click: int = 1
    time_spent_seconds: float = 0.0
    event_type: Optional[str] = None    # "pause", "seek", "complete", "open"
    domain: Optional[str] = None


class LogEventResponse(BaseModel):
    status: str = "logged"
    event_id: str


class EventHistoryItem(BaseModel):
    id: str
    content_id: Optional[str] = None
    activity_type: Optional[str] = None
    sum_click: int
    time_spent_seconds: float
    event_type: Optional[str] = None
    domain: Optional[str] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/log-event", response_model=LogEventResponse)
async def log_event(
    body: LogEventRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Store a Flutter heartbeat ping in MongoDB and trigger live ML prediction."""
    event = EngagementEvent(
        user_id=user_id,
        content_id=body.content_id,
        activity_type=body.activity_type,
        sum_click=body.sum_click,
        time_spent_seconds=body.time_spent_seconds,
        event_type=body.event_type,
        domain=body.domain,
    )
    await event.insert()
    
    # Trigger live ML prediction on heartbeat events
    if body.event_type == "heartbeat":
        try:
            from app.services.oulad_engine import predict_success
            prediction = await predict_success(user_id)
            print(f"[LiveML] User {user_id} success probability: {prediction.get('success_probability', 'N/A')}")
        except Exception as e:
            print(f"[LiveML] Prediction failed for user {user_id}: {e}")
    
    return LogEventResponse(event_id=str(event.id))


@router.get("/history", response_model=List[EventHistoryItem])
async def get_event_history(
    limit: int = 100,
    user_id: str = Depends(get_current_user_id),
):
    """Return the most recent *limit* engagement events for the current user."""
    events = (
        await EngagementEvent.find(EngagementEvent.user_id == user_id)
        .sort(-EngagementEvent.logged_at)
        .limit(limit)
        .to_list()
    )
    return [
        EventHistoryItem(
            id=str(e.id),
            content_id=e.content_id,
            activity_type=e.activity_type,
            sum_click=e.sum_click,
            time_spent_seconds=e.time_spent_seconds,
            event_type=e.event_type,
            domain=e.domain,
        )
        for e in events
    ]


# ── Flashcard Stats ───────────────────────────────────────────────────────────

class FlashcardStatsRequest(BaseModel):
    avg_recognition_time: float = 0.0   # seconds per card
    correct_answers: int = 0             # MASTERED taps
    total_cards: int = 5
    domain: Optional[str] = None
    content_id: Optional[str] = None     # video_id the flashcards were from


class FlashcardStatsResponse(BaseModel):
    status: str = "logged"
    combat_proficiency: float           # correct_answers / total_cards (0.0-1.0)
    avg_recognition_time: float
    event_id: str


@router.post("/flashcard-stats", response_model=FlashcardStatsResponse)
async def log_flashcard_stats(
    body: FlashcardStatsRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Store flashcard session performance in MongoDB.

    Persists avg_recognition_time and correct_answers so the ML model can
    incorporate flashcard mastery into the OULAD engagement features.
    Maps to activity_type='flashcard' in the engagement_events collection.
    """
    combat_proficiency = (
        body.correct_answers / body.total_cards if body.total_cards > 0 else 0.0
    )

    event = EngagementEvent(
        user_id=user_id,
        content_id=body.content_id,
        activity_type="flashcard",
        sum_click=body.correct_answers,
        time_spent_seconds=body.avg_recognition_time * body.total_cards,
        event_type="flashcard_session",
        domain=body.domain,
    )
    await event.insert()

    return FlashcardStatsResponse(
        combat_proficiency=combat_proficiency,
        avg_recognition_time=body.avg_recognition_time,
        event_id=str(event.id),
    )
