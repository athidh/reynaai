"""YouTube Search & Transcript Service.

Implements the /fetch-content logic (single video) and
/search-videos (multi-result grid) logic:
  1. Accept a search query + optional language preference.
  2. Use yt-dlp to find the best-matching YouTube video(s).
  3. Fetch the transcript via youtube-transcript-api.
  4. Clean and return the plain-text transcript + metadata.
"""
from __future__ import annotations

import re
from typing import Optional

import yt_dlp
try:
    from youtube_transcript_api import YouTubeTranscriptApi
    # v0.6+ error classes moved
    try:
        from youtube_transcript_api._errors import TranscriptsDisabled, NoTranscriptFound
    except ImportError:
        from youtube_transcript_api import TranscriptsDisabled, NoTranscriptFound
except ImportError:
    # Fallback stub when package is not installed
    class YouTubeTranscriptApi:  # type: ignore
        pass
    class TranscriptsDisabled(Exception):  # type: ignore
        pass
    class NoTranscriptFound(Exception):  # type: ignore
        pass


# ── Helpers ───────────────────────────────────────────────────────────────────

def _clean_text(raw: str) -> str:
    """Remove extra whitespace and HTML artefacts from transcript text."""
    raw = re.sub(r"\[.*?\]", "", raw)          # remove [Music], [Applause] etc.
    raw = re.sub(r"<[^>]+>", "", raw)           # strip HTML tags
    raw = re.sub(r"\s+", " ", raw).strip()
    return raw


def _search_video_id(query: str) -> Optional[str]:
    """Use yt-dlp to find the top-result video ID for *query*.

    Returns the YouTube video ID string, or None on failure.
    """
    opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "default_search": "ytsearch1",
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        try:
            result = ydl.extract_info(f"ytsearch1:{query}", download=False)
            if result and "entries" in result and result["entries"]:
                entry = result["entries"][0]
                return entry.get("id")
        except Exception:
            return None
    return None


def _fetch_transcript(video_id: str, languages: list[str] | None = None) -> list[dict]:
    """Return raw transcript segments for *video_id*.

    Targets youtube-transcript-api v1.x (instance-based):
      - api.fetch(video_id, languages=[...])  → FetchedTranscript (iterable)
      - api.list(video_id)                    → TranscriptList
    Falls back to the old static get_transcript() for older installs.
    """
    langs = languages or ["en", "en-US", "en-GB"]

    try:
        api = YouTubeTranscriptApi()
    except TypeError:
        # Older API is not instantiable — fall through to legacy path
        api = None

    # ── v1.x / v0.6+ path ────────────────────────────────────────────────────
    if api is not None and hasattr(api, "fetch"):
        # Primary: fetch preferred languages
        try:
            result = api.fetch(video_id, languages=langs)
            return [{"text": s.text, "start": s.start, "duration": s.duration}
                    if hasattr(s, "text") else dict(s)
                    for s in result]
        except Exception:
            pass

        # Fallback: any auto-generated caption
        try:
            tlist = api.list(video_id)
            transcript = tlist.find_generated_transcript(["en"])
            result = transcript.fetch()
            return [{"text": s.text, "start": s.start, "duration": s.duration}
                    if hasattr(s, "text") else dict(s)
                    for s in result]
        except Exception:
            return []

    # ── Legacy v0.5 static path ───────────────────────────────────────────────
    try:
        return YouTubeTranscriptApi.get_transcript(video_id, languages=langs)  # type: ignore
    except Exception:
        try:
            tlist = YouTubeTranscriptApi.list_transcripts(video_id)  # type: ignore
            transcript = tlist.find_generated_transcript(["en"])
            return transcript.fetch()
        except Exception:
            return []


# ── Public API ────────────────────────────────────────────────────────────────

def search_videos(query: str, count: int = 6, language: str = "en") -> list[dict]:
    """Search YouTube for *query* (filtered by *language*) and return up to *count* results."""
    # Append language hint to query so yt-dlp surfaces language-appropriate results
    lang_hints: dict[str, str] = {
        "hi": "hindi", "ta": "tamil", "es": "español", "fr": "français",
        "de": "deutsch", "ja": "日本語", "zh": "中文",
    }
    lang_tag = lang_hints.get(language, "")
    effective_query = f"{query} {lang_tag}".strip() if lang_tag else query

    opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "default_search": f"ytsearch{count}",
    }
    results: list[dict] = []
    with yt_dlp.YoutubeDL(opts) as ydl:
        try:
            info = ydl.extract_info(f"ytsearch{count}:{effective_query}", download=False)
            entries = info.get("entries", []) if info else []
            for entry in entries:
                if not entry:
                    continue
                vid_id = entry.get("id") or entry.get("url", "").split("v=")[-1]
                if not vid_id:
                    continue
                results.append({
                    "video_id": vid_id,
                    "title": entry.get("title", "Untitled"),
                    "url": f"https://www.youtube.com/watch?v={vid_id}",
                    "thumbnail": entry.get("thumbnail") or f"https://img.youtube.com/vi/{vid_id}/mqdefault.jpg",
                    "duration": entry.get("duration"),
                })
        except Exception as exc:
            print(f"[youtube_service] search_videos failed: {exc}")
    return results


def _extract_video_id_from_url(query: str) -> str | None:
    """If query is a YouTube URL or bare 11-char ID, return the video ID, else None."""
    import re
    # youtu.be/ID
    m = re.search(r'youtu\.be/([A-Za-z0-9_-]{11})', query)
    if m:
        return m.group(1)
    # youtube.com/watch?v=ID
    m = re.search(r'[?&]v=([A-Za-z0-9_-]{11})', query)
    if m:
        return m.group(1)
    # Bare 11-char video ID (only alphanumeric + _ -)
    if re.fullmatch(r'[A-Za-z0-9_-]{11}', query.strip()):
        return query.strip()
    return None


def fetch_content(query: str, languages: list[str] | None = None) -> dict:
    """Fetch transcript + metadata for a YouTube video.

    Accepts:
    - A search query  (e.g. "machine learning basics")
    - A YouTube URL   (e.g. "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    - A bare video ID (e.g. "dQw4w9WgXcQ")
    """
    # ── Direct video ID / URL — skip search ───────────────────────────────────
    video_id = _extract_video_id_from_url(query)

    # ── Search query — use yt-dlp to find the best match ─────────────────────
    if not video_id:
        video_id = _search_video_id(query)

    if not video_id:
        return {"video_id": None, "query": query, "transcript_text": "",
                "transcript_segments": [], "word_count": 0,
                "error": "Could not find a YouTube video for the given query."}

    segments = _fetch_transcript(video_id, languages)
    if not segments:
        return {"video_id": video_id, "query": query, "transcript_text": "",
                "transcript_segments": [], "word_count": 0,
                "error": "Transcript not available for this video."}

    raw_text = " ".join(seg.get("text", "") for seg in segments)
    clean = _clean_text(raw_text)

    return {
        "video_id": video_id,
        "url": f"https://www.youtube.com/watch?v={video_id}",
        "query": query,
        "transcript_text": clean,
        "transcript_segments": segments,
        "word_count": len(clean.split()),
        "error": None,
    }
