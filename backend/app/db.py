"""MongoDB Atlas connection via Motor + Beanie."""
import motor.motor_asyncio
from beanie import init_beanie

from app.core.config import settings


def get_motor_client() -> motor.motor_asyncio.AsyncIOMotorClient:
    return motor.motor_asyncio.AsyncIOMotorClient(settings.MONGODB_URL)


async def init_db():
    """Initialise Beanie with all document models. Called on app startup."""
    from app.models.user import User
    from app.models.engagement import EngagementEvent

    client = get_motor_client()
    database = client[settings.MONGODB_DB_NAME]

    await init_beanie(
        database=database,
        document_models=[User, EngagementEvent],
    )
