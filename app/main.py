"""Entry point: creates the FastAPI app, tables and the service endpoints."""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.database import Base, SessionLocal, engine
from app.routers import authors, posts

# Set at image build time (Dockerfile ARG GIT_SHA); the CI pipeline passes the
# commit hash, so "/" shows exactly which commit is running.
APP_VERSION = os.getenv("APP_VERSION", "dev")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Creates missing tables on startup. Simple and enough for this lab;
    # a bigger project would use migrations (Alembic).
    Base.metadata.create_all(engine)
    yield


app = FastAPI(
    title="Blog API",
    description="Authors and posts. Cloud Services lab, Karina Petryk.",
    version=APP_VERSION,
    lifespan=lifespan,
)
app.include_router(authors.router)
app.include_router(posts.router)


@app.get("/", tags=["service"])
def root():
    return {"service": "blog-api", "version": APP_VERSION, "docs": "/docs"}


@app.get("/health", tags=["service"])
def health(response: Response):
    """Used by the load balancer health probe: 200 only if the database answers."""
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "error", "database": "unreachable"}
    return {"status": "ok", "database": "ok"}
