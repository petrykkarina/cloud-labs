"""CRUD for /posts, the list is paginated with limit/offset."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import cache
from app.database import get_db
from app.models import Author, Post
from app.schemas import PostCreate, PostPage, PostRead, PostUpdate

router = APIRouter(prefix="/posts", tags=["posts"])

DbSession = Annotated[Session, Depends(get_db)]


def get_post_or_404(db: Session, post_id: int) -> Post:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Post not found")
    return post


@router.post("", response_model=PostRead, status_code=status.HTTP_201_CREATED)
def create_post(data: PostCreate, db: DbSession):
    if db.get(Author, data.author_id) is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Author does not exist")
    post = Post(**data.model_dump())
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


@router.get("", response_model=PostPage)
def list_posts(
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
    author_id: int | None = None,
):
    """Newest posts first. Example: /posts?limit=10&offset=20 is page 3.

    The most frequent read, so it goes through the cache (cache-aside).
    Response header X-Cache shows what happened: HIT, MISS or OFF.
    """

    def read_from_database() -> str:
        query = select(Post)
        if author_id is not None:
            query = query.where(Post.author_id == author_id)
        total = db.scalar(select(func.count()).select_from(query.subquery()))
        items = db.scalars(query.order_by(Post.id.desc()).limit(limit).offset(offset)).all()
        page = PostPage(items=items, total=total, limit=limit, offset=offset)
        return page.model_dump_json()

    # One cache entry per distinct page: same parameters -> same key.
    key = f"posts:list:limit={limit}:offset={offset}:author={author_id}"
    body, cache_status = cache.get_or_set(key, read_from_database)
    return Response(body, media_type="application/json", headers={"X-Cache": cache_status})


@router.get("/{post_id}", response_model=PostRead)
def get_post(post_id: int, db: DbSession):
    return get_post_or_404(db, post_id)


@router.put("/{post_id}", response_model=PostRead)
def update_post(post_id: int, data: PostUpdate, db: DbSession):
    post = get_post_or_404(db, post_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(post, field, value)
    db.commit()
    db.refresh(post)
    return post


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(post_id: int, db: DbSession):
    post = get_post_or_404(db, post_id)
    db.delete(post)
    db.commit()
