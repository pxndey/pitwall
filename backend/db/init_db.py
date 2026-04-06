def init_db() -> None:
    import models  # noqa: F401 — register ORM modules via import side effects

    from db.base import Base
    from db.session import engine

    Base.metadata.create_all(bind=engine)
