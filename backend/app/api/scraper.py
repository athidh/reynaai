"""Scraper routes: /scraper/*

  GET  /scraper/fetch-content    → single video transcript + metadata
  GET  /scraper/search-videos    → multiple video results for grid display
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from fastapi.security import OAuth2PasswordBearer

from app.services.youtube_service import fetch_content, search_videos

router = APIRouter(prefix="/scraper", tags=["scraper"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


@router.get("/fetch-content")
async def get_content(
    query: str = Query(..., description="Search query / topic to look up on YouTube"),
    languages: Optional[List[str]] = Query(default=None, description="Preferred transcript languages, e.g. en"),
):
    """Search YouTube for *query* and return the cleaned transcript + metadata."""
    result = fetch_content(query, languages)
    return result


@router.get("/search-videos")
async def get_search_videos(
    query: str = Query(..., description="Search query for YouTube"),
    count: int = Query(default=6, ge=1, le=20, description="Number of results to return"),
    language: str = Query(default="en", description="Preferred result language code, e.g. en, hi, ta"),
):
    """Search YouTube and return up to *count* video cards for the dashboard grid."""
    results = search_videos(query, count, language=language)
    return results
