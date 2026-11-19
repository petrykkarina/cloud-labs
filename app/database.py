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
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
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
