"""Entry point: creates the FastAPI app, tables and the service endpoints."""

import json
import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app import cache
from app.database import Base, SessionLocal, engine
from app.routers import authors, posts

# Plain stdout logging. Container Apps ships stdout to Log Analytics
# (table ContainerAppConsoleLogs_CL), where the dashboard reads it.
logging.basicConfig(level=logging.INFO, format="%(message)s")
request_logger = logging.getLogger("app.requests")

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


@app.middleware("http")
async def log_request(request: Request, call_next):
    """One JSON line per request with its duration.

    Azure Monitor metrics give only average response time, so the p95 latency
    on the dashboard is calculated from these lines with a KQL query.
    """
    started = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    request_logger.info(json.dumps({
        "type": "request",
        "method": request.method,
        # route template (/posts/{post_id}) instead of the real path keeps groups small
        "path": route.path if route else request.url.path,
        "status": response.status_code,
        "duration_ms": round((time.perf_counter() - started) * 1000, 1),
        "cache": response.headers.get("x-cache"),
    }))
    return response


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
        return {"status": "error", "database": "unreachable", "version": APP_VERSION}
    return {"status": "ok", "database": "ok", "version": APP_VERSION}


@app.get("/cache/stats", tags=["service"])
def cache_stats():
    """Cache hit/miss counters shared by all replicas (stored in Redis)."""
    return cache.stats()


@app.post("/cache/stats/reset", tags=["service"], status_code=status.HTTP_204_NO_CONTENT)
def cache_stats_reset():
    """Reset counters before a load test run."""
    cache.reset_stats()
