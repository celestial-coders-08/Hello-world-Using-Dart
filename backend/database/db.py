"""
SQLAlchemy database engine and session for PawStay backend.
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# ---------------------------------------------------------------------------
# Database file lives in the backend directory (next to main.py)
# ---------------------------------------------------------------------------
_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATABASE_URL = f"sqlite:///{os.path.join(_BACKEND_DIR, 'pawstay.db')}"

engine = create_engine(
    DATABASE_URL,
    # Let SQLite wait for short concurrent writes instead of failing immediately.
    connect_args={"check_same_thread": False, "timeout": 30},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


# ---------------------------------------------------------------------------
# Dependency — used with FastAPI's Depends()
# ---------------------------------------------------------------------------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
