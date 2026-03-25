"""Analytics Route — API v1.

GET /api/v1/analytics/{user_id}
Fetches historical engagement events for a user, grouped by day over the last 7 days.
Calculates the 'Engagement Trend' for R8 Analytics Dashboard.
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

from fastapi import APIRouter

from app.models.engagement import EngagementEvent
from app.services.oulad_engine import get_live_features

router = APIRouter(prefix="/analytics", tags=["analytics"])

@router.get("/{user_id}")
async def get_engagement_analytics(user_id: str) -> Dict[str, Any]:
    """Retrieve historical engagement scores mapped to the last 7 days."""
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=6)
    
    # 1. Fetch the overall engagement profile to get the rank and score
    profile = await get_live_features(user_id)
    overall_score = profile.get("engagement_score", 0.0)
    
    # Compute Battle Badge (e.g. from engagement matrix logic mapping score to Novel/Strategist/Master)
    if overall_score >= 0.66:
        battle_badge = "Master"
    elif overall_score >= 0.33:
        battle_badge = "Strategist"
    else:
        battle_badge = "Novice"
        
    # 2. Fetch the EngagementEvent logs for the last 7 days from MongoDB
    events = await EngagementEvent.find(
        EngagementEvent.user_id == user_id,
        EngagementEvent.logged_at >= start_date
    ).to_list()
    
    # Initialize dictionary for past 7 days to 0
    daily_interactions = {}
    for i in range(7):
        day_str = (start_date + timedelta(days=i)).strftime("%Y-%m-%d")
        daily_interactions[day_str] = 0.0

    # Aggregate interaction scores (sum_click) per day
    for event in events:
        if event.logged_at:
            day_str = event.logged_at.strftime("%Y-%m-%d")
            if day_str in daily_interactions:
                daily_interactions[day_str] += float(event.sum_click)
                
    # Format into a sorted list for the frontend line chart
    trend_data = [
        {"date": k, "score": v}
        for k, v in sorted(daily_interactions.items())
    ]
    
    return {
        "user_id": user_id,
        "battle_badge": battle_badge,
        "overall_score": overall_score,
        "engagement_trend": trend_data
    }
