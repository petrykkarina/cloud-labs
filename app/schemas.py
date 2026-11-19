"""Pydantic schemas: what the API accepts (…Create/…Update) and returns (…Read).

They are separate from the ORM models so the API shape does not have to
match the table shape one to one.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

EMAIL_PATTERN = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"


# ---------- Authors ----------

class AuthorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: str = Field(pattern=EMAIL_PATTERN, max_length=255)
    bio: str | None = None


class AuthorUpdate(BaseModel):
    """All fields optional: only the fields sent by the client are changed."""

    name: str | None = Field(default=None, min_length=1, max_length=100)
    email: str | None = Field(default=None, pattern=EMAIL_PATTERN, max_length=255)
    bio: str | None = None


class AuthorShort(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class AuthorRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str
    bio: str | None
    created_at: datetime
    posts_count: int = 0


# ---------- Posts ----------

class PostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    author_id: int


class PostUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    content: str | None = Field(default=None, min_length=1)


class PostRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    content: str
    created_at: datetime
    author: AuthorShort


class PostPage(BaseModel):
    """One page of posts plus the info needed to request the next page."""

    items: list[PostRead]
    total: int
    limit: int
    offset: int
