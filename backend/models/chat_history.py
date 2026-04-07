import uuid

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from db.base import Base


class ChatHistory(Base):
    __tablename__ = "chatHistory"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    chat: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False, server_default="user")
    user_id: Mapped[uuid.UUID] = mapped_column(
        "user", ForeignKey("user.id"), nullable=False
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", foreign_keys=[user_id])  # noqa: F821

    @property
    def content(self) -> str:
        """Alias for `chat` so Pydantic's from_attributes can map to ChatMessageOut.content."""
        return self.chat
