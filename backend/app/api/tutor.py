"""Tutor route — MongoDB version with ML prediction.

GET  /tutor/profile           → 8 OULAD features from user's MongoDB events
GET  /tutor/study-plan        → 7-day study plan (real model) + success probability
POST /tutor/reyna-response    → Llama 3 / NIM Socratic dialogue + flashcards + success probability
GET  /tutor/predict           → ML success probability prediction
POST /tutor/generate-cards    → Transcript → 5 Socratic flashcards via Llama 3
POST /tutor/chat              → Real-time Reyna chatroom with transcript context
"""
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.deps import get_current_user_id
from app.models.engagement import EngagementEvent
from app.services.oulad_engine import (
    compute_features,
    generate_study_plan_deterministic,
    get_live_features,
    predict_success,
)
from app.services.llama_service import generate_reyna_response, chat_with_reyna_conversational

router = APIRouter(prefix="/tutor", tags=["tutor"])


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_user_events(user_id: str) -> List[Dict[str, Any]]:
    events = (
        await EngagementEvent.find(EngagementEvent.user_id == user_id)
        .sort(+EngagementEvent.logged_at)
        .to_list()
    )
    return [
        {
            "logged_at": e.logged_at,
            "sum_click": e.sum_click,
            "time_spent_seconds": e.time_spent_seconds,
            "activity_type": e.activity_type,
            "domain": e.domain,
        }
        for e in events
    ]


# ── Schemas ───────────────────────────────────────────────────────────────────

class ReynaRequest(BaseModel):
    transcript_excerpt: Optional[str] = ""
    provider: Optional[str] = "nim"


class GenerateCardsRequest(BaseModel):
    """Generate 5 Socratic flashcards from a video transcript."""
    transcript_text: str = ""
    domain: Optional[str] = ""
    provider: Optional[str] = "nim"


class GenerateCardsResponse(BaseModel):
    flashcards: List[Dict[str, str]]
    greeting: Optional[str] = None
    socratic_question: Optional[str] = None
    motivation: Optional[str] = None
    combat_status: Optional[str] = None


class ChatRequest(BaseModel):
    """Real-time chat with Reyna using transcript + domain context."""
    message: str
    transcript_context: Optional[str] = ""
    domain: Optional[str] = ""
    history: Optional[List[Dict[str, str]]] = []  # [{"role": "user"|"assistant", "content": "..."}]


class ChatResponse(BaseModel):
    reply: str
    combat_status: Optional[str] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("/profile")
async def get_engagement_profile(user_id: str = Depends(get_current_user_id)):
    """Compute the 8 OULAD features from the current user's MongoDB event log."""
    features = await get_live_features(user_id)
    return {"user_id": user_id, "features": features}


@router.get("/predict")
async def get_success_prediction(user_id: str = Depends(get_current_user_id)):
    """Predict student success probability using the trained ML model.

    Returns:
        - success_probability: float (0.0 to 1.0)
        - features: 8 OULAD features
        - demographics: user demographic data
        - model_available: bool
        - error: optional error message
    """
    prediction = await predict_success(user_id)
    prediction["user_id"] = user_id
    return prediction


@router.get("/study-plan")
async def get_study_plan(user_id: str = Depends(get_current_user_id)):
    """Generate a 7-day study plan via the real engagement_studyplan.py model.

    Now includes ML success probability prediction to adjust plan intensity:
    - < 0.5: High-Intensity Recovery plan
    - > 0.8: Elite Mastery plan
    """
    # Get ML prediction
    prediction = await predict_success(user_id)
    success_prob = prediction.get("success_probability")
    features = prediction.get("features", {})

    # Generate study plan with success probability
    features["student_id"] = user_id
    plan = generate_study_plan_deterministic(features, success_probability=success_prob)
    plan["user_id"] = user_id

    # Add prediction metadata
    plan["prediction_metadata"] = {
        "success_probability": success_prob,
        "model_available": prediction.get("model_available", False),
        "demographics": prediction.get("demographics", {}),
    }

    return plan


@router.post("/reyna-response")
async def get_reyna_response(
    body: ReynaRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Call Llama 3 via NIM → Reyna's Socratic dialogue + 5 flashcards.

    Now includes ML success probability to inform Reyna's combat briefing tone.
    """
    # Get ML prediction
    prediction = await predict_success(user_id)
    success_prob = prediction.get("success_probability")
    features = prediction.get("features", {})

    # Generate Reyna response with success probability
    response = await generate_reyna_response(
        profile=features,
        transcript_excerpt=body.transcript_excerpt or "",
        provider=body.provider or "nim",
        predict_proba=success_prob,
    )

    return {
        "user_id": user_id,
        "reyna": response,
        "engagement_profile": features,
        "success_probability": success_prob,
        "model_available": prediction.get("model_available", False),
    }


@router.post("/generate-cards", response_model=GenerateCardsResponse)
async def generate_cards_from_transcript(
    body: GenerateCardsRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Generate 5 Socratic flashcards from a video transcript using Llama 3.

    This is the primary endpoint for the Flashcard Arena — called immediately
    after a video finishes in the Training Arena.

    Supply transcript_text (from fetch-content) and the user's domain for
    context-aware, Socratic questions aligned with their learning mission.
    """
    # Get ML prediction for tone adaptation
    prediction = await predict_success(user_id)
    success_prob = prediction.get("success_probability")
    features = prediction.get("features", {})

    # Inject domain into profile for Reyna system prompt
    domain = body.domain or features.get("domain", "")
    profile = {**features, "domain": domain, "domain_interest": domain}

    reyna = await generate_reyna_response(
        profile=profile,
        transcript_excerpt=body.transcript_text or "",
        provider=body.provider or "nim",
        predict_proba=success_prob,
    )

    return GenerateCardsResponse(
        flashcards=reyna.get("flashcards", []),
        greeting=reyna.get("greeting"),
        socratic_question=reyna.get("socratic_question"),
        motivation=reyna.get("motivation"),
        combat_status=reyna.get("combat_status"),
    )


@router.post("/chat", response_model=ChatResponse)
async def chat_with_reyna(
    body: ChatRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Real-time conversational chat — listens and responds to what the student says."""
    prediction = await predict_success(user_id)
    success_prob = prediction.get("success_probability")
    features = prediction.get("features", {})
    domain = body.domain or features.get("domain", "your field")

    reply = await chat_with_reyna_conversational(
        message=body.message,
        history=body.history or [],
        transcript_context=body.transcript_context or "",
        domain=domain,
        predict_proba=success_prob,
    )

    return ChatResponse(reply=reply, combat_status=None)
