import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session

from db.session import get_db
from models.chat_history import ChatHistory
from models.conversation import Conversation
from models.user import User
from schemas.chat import ChatMessageCreate, ChatMessageOut
from schemas.conversation import ConversationCreate, ConversationOut, ConversationUpdate
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
# GET /chat/history — return message history for the current user with pagination
# ---------------------------------------------------------------------------
@router.get("/history", response_model=List[ChatMessageOut])
def get_history(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=500),
    conversation_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> List[ChatHistory]:
    q = db.query(ChatHistory).filter(ChatHistory.user_id == current_user.id)
    if conversation_id:
        q = q.filter(ChatHistory.conversation_id == uuid.UUID(conversation_id))
    rows = (
        q.order_by(ChatHistory.created_at.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return rows


# ---------------------------------------------------------------------------
# Conversation thread endpoints
# ---------------------------------------------------------------------------


@router.post("/conversations", response_model=ConversationOut, status_code=201)
def create_conversation(
    payload: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = Conversation(title=payload.title, user_id=current_user.id)
    db.add(conv)
    db.commit()
    db.refresh(conv)
    conv_out = ConversationOut.model_validate(conv)
    conv_out.message_count = 0
    return conv_out


@router.get("/conversations", response_model=List[ConversationOut])
def list_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    convs = (
        db.query(Conversation)
        .filter(Conversation.user_id == current_user.id)
        .order_by(Conversation.updated_at.desc())
        .all()
    )
    results = []
    for c in convs:
        count = db.query(ChatHistory).filter(ChatHistory.conversation_id == c.id).count()
        out = ConversationOut.model_validate(c)
        out.message_count = count
        results.append(out)
    return results


@router.get("/conversations/{conversation_id}", response_model=ConversationOut)
def get_conversation(
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id)
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    count = db.query(ChatHistory).filter(ChatHistory.conversation_id == conv.id).count()
    out = ConversationOut.model_validate(conv)
    out.message_count = count
    return out


@router.put("/conversations/{conversation_id}", response_model=ConversationOut)
def update_conversation(
    conversation_id: uuid.UUID,
    payload: ConversationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id)
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    conv.title = payload.title
    db.commit()
    db.refresh(conv)
    count = db.query(ChatHistory).filter(ChatHistory.conversation_id == conv.id).count()
    out = ConversationOut.model_validate(conv)
    out.message_count = count
    return out


@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id)
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    db.query(ChatHistory).filter(ChatHistory.conversation_id == conv.id).delete()
    db.delete(conv)
    db.commit()
    return {"detail": "Conversation deleted"}


@router.get("/conversations/{conversation_id}/messages", response_model=List[ChatMessageOut])
def get_conversation_messages(
    conversation_id: uuid.UUID,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify ownership
    conv = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id)
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    rows = (
        db.query(ChatHistory)
        .filter(ChatHistory.conversation_id == conversation_id)
        .order_by(ChatHistory.created_at.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return rows


@router.get("/search", response_model=List[ChatMessageOut])
def search_history(
    q: str = Query(..., min_length=1),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        db.query(ChatHistory)
        .filter(ChatHistory.user_id == current_user.id, ChatHistory.chat.ilike(f"%{q}%"))
        .order_by(ChatHistory.created_at.desc())
        .offset(offset)
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
    circuit_context: str = ""
    conversation_id: str = ""


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
        "circuit_context": payload.circuit_context,
        "language": current_user.language or "en",
    }

    reply = _router.route(payload.message, payload.history, user_context)

    # Resolve or create conversation
    conv_id = None
    if payload.conversation_id:
        conv_id = uuid.UUID(payload.conversation_id)
        # Update conversation's updated_at
        conv = db.query(Conversation).filter(Conversation.id == conv_id).first()
        if conv:
            conv.updated_at = sa_func.now()
    else:
        # Auto-create a conversation
        conv = Conversation(
            title=payload.message[:50],
            user_id=current_user.id,
        )
        db.add(conv)
        db.flush()
        conv_id = conv.id

    # Persist both messages
    user_entry = ChatHistory(
        chat=payload.message, role="user", user_id=current_user.id,
        conversation_id=conv_id,
    )
    assistant_entry = ChatHistory(
        chat=reply, role="assistant", user_id=current_user.id,
        conversation_id=conv_id,
    )
    db.add(user_entry)
    db.add(assistant_entry)
    db.commit()

    return {"reply": reply, "conversation_id": str(conv_id)}
