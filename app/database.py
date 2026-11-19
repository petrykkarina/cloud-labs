"""Database connection.

The connection string comes ONLY from the DATABASE_URL environment variable:
  * locally it is built by compose.yaml from the values in .env;
  * in Azure it is a Container App secret created by Terraform.
Nothing secret is stored in the code or in the image.
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

DATABASE_URL = os.environ["DATABASE_URL"]

# pool_pre_ping checks a connection before using it, so the app survives
# database restarts without returning errors to the user.
#
# Pool size matters when the app scales out: Azure PostgreSQL B1ms allows
# 50 connections, 15 of them reserved for Azure, so 35 are left for us.
# 4 replicas x (5 + 2 overflow) = 28 connections at most, safely below 35.
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=2,
    pool_timeout=10,
)
SessionLocal = sessionmaker(bind=engine, autoflush=False)


class Base(DeclarativeBase):
    """Parent class for all ORM models (tables)."""


def get_db():
    """FastAPI dependency: one database session per HTTP request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
