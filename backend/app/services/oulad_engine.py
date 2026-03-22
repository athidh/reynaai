"""OULAD Analytics Engine — Live Calculator + Real Model Bridge.

This module serves three purposes:
  1. Compute the 8 OULAD features from *live* EngagementEvent rows
     (what Reyna AI collects from the Flutter app).
  2. Predict student success probability using the trained ML model
     (pass_predictor_pipeline.joblib).
  3. Delegate study-plan generation to the REAL model:
     engagement_studyplan.py in the Ai-Tutor folder.

The 8 core features (per reyna_backend.md spec):
  1. total_interactions
  2. days_active
  3. interactions_first_28_days
  4. avg_interactions_per_active_day
  5. recency_days
  6. weekly_activity_ratio
  7. submissions_count          ← "flashcard reviews / quiz attempts"
  8. avg_time_per_session
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import joblib
import numpy as np
import pandas as pd

# ── Import the REAL study-plan model from backend/app/ml/ (self-contained) ───
# __file__ = backend/app/services/oulad_engine.py
# ml folder is one level up (services -> app) then into ml/
_ML_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../ml")
)
if _ML_DIR not in sys.path:
    sys.path.insert(0, _ML_DIR)

try:
    from engagement_studyplan import (  # type: ignore
        build_engagement_matrix,
        generate_study_plan,
    )
    _MODEL_AVAILABLE = True
except ImportError:
    _MODEL_AVAILABLE = False
    print(
        "[oulad_engine] WARNING: Could not import engagement_studyplan.py. "
        "Falling back to built-in deterministic planner. "
        f"Looked in: {_ML_DIR}"
    )


# ── ML Model (loaded once at module import) ──────────────────────────────────

_ML_MODEL = None
# Model lives inside backend/app/ml/ — fully self-contained for deployment
_ML_MODEL_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../ml/pass_predictor_pipeline.joblib")
)


def _load_ml_model():
    """Load the trained Random Forest pipeline for success prediction."""
    global _ML_MODEL
    if _ML_MODEL is not None:
        return _ML_MODEL
    
    if not os.path.exists(_ML_MODEL_PATH):
        print(f"[oulad_engine] WARNING: ML model not found at {_ML_MODEL_PATH}")
        return None
    
    try:
        _ML_MODEL = joblib.load(_ML_MODEL_PATH)
        print(f"[oulad_engine] Successfully loaded ML model from {_ML_MODEL_PATH}")
        return _ML_MODEL
    except Exception as e:
        print(f"[oulad_engine] ERROR loading ML model: {e}")
        return None


# ── OULAD benchmark (loaded once at module import) ────────────────────────────

_BENCHMARK_DF: Optional[pd.DataFrame] = None


def _load_benchmark() -> pd.DataFrame:
    global _BENCHMARK_DF
    if _BENCHMARK_DF is not None:
        return _BENCHMARK_DF
    # Look for engagement_matrix.csv inside backend/app/ml/ first, then fall back
    path = os.environ.get(
        "ENGAGEMENT_MATRIX_PATH",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "../ml/engagement_matrix.csv")),
    )
    if os.path.exists(path):
        _BENCHMARK_DF = pd.read_csv(path)
    else:
        _BENCHMARK_DF = pd.DataFrame()
    return _BENCHMARK_DF


# ── Feature computation ───────────────────────────────────────────────────────

def compute_features(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Compute the 8 OULAD features from a list of raw event dicts.

    Each event dict is expected to have at minimum:
        logged_at (datetime or ISO str), sum_click (int),
        time_spent_seconds (float), activity_type (str)

    Returns a dict with all 8 features plus an engagement_score.
    """
    if not events:
        return _empty_features()

    df = pd.DataFrame(events)

    # normalise logged_at
    df["logged_at"] = pd.to_datetime(df["logged_at"], utc=True, errors="coerce")
    df = df.dropna(subset=["logged_at"])
    if df.empty:
        return _empty_features()

    df["date_only"] = df["logged_at"].dt.date
    df["sum_click"] = pd.to_numeric(df.get("sum_click", 1), errors="coerce").fillna(1)
    df["time_spent_seconds"] = pd.to_numeric(
        df.get("time_spent_seconds", 0), errors="coerce"
    ).fillna(0)

    now = datetime.now(timezone.utc)
    first_day = df["logged_at"].min()
    last_day = df["logged_at"].max()

    # 1. total_interactions
    total_interactions = float(df["sum_click"].sum())

    # 2. days_active
    days_active = int(df["date_only"].nunique())

    # 3. interactions_first_28_days
    cutoff = first_day + pd.Timedelta(days=28)
    first_28 = float(df[df["logged_at"] <= cutoff]["sum_click"].sum())

    # 4. avg_interactions_per_active_day
    avg_per_day = total_interactions / max(days_active, 1)

    # 5. recency_days  (days since last activity)
    recency_days = (now - last_day).days

    # 6. weekly_activity_ratio  (last 4 weeks / first 4 weeks)
    df["days_since_first"] = (df["logged_at"] - first_day).dt.days
    df["week_idx"] = (df["days_since_first"] // 7).astype(int)
    per_week = df.groupby("week_idx")["sum_click"].sum()

    first4 = per_week[per_week.index.isin(range(4))].mean() if not per_week.empty else 0
    last4_idx = sorted(per_week.index)[-4:] if len(per_week) >= 4 else per_week.index
    last4 = per_week[per_week.index.isin(last4_idx)].mean() if not per_week.empty else 0
    weekly_ratio = float(last4 / first4) if first4 > 0 else 1.0

    # 7. submissions_count  (events with activity_type in quiz/flashcard)
    submission_types = {"quiz", "flashcard", "assessment", "review"}
    act_col = df.get("activity_type", pd.Series(dtype=str))
    if "activity_type" in df.columns:
        submissions_count = int(
            df["activity_type"].str.lower().isin(submission_types).sum()
        )
    else:
        submissions_count = 0

    # 8. avg_time_per_session
    avg_time = float(df["time_spent_seconds"].mean())

    features = {
        "total_interactions": total_interactions,
        "days_active": days_active,
        "interactions_first_28_days": first_28,
        "avg_interactions_per_active_day": round(avg_per_day, 2),
        "recency_days": recency_days,
        "weekly_activity_ratio": round(weekly_ratio, 4),
        "submissions_count": submissions_count,
        "avg_time_per_session": round(avg_time, 2),
    }

    features["engagement_score"] = _compute_score(features)
    features["engagement_level"] = _level(features["engagement_score"])
    features["consistency"] = _consistency(weekly_ratio)
    features["percentile_rank"] = _percentile(features["total_interactions"])

    return features


def _empty_features() -> Dict[str, Any]:
    return {
        "total_interactions": 0,
        "days_active": 0,
        "interactions_first_28_days": 0,
        "avg_interactions_per_active_day": 0.0,
        "recency_days": 0,
        "weekly_activity_ratio": 1.0,
        "submissions_count": 0,
        "avg_time_per_session": 0.0,
        "engagement_score": 0.0,
        "engagement_level": "low",
        "consistency": "stable",
        "percentile_rank": 0.0,
    }


def _compute_score(f: Dict[str, Any]) -> float:
    """Weighted score 0–1 using the same weights as engagement_studyplan.py."""
    bm = _load_benchmark()

    def _norm(val: float, col: str) -> float:
        if bm.empty or col not in bm.columns:
            return min(val / max(val, 1), 1.0)
        mn, mx = bm[col].min(), bm[col].max()
        if mx == mn:
            return 0.5
        return float(np.clip((val - mn) / (mx - mn), 0, 1))

    score = (
        _norm(f["total_interactions"], "total_interactions") * 0.40
        + _norm(f["days_active"], "days_active") * 0.20
        + _norm(f["avg_interactions_per_active_day"], "avg_interactions_per_active_day") * 0.20
        + (1 - _norm(f["recency_days"], "recency_days")) * 0.15  # inverted
        + (1 - min(abs(f["weekly_activity_ratio"] - 1), 1)) * 0.05
    )
    return round(float(np.clip(score, 0, 1)), 4)


def _level(score: float) -> str:
    if score < 0.33:
        return "low"
    if score < 0.66:
        return "medium"
    return "high"


def _consistency(ratio: float) -> str:
    if ratio < 0.8:
        return "dropping"
    if ratio > 1.2:
        return "increasing"
    return "stable"


def _percentile(total_interactions: float) -> float:
    bm = _load_benchmark()
    if bm.empty or "total_interactions" not in bm.columns:
        return 0.0
    pct = float((bm["total_interactions"] < total_interactions).mean() * 100)
    return round(pct, 1)


# ── Live Feature Aggregation ─────────────────────────────────────────────────

async def get_live_features(user_id: str) -> Dict[str, Any]:
    """Query all EngagementEvents for a user and compute the 8 OULAD features.
    
    Args:
        user_id: MongoDB ObjectId string of the user
        
    Returns:
        Dict with 8 OULAD features + engagement_score, engagement_level, etc.
    """
    from ..models.engagement import EngagementEvent
    
    # Query all engagement events for this user
    events = await EngagementEvent.find(
        EngagementEvent.user_id == user_id
    ).to_list()
    
    # Convert to dict format expected by compute_features
    event_dicts = [
        {
            "logged_at": event.logged_at,
            "sum_click": event.sum_click,
            "time_spent_seconds": event.time_spent_seconds,
            "activity_type": event.activity_type or "video",
            "domain": event.domain,
        }
        for event in events
    ]
    
    return compute_features(event_dicts)


# ── ML Success Prediction ────────────────────────────────────────────────────

async def predict_success(user_id: str) -> Dict[str, Any]:
    """Predict student success probability using the trained ML model.
    
    Combines the 8 OULAD features from engagement events with user demographics
    to predict the probability of passing (0.0 to 1.0).
    
    Args:
        user_id: MongoDB ObjectId string of the user
        
    Returns:
        Dict with:
            - success_probability: float (0.0 to 1.0)
            - features: Dict with 8 OULAD features
            - demographics: Dict with user demographic data
            - model_available: bool
            - error: Optional error message
    """
    from ..models.user import User
    
    # Load the ML model
    model = _load_ml_model()
    if model is None:
        return {
            "success_probability": 0.5,  # neutral default
            "features": {},
            "demographics": {},
            "model_available": False,
            "error": "Model file not found"
        }
    
    # Get user demographics
    user = await User.get(user_id)
    if not user:
        return {
            "success_probability": 0.5,
            "features": {},
            "demographics": {},
            "model_available": True,
            "error": "User not found"
        }
    
    # Get live OULAD features
    features = await get_live_features(user_id)
    
    # Check if user has any engagement data
    if features.get("total_interactions", 0) == 0:
        return {
            "success_probability": 0.5,
            "features": features,
            "demographics": {},
            "model_available": True,
            "error": "Insufficient engagement data"
        }
    
    # Prepare input DataFrame matching the model's expected features
    # The model expects these columns (from train_model.py):
    # Numeric: total_interactions, days_active, avg_interactions_per_active_day,
    #          recency_days, interactions_first_28_days, weekly_activity_ratio,
    #          num_of_prev_attempts, studied_credits,
    #          avg_assessment_score, num_assessments, max_assessment_score, std_assessment_score
    # Categorical: gender, highest_education, age_band, disability
    
    input_data = {
        # OULAD engagement features (we have these)
        "total_interactions": features.get("total_interactions", 0),
        "days_active": features.get("days_active", 0),
        "avg_interactions_per_active_day": features.get("avg_interactions_per_active_day", 0.0),
        "recency_days": features.get("recency_days", 0),
        "interactions_first_28_days": features.get("interactions_first_28_days", 0),
        "weekly_activity_ratio": features.get("weekly_activity_ratio", 1.0),
        
        # Student info features (defaults for Reyna AI - we don't track these)
        "num_of_prev_attempts": 0,  # New students
        "studied_credits": 60,       # Default course load
        
        # Assessment features (defaults - we use submissions_count instead)
        "avg_assessment_score": features.get("submissions_count", 0) * 10,  # Rough proxy
        "num_assessments": features.get("submissions_count", 0),
        "max_assessment_score": features.get("submissions_count", 0) * 10,
        "std_assessment_score": 0,
        
        # Demographics (from User model)
        "gender": user.gender or "M",  # Default to avoid missing
        "highest_education": user.education or "A Level",  # Default
        "age_band": user.age_band or "0-35",  # Default
        "disability": user.disability or "N",  # Default
    }
    
    demographics = {
        "gender": user.gender,
        "education": user.education,
        "age_band": user.age_band,
        "disability": user.disability,
    }
    
    try:
        # Create DataFrame with single row
        X = pd.DataFrame([input_data])
        
        # Get prediction probability
        proba = model.predict_proba(X)[0, 1]  # Probability of class 1 (Pass)
        
        return {
            "success_probability": round(float(proba), 4),
            "features": features,
            "demographics": demographics,
            "model_available": True,
            "error": None
        }
        
    except Exception as e:
        print(f"[oulad_engine] ERROR during prediction: {e}")
        return {
            "success_probability": 0.5,
            "features": features,
            "demographics": demographics,
            "model_available": True,
            "error": f"Prediction failed: {str(e)}"
        }


# ── Study-plan generation — delegates to the REAL model ──────────────────────

def generate_study_plan_deterministic(features: Dict[str, Any], success_probability: Optional[float] = None) -> Dict[str, Any]:
    """Generate a 7-day study plan.

    If engagement_studyplan.py was successfully imported, this calls the REAL
    model's generate_study_plan() directly.  Otherwise it falls back to the
    built-in rule-based planner below.

    The real model expects a DataFrame with a 'student_id' column, so we wrap
    the features dict into a single-row DataFrame before calling it.
    
    Args:
        features: Dict with 8 OULAD features
        success_probability: Optional ML model prediction (0.0 to 1.0)
    
    Returns:
        Dict with engagement_profile, daily_minutes, days, and optionally success_probability
    """
    if _MODEL_AVAILABLE:
        try:
            # Build a minimal single-student DataFrame that the model expects
            row = {
                "student_id": features.get("student_id", 0),
                "total_interactions": features.get("total_interactions", 0),
                "days_active": features.get("days_active", 0),
                "interactions_first_28_days": features.get("interactions_first_28_days", 0),
                "avg_interactions_per_active_day": features.get("avg_interactions_per_active_day", 0),
                "recency_days": features.get("recency_days", 0),
                "weekly_activity_ratio": features.get("weekly_activity_ratio", 1.0),
            }
            eng_df = pd.DataFrame([row])
            plan = generate_study_plan(eng_df, student_id=row["student_id"])
            # attach our richer features to the profile block
            plan["engagement_profile"] = features
            if success_probability is not None:
                plan["success_probability"] = success_probability
            return plan
        except Exception as exc:
            print(f"[oulad_engine] Real model call failed ({exc}), using fallback.")

    # ── Built-in fallback (identical logic to engagement_studyplan.py) ────────
    level = features.get("engagement_level", "medium")
    consistency = features.get("consistency", "stable")
    recency = features.get("recency_days", 0)

    # Adjust intensity based on success probability if provided
    if success_probability is not None:
        if success_probability < 0.5:
            # High-intensity recovery plan
            level = "low"  # More time needed
            consistency = "dropping"
        elif success_probability > 0.8:
            # Elite mastery plan
            level = "high"
            consistency = "increasing"

    base = {"low": 90, "medium": 60, "high": 30}[level]
    adj = {"dropping": 30, "increasing": -10, "stable": 0}[consistency]
    recency_adj = min(30, int(recency // 30) * 10) if recency > 30 else 0
    daily_min = max(20, base + adj + recency_adj)

    patterns = {
        "low": [
            ("Review notes", ["Skim lecture notes", "Make summary sheet"]),
            ("Watch lectures", ["Watch one recorded lecture", "Take notes"]),
            ("Practice", ["Solve 2-3 practice problems"]),
            ("Targeted revision", ["Identify weakest topic", "Focused exercises"]),
            ("Mock test", ["Short timed quiz", "Review mistakes"]),
            ("Reflection", ["Review week progress", "Plan next steps"]),
            ("Mixed practice", ["Mix of problems and review"]),
        ],
        "medium": [
            ("Review notes", ["Revise summaries", "Flashcards for facts"]),
            ("Watch lectures", ["Watch selected lecture clips"]),
            ("Practice", ["Solve 4-6 problems"]),
            ("Focused drill", ["Drill on weaker subtopics"]),
            ("Mock test", ["Timed practice test", "Review errors"]),
            ("Active recall", ["Teach a concept aloud"]),
            ("Mixed practice", ["Mixed problems + quick review"]),
        ],
        "high": [
            ("Warm-up review", ["Quick recap of notes"]),
            ("Apply concepts", ["Solve challenging problems"]),
            ("Timed problems", ["Timed problem set"]),
            ("Deep dive", ["Focus on advanced topics"]),
            ("Full mock test", ["Full practice test", "Detailed review"]),
            ("Reflection", ["Analyze mistakes + plan"]),
            ("Consolidation", ["Flashcards + quick drills"]),
        ],
    }

    tip_map = {
        ("low", "dropping"): "Break study into short 10-min blocks and set a daily reminder.",
        ("low", "stable"): "Short daily sessions beat long infrequent ones.",
        ("medium", "dropping"): "Your momentum is slipping — try a fixed study time each day.",
        ("medium", "increasing"): "Great progress! Keep the streak going.",
        ("high", "stable"): "You're crushing it — keep consistent and push depth.",
    }
    tip = tip_map.get((level, consistency), "Stay consistent: daily beats occasional.")

    days = []
    for i, (focus, tasks) in enumerate(patterns[level], start=1):
        minutes = int(daily_min * (1.0 - 0.05 * ((i - 1) // 2)))
        days.append({"day": i, "focus": focus, "recommended_minutes": minutes, "tasks": tasks, "tip": tip})

    result = {
        "engagement_profile": features,
        "daily_minutes": daily_min,
        "days": days,
    }
    
    if success_probability is not None:
        result["success_probability"] = success_probability
    
    return result
