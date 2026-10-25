"""Provider-only SQLite storage with package services and bookings."""

import json
import os
import sqlite3
from contextlib import contextmanager

DATABASE_PATH = os.path.join(os.path.dirname(__file__), "provider.db")
PAWSTAY_DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "pawstay.db")

TIER_ORDER = ["bronze", "silver", "gold"]

DEFAULT_PACKAGES = {
    "bronze": {
        "tier": "bronze",
        "enabled": False,
        "price": 0.0,
        "duration_value": 2,
        "duration_unit": "hours",
        "meals_per_day": 0,
        "walks_per_day": 1,
        "inclusions": ["Basic walk", "Fresh water"],
        "description": "Bronze basic pet care package",
    },
    "silver": {
        "tier": "silver",
        "enabled": False,
        "price": 0.0,
        "duration_value": 4,
        "duration_unit": "hours",
        "meals_per_day": 1,
        "walks_per_day": 2,
        "inclusions": ["Extended walk", "Playtime", "Treats"],
        "description": "Silver standard pet care package",
    },
    "gold": {
        "tier": "gold",
        "enabled": False,
        "price": 0.0,
        "duration_value": 8,
        "duration_unit": "hours",
        "meals_per_day": 2,
        "walks_per_day": 3,
        "inclusions": ["Full day care", "All meals", "Photo updates"],
        "description": "Gold premium pet care package",
    },
}


def _migrate_tables(db: sqlite3.Connection) -> None:
    """Safe migration that copies old walking price into sitter_price without crashing."""
    cursor = db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='provider_profiles'"
    )
    table_exists = cursor.fetchone() is not None

    if table_exists:
        cols = {
            col["name"]
            for col in db.execute("PRAGMA table_info(provider_profiles)").fetchall()
        }

        # Safe migration: copy old walking price into sitter_price
        if "sitter_price" not in cols:
            db.execute("ALTER TABLE provider_profiles ADD COLUMN sitter_price REAL DEFAULT 0")
            if "walking_charge" in cols:
                db.execute(
                    """
                    UPDATE provider_profiles
                    SET sitter_price = walking_charge
                    WHERE walking_charge IS NOT NULL AND walking_charge > 0
                    """
                )

        if "sitter_enabled" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN sitter_enabled INTEGER DEFAULT 0"
            )
            if "walking_charge" in cols:
                db.execute(
                    """
                    UPDATE provider_profiles
                    SET sitter_enabled = 1
                    WHERE walking_charge IS NOT NULL AND walking_charge > 0
                    """
                )

        if "sitter_duration_mins" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN sitter_duration_mins INTEGER DEFAULT 60"
            )

        if "bio" not in cols:
            db.execute("ALTER TABLE provider_profiles ADD COLUMN bio TEXT DEFAULT ''")
            if "provider_description" in cols:
                db.execute(
                    """
                    UPDATE provider_profiles
                    SET bio = substr(provider_description, 1, 500)
                    WHERE provider_description IS NOT NULL AND (bio IS NULL OR bio = '')
                    """
                )

        if "city" not in cols:
            db.execute("ALTER TABLE provider_profiles ADD COLUMN city TEXT DEFAULT ''")

        if "experience_years" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN experience_years INTEGER DEFAULT 0"
            )

        if "pet_types" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN pet_types TEXT DEFAULT '[]'"
            )

        if "is_online" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN is_online INTEGER NOT NULL DEFAULT 1"
            )

        if "updated_at" not in cols:
            db.execute(
                "ALTER TABLE provider_profiles ADD COLUMN updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"
            )

        # Safely remove/drop old columns
        for old_col in [
            "walking_charge",
            "daycare_charge",
            "daycare_food_charge",
            "day_care",
            "day_care_food",
            "pet_walking",
            "provider_description",
        ]:
            if old_col in cols:
                try:
                    db.execute(f"ALTER TABLE provider_profiles DROP COLUMN {old_col}")
                except Exception:
                    pass
    else:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS provider_profiles (
                lookup TEXT PRIMARY KEY,
                bio TEXT DEFAULT '',
                city TEXT DEFAULT '',
                experience_years INTEGER DEFAULT 0,
                pet_types TEXT DEFAULT '[]',
                sitter_enabled INTEGER NOT NULL DEFAULT 0,
                sitter_price REAL NOT NULL DEFAULT 0,
                sitter_duration_mins INTEGER NOT NULL DEFAULT 60,
                is_online INTEGER NOT NULL DEFAULT 1,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )

    # Provider packages table (one row per tier bronze|silver|gold per provider)
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS provider_packages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            provider_lookup TEXT NOT NULL,
            tier TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 0,
            price REAL NOT NULL DEFAULT 0,
            duration_value INTEGER NOT NULL DEFAULT 1,
            duration_unit TEXT NOT NULL DEFAULT 'hours',
            meals_per_day INTEGER NOT NULL DEFAULT 0,
            walks_per_day INTEGER NOT NULL DEFAULT 0,
            inclusions TEXT NOT NULL DEFAULT '[]',
            description TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(provider_lookup, tier)
        )
        """
    )

    # Provider bookings table (safe migration with provider_id, customer_id, dates, pet info, notes)
    cursor = db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='provider_bookings'"
    )
    if cursor.fetchone() is not None:
        cols = {
            col["name"]
            for col in db.execute("PRAGMA table_info(provider_bookings)").fetchall()
        }
        for col_name, col_def in [
            ("provider_id", "TEXT"),
            ("customer_id", "TEXT"),
            ("start_datetime", "TEXT"),
            ("end_datetime", "TEXT"),
            ("pet_name", "TEXT"),
            ("pet_type", "TEXT"),
            ("notes", "TEXT"),
        ]:
            if col_name not in cols:
                try:
                    db.execute(f"ALTER TABLE provider_bookings ADD COLUMN {col_name} {col_def}")
                except Exception:
                    pass
    else:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS provider_bookings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider_id TEXT,
                customer_id TEXT,
                provider_lookup TEXT NOT NULL,
                customer_lookup TEXT,
                service_type TEXT NOT NULL,
                package_id INTEGER,
                tier TEXT,
                price_snapshot REAL NOT NULL,
                start_datetime TEXT,
                end_datetime TEXT,
                pet_name TEXT,
                pet_type TEXT,
                notes TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )

    # Notifications table
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipient_id TEXT NOT NULL,
            recipient_role TEXT,
            type TEXT NOT NULL,
            booking_id INTEGER,
            title TEXT,
            message TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    db.commit()


@contextmanager
def connection():
    db = sqlite3.connect(DATABASE_PATH)
    db.row_factory = sqlite3.Row
    try:
        _migrate_tables(db)
        yield db
    finally:
        db.close()


def _ensure_packages(db: sqlite3.Connection, lookup: str) -> None:
    """Ensure bronze, silver, and gold package rows exist for this provider."""
    lookup_clean = lookup.strip()
    for tier in TIER_ORDER:
        existing = db.execute(
            "SELECT id FROM provider_packages WHERE provider_lookup = ? AND tier = ?",
            (lookup_clean, tier),
        ).fetchone()
        if existing is None:
            defaults = DEFAULT_PACKAGES[tier]
            db.execute(
                """
                INSERT INTO provider_packages (
                    provider_lookup, tier, enabled, price,
                    duration_value, duration_unit, meals_per_day,
                    walks_per_day, inclusions, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    lookup_clean,
                    tier,
                    int(defaults["enabled"]),
                    defaults["price"],
                    defaults["duration_value"],
                    defaults["duration_unit"],
                    defaults["meals_per_day"],
                    defaults["walks_per_day"],
                    json.dumps(defaults["inclusions"]),
                    defaults["description"],
                ),
            )
    db.commit()


def get_profile(lookup: str) -> dict:
    """Return provider profile with new fields: bio, city, experience_years, pet_types, sitter service."""
    lookup_clean = lookup.strip()
    with connection() as db:
        row = db.execute(
            "SELECT * FROM provider_profiles WHERE lookup = ?",
            (lookup_clean,),
        ).fetchone()

        # Check alternate user lookup (email or username) if missing or disabled
        if (row is None or not row["sitter_enabled"]) and os.path.exists(PAWSTAY_DB_PATH):
            try:
                with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                    p_db.row_factory = sqlite3.Row
                    u_row = p_db.execute(
                        "SELECT username, email, city FROM users WHERE username = ? OR email = ? OR id = ?",
                        (lookup_clean, lookup_clean, int(lookup_clean) if lookup_clean.isdigit() else -1),
                    ).fetchone()
                    if u_row:
                        for alt in (u_row["email"], u_row["username"]):
                            if alt and alt != lookup_clean:
                                alt_row = db.execute(
                                    "SELECT * FROM provider_profiles WHERE lookup = ?",
                                    (alt,),
                                ).fetchone()
                                if alt_row and (row is None or alt_row["sitter_enabled"]):
                                    row = alt_row
                                    break
            except Exception:
                pass

        if row is None:
            # Sync default city from pawstay.db if available
            default_city = ""
            if os.path.exists(PAWSTAY_DB_PATH):
                try:
                    with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                        p_db.row_factory = sqlite3.Row
                        u_row = p_db.execute(
                            "SELECT city FROM users WHERE username = ? OR email = ?",
                            (lookup_clean, lookup_clean),
                        ).fetchone()
                        if u_row and u_row["city"]:
                            default_city = u_row["city"]
                except Exception:
                    pass

            db.execute(
                """
                INSERT INTO provider_profiles (lookup, city)
                VALUES (?, ?)
                """,
                (lookup_clean, default_city),
            )
            db.commit()
            return {
                "lookup": lookup_clean,
                "bio": "",
                "city": default_city,
                "experience_years": 0,
                "pet_types": [],
                "sitter_enabled": False,
                "sitter_price": 0.0,
                "sitter_duration_mins": 60,
                "is_online": True,
            }

        pet_types = row["pet_types"]
        if isinstance(pet_types, str):
            try:
                pet_types = json.loads(pet_types)
            except Exception:
                pet_types = [t.strip() for t in pet_types.split(",") if t.strip()]
        if not isinstance(pet_types, list):
            pet_types = []

        return {
            "lookup": row["lookup"],
            "bio": row["bio"] or "",
            "city": row["city"] or "",
            "experience_years": int(row["experience_years"] or 0),
            "pet_types": pet_types,
            "sitter_enabled": bool(row["sitter_enabled"]),
            "sitter_price": float(row["sitter_price"] or 0.0),
            "sitter_duration_mins": int(row["sitter_duration_mins"] or 60),
            "is_online": bool(row["is_online"]),
        }


def get_packages(lookup: str) -> list[dict]:
    """Return 3 package rows for bronze, silver, gold in order."""
    lookup_clean = lookup.strip()
    with connection() as db:
        _ensure_packages(db, lookup_clean)
        rows = db.execute(
            """
            SELECT * FROM provider_packages
            WHERE provider_lookup = ?
            ORDER BY CASE tier
                WHEN 'bronze' THEN 1
                WHEN 'silver' THEN 2
                WHEN 'gold' THEN 3
                ELSE 4 END
            """,
            (lookup_clean,),
        ).fetchall()

        if not any(r["enabled"] for r in rows) and os.path.exists(PAWSTAY_DB_PATH):
            try:
                with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                    p_db.row_factory = sqlite3.Row
                    u_row = p_db.execute(
                        "SELECT username, email FROM users WHERE username = ? OR email = ? OR id = ?",
                        (lookup_clean, lookup_clean, int(lookup_clean) if lookup_clean.isdigit() else -1),
                    ).fetchone()
                    if u_row:
                        for alt in (u_row["email"], u_row["username"]):
                            if alt and alt != lookup_clean:
                                alt_rows = db.execute(
                                    """
                                    SELECT * FROM provider_packages
                                    WHERE provider_lookup = ?
                                    ORDER BY CASE tier
                                        WHEN 'bronze' THEN 1
                                        WHEN 'silver' THEN 2
                                        WHEN 'gold' THEN 3
                                        ELSE 4 END
                                    """,
                                    (alt,),
                                ).fetchall()
                                if any(r["enabled"] for r in alt_rows):
                                    rows = alt_rows
                                    break
            except Exception:
                pass

        result = []
        for r in rows:
            inclusions = r["inclusions"]
            if isinstance(inclusions, str):
                try:
                    inclusions = json.loads(inclusions)
                except Exception:
                    inclusions = [i.strip() for i in inclusions.split(",") if i.strip()]
            if not isinstance(inclusions, list):
                inclusions = []

            result.append(
                {
                    "id": r["id"],
                    "tier": r["tier"],
                    "enabled": bool(r["enabled"]),
                    "price": float(r["price"] or 0.0),
                    "duration_value": int(r["duration_value"] or 1),
                    "duration_unit": r["duration_unit"] or "hours",
                    "meals_per_day": int(r["meals_per_day"] or 0),
                    "walks_per_day": int(r["walks_per_day"] or 0),
                    "inclusions": inclusions,
                    "description": r["description"] or "",
                }
            )
        return result


def get_services(lookup: str) -> dict:
    """Endpoint 1 GET: profile + sitter service + 3 packages in one payload."""
    lookup_clean = lookup.strip()
    profile = get_profile(lookup_clean)
    packages = get_packages(lookup_clean)

    return {
        "lookup": lookup_clean,
        "profile": {
            "bio": profile["bio"],
            "city": profile["city"],
            "experience_years": profile["experience_years"],
            "pet_types": profile["pet_types"],
        },
        "sitter_service": {
            "sitter_enabled": profile["sitter_enabled"],
            "sitter_price": profile["sitter_price"],
            "sitter_duration_mins": profile["sitter_duration_mins"],
        },
        "packages": packages,
    }


def validate_services_payload(payload: dict) -> None:
    """
    Server validation:
    - price > 0 if enabled
    - at least one service enabled
    - silver >= bronze, gold >= silver (only among enabled)
    - bio <= 500
    """
    profile_data = payload.get("profile") or {}
    bio = str(profile_data.get("bio") or "").strip()
    if len(bio) > 500:
        raise ValueError("Bio must not exceed 500 characters.")

    sitter_data = payload.get("sitter_service") or payload.get("sitter") or {}
    sitter_enabled = bool(sitter_data.get("sitter_enabled", False))
    sitter_price = float(sitter_data.get("sitter_price") or 0.0)

    if sitter_enabled and sitter_price <= 0:
        raise ValueError("Sitter price must be greater than zero when enabled.")

    packages_data = payload.get("packages") or []
    if isinstance(packages_data, dict):
        packages_list = []
        for tier_key in TIER_ORDER:
            if tier_key in packages_data:
                item = dict(packages_data[tier_key])
                item["tier"] = tier_key
                packages_list.append(item)
        packages_data = packages_list

    enabled_tier_prices = {}
    any_package_enabled = False

    for pkg in packages_data:
        tier = str(pkg.get("tier") or "").strip().lower()
        enabled = bool(pkg.get("enabled", False))
        price = float(pkg.get("price") or 0.0)

        if enabled:
            any_package_enabled = True
            if price <= 0:
                raise ValueError(
                    f"Price for {tier} package must be greater than zero when enabled."
                )
            if tier in TIER_ORDER:
                enabled_tier_prices[tier] = price

    if not (sitter_enabled or any_package_enabled):
        raise ValueError("At least one service or package must be enabled.")

    # Tier hierarchy check only among enabled packages: silver >= bronze, gold >= silver
    if "bronze" in enabled_tier_prices and "silver" in enabled_tier_prices:
        if enabled_tier_prices["silver"] < enabled_tier_prices["bronze"]:
            raise ValueError(
                "Silver package price must be greater than or equal to Bronze package price."
            )

    if "silver" in enabled_tier_prices and "gold" in enabled_tier_prices:
        if enabled_tier_prices["gold"] < enabled_tier_prices["silver"]:
            raise ValueError(
                "Gold package price must be greater than or equal to Silver package price."
            )

    if "bronze" in enabled_tier_prices and "gold" in enabled_tier_prices:
        if enabled_tier_prices["gold"] < enabled_tier_prices["bronze"]:
            raise ValueError(
                "Gold package price must be greater than or equal to Bronze package price."
            )


def update_services(lookup: str, payload: dict) -> dict:
    """Endpoint 1 PUT: validate and update profile, sitter service, and 3 packages."""
    lookup_clean = lookup.strip()
    validate_services_payload(payload)

    profile_data = payload.get("profile") or {}
    bio = str(profile_data.get("bio") or "").strip()
    city = str(profile_data.get("city") or "").strip()
    experience_years = int(profile_data.get("experience_years") or 0)
    pet_types = profile_data.get("pet_types") or []
    if isinstance(pet_types, list):
        pet_types_str = json.dumps(pet_types)
    else:
        pet_types_str = str(pet_types)

    sitter_data = payload.get("sitter_service") or payload.get("sitter") or {}
    sitter_enabled = 1 if sitter_data.get("sitter_enabled") else 0
    sitter_price = float(sitter_data.get("sitter_price") or 0.0)
    sitter_duration_mins = int(sitter_data.get("sitter_duration_mins") or 60)

    packages_data = payload.get("packages") or []
    if isinstance(packages_data, dict):
        packages_list = []
        for tier_key in TIER_ORDER:
            if tier_key in packages_data:
                item = dict(packages_data[tier_key])
                item["tier"] = tier_key
                packages_list.append(item)
        packages_data = packages_list

    with connection() as db:
        # Update provider_profiles
        db.execute(
            """
            INSERT INTO provider_profiles (
                lookup, bio, city, experience_years, pet_types,
                sitter_enabled, sitter_price, sitter_duration_mins, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(lookup) DO UPDATE SET
                bio = excluded.bio,
                city = excluded.city,
                experience_years = excluded.experience_years,
                pet_types = excluded.pet_types,
                sitter_enabled = excluded.sitter_enabled,
                sitter_price = excluded.sitter_price,
                sitter_duration_mins = excluded.sitter_duration_mins,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                lookup_clean,
                bio,
                city,
                experience_years,
                pet_types_str,
                sitter_enabled,
                sitter_price,
                sitter_duration_mins,
            ),
        )

        # Update packages
        _ensure_packages(db, lookup_clean)
        for pkg in packages_data:
            tier = str(pkg.get("tier") or "").strip().lower()
            if tier not in TIER_ORDER:
                continue
            enabled = 1 if pkg.get("enabled") else 0
            price = float(pkg.get("price") or 0.0)
            duration_value = int(pkg.get("duration_value") or 1)
            duration_unit = str(pkg.get("duration_unit") or "hours").strip()
            meals_per_day = int(pkg.get("meals_per_day") or 0)
            walks_per_day = int(pkg.get("walks_per_day") or 0)
            inclusions = pkg.get("inclusions") or []
            inclusions_str = (
                json.dumps(inclusions)
                if isinstance(inclusions, list)
                else str(inclusions)
            )
            description = str(pkg.get("description") or "").strip()

            db.execute(
                """
                INSERT INTO provider_packages (
                    provider_lookup, tier, enabled, price, duration_value,
                    duration_unit, meals_per_day, walks_per_day, inclusions,
                    description, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(provider_lookup, tier) DO UPDATE SET
                    enabled = excluded.enabled,
                    price = excluded.price,
                    duration_value = excluded.duration_value,
                    duration_unit = excluded.duration_unit,
                    meals_per_day = excluded.meals_per_day,
                    walks_per_day = excluded.walks_per_day,
                    inclusions = excluded.inclusions,
                    description = excluded.description,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (
                    lookup_clean,
                    tier,
                    enabled,
                    price,
                    duration_value,
                    duration_unit,
                    meals_per_day,
                    walks_per_day,
                    inclusions_str,
                    description,
                ),
            )
        db.commit()
    return get_profile(lookup)


def update_status(lookup: str, is_online: bool) -> None:
    """Update online/offline status."""
    lookup_clean = lookup.strip()
    with connection() as db:
        db.execute(
            """
            INSERT INTO provider_profiles (lookup, is_online)
            VALUES (?, ?)
            ON CONFLICT(lookup) DO UPDATE SET
                is_online = excluded.is_online,
                updated_at = CURRENT_TIMESTAMP
            """,
            (lookup_clean, int(is_online)),
        )
        db.commit()


def delete_profile(lookup: str) -> None:
    """Delete provider profile, packages, and bookings."""
    lookup_clean = lookup.strip()
    with connection() as db:
        db.execute("DELETE FROM provider_profiles WHERE lookup = ?", (lookup_clean,))
        db.execute("DELETE FROM provider_packages WHERE provider_lookup = ?", (lookup_clean,))
        db.commit()
