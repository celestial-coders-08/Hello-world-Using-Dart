"""
SQLAlchemy Database setup for PawStay Message Service.
Uses SQLite (messages.db) — independent from the main PawStay backend.
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# messages.db lives in backend/messages/ directory
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "messages.db")
DB_PATH = os.path.normpath(DB_PATH)

SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False, "timeout": 30},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
