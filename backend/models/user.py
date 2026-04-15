import uuid

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from db.base import Base


class User(Base):
    __tablename__ = "user"

    username: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    id: Mapped[uuid.UUID] = mapped_column(default=uuid.uuid4, unique=True, index=True)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password: Mapped[str] = mapped_column(String, nullable=False)  # store bcrypt hash
    fav_driver: Mapped[str | None] = mapped_column("favDriver", String, nullable=True)
    fav_team: Mapped[str | None] = mapped_column("favTeam", String, nullable=True)
    language: Mapped[str] = mapped_column(String(10), nullable=False, server_default="en")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
