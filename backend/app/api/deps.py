from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from beanie import PydanticObjectId

from app.core.security import decode_access_token
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    return payload["sub"]

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """Return the full User document (needed by tutor for demographics)."""
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    user = await User.get(PydanticObjectId(payload["sub"]))
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return user

async def verify_token(token: str) -> User:
    """Verify raw token string (useful for WebSockets)."""
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    user = await User.get(PydanticObjectId(payload["sub"]))
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return user
