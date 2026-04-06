from contextlib import asynccontextmanager

from fastapi import FastAPI

from api.router import api_router
from core.config import settings
from db.init_db import init_db
from endpoints.health import router as health_router


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    lifespan=lifespan,
)
app.include_router(health_router)
app.include_router(api_router, prefix="/api")
