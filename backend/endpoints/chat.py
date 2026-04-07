from typing import List

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from db.session import get_db
from models.chat_history import ChatHistory
from models.user import User
from schemas.chat import ChatMessageCreate, ChatMessageOut
from services.auth import get_current_user

router = APIRouter(tags=["chat"])

# Lazy-initialised agent router (avoids heavy imports at module load time)
_router = None


# ---------------------------------------------------------------------------
# POST /chat/message — save a single message and return it
# ---------------------------------------------------------------------------
@router.post("/message", response_model=ChatMessageOut, status_code=201)
def save_message(
    payload: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ChatHistory:
    entry = ChatHistory(
        chat=payload.content,
        role=payload.role,
        user_id=current_user.id,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


# ---------------------------------------------------------------------------
# GET /chat/history — return message history for the current user
# ---------------------------------------------------------------------------
@router.get("/history", response_model=List[ChatMessageOut])
def get_history(
    limit: int = Query(default=50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> List[ChatHistory]:
    rows = (
        db.query(ChatHistory)
        .filter(ChatHistory.user_id == current_user.id)
        .order_by(ChatHistory.created_at.asc())
        .limit(limit)
        .all()
    )
    return rows


# ---------------------------------------------------------------------------
# POST /chat/watsonx — route through the multi-agent framework
# ---------------------------------------------------------------------------

class WatsonxBody(BaseModel):
    message: str
    history: List[dict] = []


@router.post("/watsonx")
def chat_watsonx(
    payload: WatsonxBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    global _router
    if _router is None:
        from agents.router import AgentRouter
        _router = AgentRouter()

    user_context = {
        "username": current_user.username,
        "fav_driver": current_user.fav_driver or "",
        "fav_team": current_user.fav_team or "",
    }

    reply = _router.route(payload.message, payload.history, user_context)

    # Persist both messages
    user_entry = ChatHistory(chat=payload.message, role="user", user_id=current_user.id)
    assistant_entry = ChatHistory(chat=reply, role="assistant", user_id=current_user.id)
    db.add(user_entry)
    db.add(assistant_entry)
    db.commit()

    return {"reply": reply}
