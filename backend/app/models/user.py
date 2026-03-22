"""Beanie User Document for MongoDB Atlas."""
from datetime import datetime, timezone
from typing import Optional

from beanie import Document
from pydantic import EmailStr


class User(Document):
    name: str
    email: EmailStr
    hashed_password: str

    # Onboarding / personalization
    age: Optional[int] = None
    age_band: Optional[str] = None        # "0-35" | "35-55" | "55+"
    education: Optional[str] = None       # "Lower Than A Level" | "A Level" | "HE Qualification" | "Post Graduate Qualification"
    domain_interest: Optional[str] = None # "Medico" | "Data Scientist" | "Custom"

    # OULAD demographic features for ML model
    gender: Optional[str] = None          # "M" | "F"
    disability: Optional[str] = None      # "Y" | "N"

    created_at: datetime = None

    def model_post_init(self, __context):
        if self.created_at is None:
            object.__setattr__(self, "created_at", datetime.now(timezone.utc))

    class Settings:
        name = "users"
        indexes = ["email"]
