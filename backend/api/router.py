from fastapi import APIRouter

from endpoints.auth import router as auth_router
from endpoints.chat import router as chat_router
from endpoints.f1 import router as f1_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth")
api_router.include_router(chat_router, prefix="/chat")
api_router.include_router(f1_router, prefix="/f1")
