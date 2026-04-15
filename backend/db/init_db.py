def init_db() -> None:
    import models  # noqa: F401 — register ORM modules via import side effects
    from models.conversation import Conversation  # noqa: F401

    from db.base import Base
    from db.session import engine

    Base.metadata.create_all(bind=engine)

    # Migrations for existing tables
    from sqlalchemy import text
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE chatHistory ADD COLUMN conversation_id TEXT"))
            conn.commit()
        except Exception:
            pass  # column already exists
        try:
            conn.execute(text("ALTER TABLE user ADD COLUMN language TEXT DEFAULT 'en'"))
            conn.commit()
        except Exception:
            pass  # column already exists
