import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class UserCreate(BaseModel):
    username: str
    name: Optional[str] = None
    email: str
    password: str
    fav_driver: Optional[str] = None
    fav_team: Optional[str] = None
    language: Optional[str] = None


class UserLogin(BaseModel):
    username: str
    password: str


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    fav_driver: Optional[str] = None
    fav_team: Optional[str] = None
    language: Optional[str] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    username: str
    name: Optional[str] = None
    id: uuid.UUID
    email: str
    fav_driver: Optional[str] = None
    fav_team: Optional[str] = None
    language: str = "en"
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
