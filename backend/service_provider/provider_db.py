"""Provider-only SQLite storage."""

import os
import sqlite3
from contextlib import contextmanager

DATABASE_PATH = os.path.join(os.path.dirname(__file__), "provider.db")


@contextmanager
def connection():
    db = sqlite3.connect(DATABASE_PATH)
    db.row_factory = sqlite3.Row
    try:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS provider_profiles (
                lookup TEXT PRIMARY KEY,
                walking_charge INTEGER,
                daycare_charge INTEGER,
                daycare_food_charge INTEGER,
                provider_description TEXT,
                is_online INTEGER NOT NULL DEFAULT 1,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        db.commit()
        yield db
    finally:
        db.close()


def get_profile(lookup: str) -> dict:
    with connection() as db:
        row = db.execute(
            "SELECT * FROM provider_profiles WHERE lookup = ?",
            (lookup.strip(),),
        ).fetchone()
        if row is None:
            db.execute(
                "INSERT INTO provider_profiles (lookup) VALUES (?)",
                (lookup.strip(),),
            )
            db.commit()
            return {
                "lookup": lookup.strip(),
                "walking_charge": None,
                "daycare_charge": None,
                "daycare_food_charge": None,
                "provider_description": None,
                "is_online": True,
            }
        return dict(row)


def update_profile(lookup: str, payload: dict) -> dict:
    with connection() as db:
        db.execute(
            """
            INSERT INTO provider_profiles (
                lookup, walking_charge, daycare_charge,
                daycare_food_charge, provider_description, updated_at
            ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(lookup) DO UPDATE SET
                walking_charge = excluded.walking_charge,
                daycare_charge = excluded.daycare_charge,
                daycare_food_charge = excluded.daycare_food_charge,
                provider_description = excluded.provider_description,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                lookup.strip(),
                payload["walking_charge"],
                payload["daycare_charge"],
                payload["daycare_food_charge"],
                payload["provider_description"].strip(),
            ),
        )
        db.commit()
    return get_profile(lookup)


def update_status(lookup: str, is_online: bool) -> None:
    with connection() as db:
        db.execute(
            """
            INSERT INTO provider_profiles (lookup, is_online)
            VALUES (?, ?)
            ON CONFLICT(lookup) DO UPDATE SET
                is_online = excluded.is_online,
                updated_at = CURRENT_TIMESTAMP
            """,
            (lookup.strip(), int(is_online)),
        )
        db.commit()
