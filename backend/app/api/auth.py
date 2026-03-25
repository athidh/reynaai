"""Auth routes: /signup and /login with JWT — MongoDB version."""
from typing import Optional

from beanie.operators import Eq
from fastapi import APIRouter, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi import Depends
from pydantic import BaseModel, EmailStr

from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.api.deps import get_current_user_id

router = APIRouter(prefix="/auth", tags=["auth"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class SignupRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
    age_band: str                     # Required: "0-35" | "35-55" | "55+"
    education: str                    # Required: "Lower Than A Level" | "A Level" | "HE" | "Post Grad"
    domain_interest: str              # Required: Selected domain or custom text
    gender: Optional[str] = "M"       # Default to "M"
    disability: Optional[str] = "N"   # Default to "N"


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str
    domain_interest: Optional[str] = None


class UserProfile(BaseModel):
    id: str
    name: str
    email: str
    age: Optional[int] = None
    age_band: Optional[str] = None
    education: Optional[str] = None
    domain_interest: Optional[str] = None
    gender: Optional[str] = None
    disability: Optional[str] = None


# ── Shared Dependencies are now in app/api/deps.py ──────────────────────────


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(body: SignupRequest):
    # Debug logging to see what's being received
    print(f"[DEBUG] Signup request body: {body.model_dump()}")
    
    existing = await User.find_one(User.email == body.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered.")

    user = User(
        name=body.name,
        email=body.email,
        hashed_password=hash_password(body.password),
        age_band=body.age_band,
        education=body.education,
        domain_interest=body.domain_interest,
        gender=body.gender,
        disability=body.disability,
    )
    await user.insert()

    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(
        access_token=token,
        user_id=str(user.id),
        name=user.name,
        domain_interest=user.domain_interest,
    )


@router.post("/login", response_model=TokenResponse)
async def login(form: OAuth2PasswordRequestForm = Depends()):
    user = await User.find_one(User.email == form.username)
    if not user or not verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(
        access_token=token,
        user_id=str(user.id),
        name=user.name,
        domain_interest=user.domain_interest,
    )


@router.get("/me", response_model=UserProfile)
async def get_me(user_id: str = Depends(get_current_user_id)):
    from beanie import PydanticObjectId
    user = await User.get(PydanticObjectId(user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return UserProfile(
        id=str(user.id),
        name=user.name,
        email=user.email,
        age=user.age,
        age_band=user.age_band,
        education=user.education,
        domain_interest=user.domain_interest,
        gender=user.gender,
        disability=user.disability,
    )
