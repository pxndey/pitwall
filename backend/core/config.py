from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "F1 Pitwall API"
    version: str = "0.1.0"
    database_url: str = "sqlite:///./app.db"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 60 * 24 * 7  # 1 week

    # IBM watsonx.ai
    watsonx_api_key: str = ""
    watsonx_project_id: str = ""
    watsonx_url: str = "https://us-south.ml.cloud.ibm.com"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
