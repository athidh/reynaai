"""Beanie EngagementEvent Document for MongoDB Atlas.

Maps Flutter heartbeat pings to OULAD-compatible fields.
"""
from datetime import datetime, timezone
from typing import Optional

from beanie import Document


class EngagementEvent(Document):
    user_id: str                              # MongoDB ObjectId string of the User
    content_id: Optional[str] = None         # YouTube video ID or chapter ID
    activity_type: Optional[str] = "video"   # "video", "flashcard", "quiz"
    sum_click: int = 1                        # interactions in this ping
    time_spent_seconds: float = 0.0          # session duration in seconds
    event_type: Optional[str] = None         # "pause", "seek", "complete", "open"
    domain: Optional[str] = None             # user's domain_interest at time of log
    logged_at: datetime = None

    def model_post_init(self, __context):
        if self.logged_at is None:
            object.__setattr__(self, "logged_at", datetime.now(timezone.utc))

    class Settings:
        name = "engagement_events"
        indexes = ["user_id", "logged_at"]
