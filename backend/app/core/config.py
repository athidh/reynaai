"""Core configuration — reads from .env file."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ── App ───────────────────────────────────────────────────────────────
    APP_NAME: str = "Reyna AI Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # ── JWT ───────────────────────────────────────────────────────────────
    SECRET_KEY: str = "CHANGE_ME_SUPER_SECRET_KEY_32_CHARS_MIN"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    # ── MongoDB Atlas ─────────────────────────────────────────────────────
    MONGODB_URL: str = "mongodb://localhost:27017"
    MONGODB_DB_NAME: str = "reyna_ai"

    # ── NVIDIA NIM / Llama 3 ─────────────────────────────────────────────
    NIM_API_KEY: str = ""
    NIM_ENDPOINT: str = "https://integrate.api.nvidia.com/v1"
    NIM_MODEL: str = "meta/llama3-8b-instruct"

    # ── OpenAI (fallback) ─────────────────────────────────────────────────
    OPENAI_API_KEY: str = ""

    # ── OULAD Data paths ──────────────────────────────────────────────────
    OULAD_DATA_DIR: str = "../Ai-Tutor/Ai-Tutor/anonymisedData"
    ENGAGEMENT_MATRIX_PATH: str = "../Ai-Tutor/Ai-Tutor/engagement_matrix.csv"


settings = Settings()
