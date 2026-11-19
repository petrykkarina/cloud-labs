"""CRUD for /authors."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Author
from app.schemas import AuthorCreate, AuthorRead, AuthorUpdate

router = APIRouter(prefix="/authors", tags=["authors"])

DbSession = Annotated[Session, Depends(get_db)]


def get_author_or_404(db: Session, author_id: int) -> Author:
    author = db.get(Author, author_id)
    if author is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Author not found")
    return author


def save(db: Session, author: Author) -> Author:
    """Commit and turn a duplicate email into a clear 409 error."""
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already exists")
    db.refresh(author)
    return author


@router.post("", response_model=AuthorRead, status_code=status.HTTP_201_CREATED)
def create_author(data: AuthorCreate, db: DbSession):
    author = Author(**data.model_dump())
    db.add(author)
    return save(db, author)


@router.get("", response_model=list[AuthorRead])
def list_authors(
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    query = select(Author).order_by(Author.id).limit(limit).offset(offset)
    return db.scalars(query).all()


@router.get("/{author_id}", response_model=AuthorRead)
def get_author(author_id: int, db: DbSession):
    return get_author_or_404(db, author_id)


@router.put("/{author_id}", response_model=AuthorRead)
def update_author(author_id: int, data: AuthorUpdate, db: DbSession):
    author = get_author_or_404(db, author_id)
    # exclude_unset: change only the fields the client actually sent
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(author, field, value)
    return save(db, author)


@router.delete("/{author_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_author(author_id: int, db: DbSession):
    author = get_author_or_404(db, author_id)
    db.delete(author)
    db.commit()
