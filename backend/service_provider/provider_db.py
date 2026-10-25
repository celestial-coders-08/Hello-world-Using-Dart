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

    # Also keep pawstay.db users table in sync if user exists
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.execute(
                    """
                    UPDATE users
                    SET bio = ?, city = COALESCE(NULLIF(?, ''), city),
                        experience_years = ?, pet_types = ?,
                        sitter_enabled = ?, sitter_price = ?, sitter_duration_mins = ?
                    WHERE username = ? OR email = ?
                    """,
                    (
                        bio,
                        city,
                        experience_years,
                        pet_types_str,
                        sitter_enabled,
                        sitter_price,
                        sitter_duration_mins,
                        lookup_clean,
                        lookup_clean,
                    ),
                )
                p_db.commit()
        except Exception:
            pass

    return get_services(lookup_clean)


def get_real_reviews_stats(lookup: str) -> tuple[float | None, int]:
    """Compute rating and review_count from real reviews. Returns (None, 0) if no reviews."""
    lookup_clean = lookup.strip()
    if not os.path.exists(PAWSTAY_DB_PATH):
        return None, 0

    try:
        with sqlite3.connect(PAWSTAY_DB_PATH) as db:
            db.row_factory = sqlite3.Row
            # Check user username/email to match all associated reviews
            matched_lookups = [lookup_clean]
            u_row = db.execute(
                "SELECT username, email FROM users WHERE username = ? OR email = ?",
                (lookup_clean, lookup_clean),
            ).fetchone()
            if u_row:
                if u_row["username"] and u_row["username"] not in matched_lookups:
                    matched_lookups.append(u_row["username"])
                if u_row["email"] and u_row["email"] not in matched_lookups:
                    matched_lookups.append(u_row["email"])

            placeholders = ",".join("?" for _ in matched_lookups)
            res = db.execute(
                f"""
                SELECT AVG(rating) AS avg_rating, COUNT(id) AS review_count
                FROM reviews
                WHERE provider_lookup IN ({placeholders})
                """,
                matched_lookups,
            ).fetchone()

            if res and res["review_count"] and res["review_count"] > 0:
                avg = (
                    round(float(res["avg_rating"]), 1)
                    if res["avg_rating"] is not None
                    else None
                )
                count = int(res["review_count"])
                return avg, count
    except Exception:
        pass
    return None, 0


def get_customer_display_name(lookup: str) -> str:
    """Safely resolve customer display name. Never return email or phone number."""
    clean = (lookup or "").strip()
    if not clean:
        return "Customer"
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                u_row = p_db.execute(
                    "SELECT full_name, username FROM users WHERE username = ? OR email = ? OR id = ?",
                    (clean, clean, int(clean) if clean.isdigit() else -1),
                ).fetchone()
                if u_row:
                    for key in ("full_name", "name"):
                        if key in u_row.keys():
                            val = u_row[key]
                            if val and str(val).strip() and "@" not in str(val):
                                return str(val).strip()
                    if "username" in u_row.keys() and u_row["username"]:
                        val = str(u_row["username"]).strip()
                        if val and "@" not in val:
                            return val
        except Exception:
            pass
    prefix = clean.split("@")[0].strip() if "@" in clean else clean
    return prefix.capitalize() if prefix else "Customer"


def _format_booking_for_provider(row: sqlite3.Row | dict) -> dict:
    service_type = (row["service_type"] or "").lower()
    tier = row["tier"] if "tier" in row.keys() else None
    if service_type == "package" and tier:
        service_name = f"{str(tier).capitalize()} Package"
    elif service_type == "package":
        service_name = "Package Service"
    else:
        service_name = "Pet Sitter"

    customer_id = (
        row["customer_id"]
        if "customer_id" in row.keys() and row["customer_id"]
        else row["customer_lookup"]
    ) or ""
    customer_name = get_customer_display_name(str(customer_id))
    provider_id = (
        row["provider_id"]
        if "provider_id" in row.keys() and row["provider_id"]
        else row["provider_lookup"]
    ) or ""

    return {
        "id": int(row["id"]),
        "provider_id": str(provider_id),
        "customer_id": str(customer_id),
        "customer_name": customer_name,  # Never email, never phone
        "service_type": service_type,
        "package_id": row["package_id"] if "package_id" in row.keys() else None,
        "tier": tier,
        "service_name": service_name,
        "price_snapshot": float(row["price_snapshot"] or 0.0),
        "start_datetime": row["start_datetime"] if "start_datetime" in row.keys() else None,
        "end_datetime": row["end_datetime"] if "end_datetime" in row.keys() else None,
        "pet_name": (row["pet_name"] if "pet_name" in row.keys() and row["pet_name"] else "Pet"),
        "pet_type": (row["pet_type"] if "pet_type" in row.keys() and row["pet_type"] else "Dog"),
        "notes": (row["notes"] if "notes" in row.keys() and row["notes"] else ""),
        "status": (row["status"] or "pending").lower(),
        "created_at": str(row["created_at"]),
    }


def _resolve_canonical_provider_lookup(p_lookup: str) -> str:
    """
    Resolve the canonical lookup key that is actually stored in provider_profiles.
    The customer app may send a numeric id or username; we must map it to whatever
    key the provider registered under so that list_provider_bookings finds it.
    """
    clean = p_lookup.strip()
    # Already stored directly? Check provider.db first.
    with sqlite3.connect(DATABASE_PATH) as db:
        db.row_factory = sqlite3.Row
        row = db.execute(
            "SELECT lookup FROM provider_profiles WHERE lookup = ?", (clean,)
        ).fetchone()
        if row:
            return clean  # exact match — use as-is

    # Not found directly; try resolving via pawstay.db
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                u_row = p_db.execute(
                    "SELECT username, email FROM users WHERE username = ? OR email = ? OR id = ?",
                    (clean, clean, int(clean) if clean.isdigit() else -1),
                ).fetchone()
                if u_row:
                    # Try each alt lookup against provider_profiles
                    for alt in (u_row["username"], u_row["email"]):
                        if not alt:
                            continue
                        with sqlite3.connect(DATABASE_PATH) as db2:
                            db2.row_factory = sqlite3.Row
                            alt_row = db2.execute(
                                "SELECT lookup FROM provider_profiles WHERE lookup = ?", (alt,)
                            ).fetchone()
                            if alt_row:
                                print(f"[DEBUG create_booking] normalized provider {clean!r} -> {alt!r}")
                                return alt
        except Exception as ex:
            print(f"[DEBUG create_booking] lookup normalization error: {ex}")

    # Fall back to the original value
    return clean


def create_booking(
    provider_lookup: str,
    service_type: str,
    package_id: int | None = None,
    tier: str | None = None,
    price: float | None = None,
    customer_lookup: str | None = None,
    start_datetime: str | None = None,
    end_datetime: str | None = None,
    pet_name: str | None = None,
    pet_type: str | None = None,
    notes: str | None = None,
    provider_id: str | None = None,
    customer_id: str | None = None,
) -> dict:
    """Store booking with package_id + price_snapshot after validating service is enabled, status=pending."""
    p_lookup_raw = (provider_id or provider_lookup or "").strip()
    c_lookup = (customer_id or customer_lookup or "").strip()
    service_clean = service_type.strip().lower()

    if not p_lookup_raw:
        raise ValueError("Provider lookup/ID is required.")
    if not c_lookup:
        raise ValueError("Customer lookup/ID is required.")

    # Normalize to the canonical key in provider_profiles
    p_lookup = _resolve_canonical_provider_lookup(p_lookup_raw)
    print(f"[DEBUG create_booking] provider={p_lookup!r} customer={c_lookup!r} service={service_clean!r}")

    prof = get_profile(p_lookup)
    price_snapshot = 0.0
    final_package_id = package_id
    final_tier = tier

    with connection() as db:
        if service_clean == "package":
            if final_package_id is not None:
                pkg_row = db.execute(
                    "SELECT * FROM provider_packages WHERE id = ?",
                    (final_package_id,),
                ).fetchone()
                # fallback: id may belong to a different lookup; try by tier + lookup
                if not pkg_row and final_tier:
                    pkg_row = db.execute(
                        "SELECT * FROM provider_packages WHERE provider_lookup = ? AND tier = ?",
                        (p_lookup, final_tier.lower()),
                    ).fetchone()
            elif final_tier is not None:

                pkg_row = db.execute(
                    "SELECT * FROM provider_packages WHERE provider_lookup = ? AND tier = ?",
                    (p_lookup, final_tier.lower()),
                ).fetchone()
            else:
                pkg_row = None

            if not pkg_row or not pkg_row["enabled"]:
                raise ValueError("Selected package is not currently enabled for this provider.")

            final_package_id = pkg_row["id"]
            final_tier = pkg_row["tier"]
            price_snapshot = float(pkg_row["price"] or 0.0)
            if price is not None and float(price) > 0:
                price_snapshot = float(price)
        else:
            # Sitter booking
            if not prof.get("sitter_enabled"):
                raise ValueError("Pet Sitter service is not currently enabled for this provider.")
            price_snapshot = float(prof.get("sitter_price") or 0.0)
            if price is not None and float(price) > 0:
                price_snapshot = float(price)
            final_package_id = None
            final_tier = None

        cursor = db.execute(
            """
            INSERT INTO provider_bookings (
                provider_id, customer_id, provider_lookup, customer_lookup,
                service_type, package_id, tier, price_snapshot,
                start_datetime, end_datetime, pet_name, pet_type, notes,
                status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
            """,
            (
                p_lookup,
                c_lookup,
                p_lookup,
                c_lookup,
                service_clean,
                final_package_id,
                final_tier,
                price_snapshot,
                start_datetime,
                end_datetime,
                (pet_name or "Pet").strip(),
                (pet_type or "Dog").strip(),
                (notes or "").strip(),
            ),
        )
        db.commit()
        booking_id = cursor.lastrowid

    # Also record in pawstay.db bookings table if available
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.execute(
                    """
                    INSERT INTO bookings (
                        provider_id, customer_id, provider_lookup, customer_lookup,
                        service_type, package_id, tier, price_snapshot,
                        start_datetime, end_datetime, pet_name, pet_type, notes,
                        status, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', CURRENT_TIMESTAMP)
                    """,
                    (
                        p_lookup,
                        c_lookup,
                        p_lookup,
                        c_lookup,
                        service_clean,
                        final_package_id,
                        final_tier,
                        price_snapshot,
                        start_datetime,
                        end_datetime,
                        (pet_name or "Pet").strip(),
                        (pet_type or "Dog").strip(),
                        (notes or "").strip(),
                    ),
                )
                p_db.commit()
        except Exception:
            pass

    # Create notification for the provider
    cust_display = get_customer_display_name(c_lookup)
    add_notification(
        recipient_id=p_lookup,
        recipient_role="provider",
        type="new_booking",
        booking_id=booking_id,
        title="New Booking Request",
        message=f"New booking request from {cust_display}",
    )

    return {
        "id": booking_id,
        "provider_id": p_lookup,
        "customer_id": c_lookup,
        "customer_name": cust_display,
        "service_type": service_clean,
        "package_id": final_package_id,
        "tier": final_tier,
        "service_name": (final_tier.capitalize() + " Package")
        if service_clean == "package" and final_tier
        else "Pet Sitter",
        "price_snapshot": price_snapshot,
        "start_datetime": start_datetime,
        "end_datetime": end_datetime,
        "pet_name": pet_name or "Pet",
        "pet_type": pet_type or "Dog",
        "notes": notes or "",
        "status": "pending",
    }



def get_dashboard_stats(lookup: str) -> dict:
    """
    Endpoint 4:
    - enabled services summary
    - bookings count and earnings per package
    - real rating/review_count (null/0 -> client shows 'New', no hardcoded badges)
    - package_id + price_snapshot used for computations
    """
    lookup_clean = lookup.strip()
    profile = get_profile(lookup_clean)
    packages = get_packages(lookup_clean)
    rating, review_count = get_real_reviews_stats(lookup_clean)

    enabled_packages = [p["tier"] for p in packages if p["enabled"]]
    enabled_services_summary = {
        "sitter_enabled": profile["sitter_enabled"],
        "enabled_packages": enabled_packages,
        "total_enabled_services": (1 if profile["sitter_enabled"] else 0)
        + len(enabled_packages),
    }

    # Query provider_bookings from provider.db
    package_stats = []
    total_package_earnings = 0.0
    total_package_bookings = 0

    with connection() as db:
        for pkg in packages:
            row = db.execute(
                """
                SELECT COUNT(id) AS booking_count, COALESCE(SUM(price_snapshot), 0) AS total_earnings
                FROM provider_bookings
                WHERE provider_lookup = ? AND (package_id = ? OR tier = ?)
                """,
                (lookup_clean, pkg["id"], pkg["tier"]),
            ).fetchone()

            b_count = int(row["booking_count"] or 0)
            earnings = float(row["total_earnings"] or 0.0)

            total_package_bookings += b_count
            total_package_earnings += earnings

            package_stats.append(
                {
                    "package_id": pkg["id"],
                    "tier": pkg["tier"],
                    "enabled": pkg["enabled"],
                    "price": pkg["price"],
                    "bookings_count": b_count,
                    "earnings": earnings,
                }
            )

        # Sitter bookings
        sitter_row = db.execute(
            """
            SELECT COUNT(id) AS booking_count, COALESCE(SUM(price_snapshot), 0) AS total_earnings
            FROM provider_bookings
            WHERE provider_lookup = ? AND service_type = 'sitter'
            """,
            (lookup_clean,),
        ).fetchone()

        sitter_bookings_count = int(sitter_row["booking_count"] or 0)
        # Pending bookings count for requests card
        pending_row = db.execute(
            """
            SELECT COUNT(id) AS pending_count
            FROM provider_bookings
            WHERE (provider_lookup = ? OR provider_id = ?) AND LOWER(status) = 'pending'
            """,
            (lookup_clean, lookup_clean),
        ).fetchone()
        pending_bookings_count = int(pending_row["pending_count"] or 0) if pending_row else 0

        sitter_earnings = float(sitter_row["total_earnings"] or 0.0)

    total_bookings = total_package_bookings + sitter_bookings_count
    total_earnings = total_package_earnings + sitter_earnings

    return {
        "lookup": lookup_clean,
        "rating": rating,
        "review_count": review_count,
        "enabled_services": enabled_services_summary,
        "packages": package_stats,
        "sitter_service": {
            "sitter_enabled": profile["sitter_enabled"],
            "sitter_price": profile["sitter_price"],
            "bookings_count": sitter_bookings_count,
            "earnings": sitter_earnings,
        },
        "total_bookings": total_bookings,
        "total_earnings": total_earnings,
        "pending_bookings_count": pending_bookings_count,
    }


ALLOWED_TRANSITIONS = {
    "pending": {"accepted", "declined", "cancelled"},
    "accepted": {"completed", "cancelled"},
    "declined": set(),
    "completed": set(),
    "cancelled": set(),
}


def _all_provider_aliases(lookup: str) -> list[str]:
    """Return all known lookup aliases for this provider (username + email)."""
    clean = lookup.strip()
    aliases = [clean]
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                u_row = p_db.execute(
                    "SELECT username, email FROM users WHERE username = ? OR email = ? OR id = ?",
                    (clean, clean, int(clean) if clean.isdigit() else -1),
                ).fetchone()
                if u_row:
                    for alt in (u_row["username"], u_row["email"]):
                        if alt and alt not in aliases:
                            aliases.append(alt)
        except Exception:
            pass
    return aliases


def list_provider_bookings(
    provider_lookup: str,
    status_filter: str | None = None,
) -> list[dict]:
    aliases = _all_provider_aliases(provider_lookup.strip())
    placeholders = ",".join("?" for _ in aliases)
    with connection() as db:
        if status_filter and status_filter.strip():
            query = f"""
                SELECT * FROM provider_bookings
                WHERE (provider_lookup IN ({placeholders}) OR provider_id IN ({placeholders}))
                  AND LOWER(status) = LOWER(?)
                ORDER BY
                  CASE WHEN start_datetime IS NOT NULL AND start_datetime != '' THEN start_datetime ELSE created_at END ASC
            """
            rows = db.execute(query, (*aliases, *aliases, status_filter.strip())).fetchall()
        else:
            query = f"""
                SELECT * FROM provider_bookings
                WHERE (provider_lookup IN ({placeholders}) OR provider_id IN ({placeholders}))
                ORDER BY
                  CASE WHEN start_datetime IS NOT NULL AND start_datetime != '' THEN start_datetime ELSE created_at END ASC
            """
            rows = db.execute(query, (*aliases, *aliases)).fetchall()

        return [_format_booking_for_provider(r) for r in rows]



def get_provider_booking_detail(
    booking_id: int,
    provider_lookup: str | None = None,
) -> dict | None:
    with connection() as db:
        row = db.execute(
            "SELECT * FROM provider_bookings WHERE id = ?",
            (booking_id,),
        ).fetchone()
        if not row:
            return None
        if provider_lookup and provider_lookup.strip():
            p_clean = provider_lookup.strip()
            provider_aliases = _all_provider_aliases(p_clean)
            row_p = (
                row["provider_id"]
                if "provider_id" in row.keys() and row["provider_id"]
                else row["provider_lookup"]
            )
            row_p = str(row_p or "").strip()
            # A booking may use the provider's username while the active
            # provider session uses their email (or vice versa).  The list
            # endpoint already recognizes both identifiers, so apply that
            # same ownership rule when opening a notification's booking.
            if row_p and row_p not in provider_aliases:
                raise PermissionError("Unauthorized: You do not own this booking.")
        return _format_booking_for_provider(row)


def update_booking_status(
    booking_id: int,
    new_status: str,
    provider_lookup: str | None = None,
) -> dict:
    target_status = new_status.strip().lower()
    with connection() as db:
        row = db.execute(
            "SELECT * FROM provider_bookings WHERE id = ?",
            (booking_id,),
        ).fetchone()
        if not row:
            raise ValueError(f"Booking with id {booking_id} not found.")

        current_status = (row["status"] or "pending").strip().lower()
        row_provider = (
            row["provider_id"]
            if "provider_id" in row.keys() and row["provider_id"]
            else row["provider_lookup"]
        )
        row_provider = str(row_provider or "").strip()

        if provider_lookup and provider_lookup.strip():
            p_clean = provider_lookup.strip()
            provider_aliases = _all_provider_aliases(p_clean)
            if row_provider and row_provider not in provider_aliases:
                raise PermissionError("Unauthorized: Only the owning provider can update this booking status.")

        allowed = ALLOWED_TRANSITIONS.get(current_status, set())
        if target_status not in allowed:
            raise ValueError(
                f"Invalid transition from '{current_status}' to '{target_status}'. Allowed transitions: {sorted(list(allowed)) if allowed else 'none'}"
            )

        db.execute(
            "UPDATE provider_bookings SET status = ? WHERE id = ?",
            (target_status, booking_id),
        )
        db.commit()

    # Safe sync to pawstay.db
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.execute(
                    "UPDATE bookings SET status = ? WHERE id = ?",
                    (target_status, booking_id),
                )
                p_db.commit()
        except Exception:
            pass

    # On accept/decline, create notification for the customer
    if target_status in ("accepted", "declined"):
        customer_id = (
            row["customer_id"]
            if "customer_id" in row.keys() and row["customer_id"]
            else row["customer_lookup"]
        )
        customer_id = str(customer_id or "").strip()
        provider_name = get_provider_display_name(row_provider)
        add_notification(
            recipient_id=customer_id,
            recipient_role="customer",
            type=f"booking_{target_status}",
            booking_id=booking_id,
            title=f"Booking {target_status.capitalize()}",
            message=f"Your booking request has been {target_status} by {provider_name}.",
        )

    updated = get_provider_booking_detail(booking_id)
    return updated or {"id": booking_id, "status": target_status}


def list_customer_bookings(
    customer_lookup: str,
    status_filter: str | None = None,
) -> list[dict]:
    clean = customer_lookup.strip()
    with connection() as db:
        if status_filter and status_filter.strip():
            query = """
                SELECT * FROM provider_bookings
                WHERE (customer_lookup = ? OR customer_id = ?)
                  AND LOWER(status) = LOWER(?)
                ORDER BY
                  CASE WHEN start_datetime IS NOT NULL AND start_datetime != '' THEN start_datetime ELSE created_at END ASC
            """
            rows = db.execute(query, (clean, clean, status_filter.strip())).fetchall()
        else:
            query = """
                SELECT * FROM provider_bookings
                WHERE (customer_lookup = ? OR customer_id = ?)
                ORDER BY
                  CASE WHEN start_datetime IS NOT NULL AND start_datetime != '' THEN start_datetime ELSE created_at END ASC
            """
            rows = db.execute(query, (clean, clean)).fetchall()

        return [_format_booking_for_provider(r) for r in rows]


def add_notification(
    recipient_id: str,
    recipient_role: str = "provider",
    type: str = "new_booking",
    booking_id: int | None = None,
    title: str | None = None,
    message: str = "",
) -> dict:
    clean_rec = (recipient_id or "").strip()
    with connection() as db:
        cursor = db.execute(
            """
            INSERT INTO notifications (
                recipient_id, recipient_role, type, booking_id, title, message, is_read, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
            """,
            (
                clean_rec,
                recipient_role,
                type,
                booking_id,
                title or type.replace("_", " ").title(),
                message,
            ),
        )
        db.commit()
        nid = cursor.lastrowid

    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.execute(
                    """
                    INSERT INTO notifications (
                        recipient_id, recipient_role, type, booking_id, title, message, is_read, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
                    """,
                    (
                        clean_rec,
                        recipient_role,
                        type,
                        booking_id,
                        title or type.replace("_", " ").title(),
                        message,
                    ),
                )
                p_db.commit()
        except Exception:
            pass

    return {
        "id": nid,
        "recipient_id": clean_rec,
        "recipient_role": recipient_role,
        "type": type,
        "booking_id": booking_id,
        "title": title or type.replace("_", " ").title(),
        "message": message,
        "is_read": False,
    }


def list_notifications(
    recipient_id: str,
    role: str | None = None,
    limit: int = 50,
) -> list[dict]:
    aliases = _all_provider_aliases(recipient_id.strip())
    placeholders = ",".join("?" for _ in aliases)
    with connection() as db:
        if role and role.strip():
            rows = db.execute(
                f"""
                SELECT * FROM notifications
                WHERE recipient_id IN ({placeholders}) AND recipient_role = ?
                ORDER BY created_at DESC LIMIT ?
                """,
                (*aliases, role.strip(), limit),
            ).fetchall()
        else:
            rows = db.execute(
                f"""
                SELECT * FROM notifications
                WHERE recipient_id IN ({placeholders})
                ORDER BY created_at DESC LIMIT ?
                """,
                (*aliases, limit),
            ).fetchall()
        return [
            {
                "id": int(r["id"]),
                "recipient_id": str(r["recipient_id"]),
                "recipient_role": r["recipient_role"],
                "type": r["type"],
                "booking_id": r["booking_id"],
                "title": r["title"] or "",
                "message": r["message"] or "",
                "is_read": bool(r["is_read"]),
                "created_at": str(r["created_at"]),
            }
            for r in rows
        ]


def get_unread_notifications_count(
    recipient_id: str,
    role: str | None = None,
) -> int:
    aliases = _all_provider_aliases(recipient_id.strip())
    placeholders = ",".join("?" for _ in aliases)
    with connection() as db:
        if role and role.strip():
            row = db.execute(
                f"SELECT COUNT(*) AS cnt FROM notifications WHERE recipient_id IN ({placeholders}) AND recipient_role = ? AND is_read = 0",
                (*aliases, role.strip()),
            ).fetchone()
        else:
            row = db.execute(
                f"SELECT COUNT(*) AS cnt FROM notifications WHERE recipient_id IN ({placeholders}) AND is_read = 0",
                (*aliases,),
            ).fetchone()
        return int(row["cnt"] or 0) if row else 0


def mark_notification_read(notification_id: int) -> bool:
    with connection() as db:
        db.execute("UPDATE notifications SET is_read = 1 WHERE id = ?", (notification_id,))
        db.commit()
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.execute("UPDATE notifications SET is_read = 1 WHERE id = ?", (notification_id,))
                p_db.commit()
        except Exception:
            pass
    return True


def mark_all_notifications_read(
    recipient_id: str,
    role: str | None = None,
) -> bool:
    clean_rec = recipient_id.strip()
    with connection() as db:
        if role and role.strip():
            db.execute(
                "UPDATE notifications SET is_read = 1 WHERE recipient_id = ? AND recipient_role = ?",
                (clean_rec, role.strip()),
            )
        else:
            db.execute(
                "UPDATE notifications SET is_read = 1 WHERE recipient_id = ?",
                (clean_rec,),
            )
        db.commit()
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                if role and role.strip():
                    p_db.execute(
                        "UPDATE notifications SET is_read = 1 WHERE recipient_id = ? AND recipient_role = ?",
                        (clean_rec, role.strip()),
                    )
                else:
                    p_db.execute(
                        "UPDATE notifications SET is_read = 1 WHERE recipient_id = ?",
                        (clean_rec,),
                    )
                p_db.commit()
        except Exception:
            pass
    return True


def get_provider_display_name(lookup: str, u_row: sqlite3.Row | dict | None = None) -> str:
    """
    Fallback order:
    profile display name -> user's name field -> email prefix capitalized only if nothing else exists.
    Never return the email.
    """
    if u_row is None and os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                u_row = p_db.execute(
                    "SELECT full_name, username, email FROM users WHERE username = ? OR email = ? OR id = ?",
                    (lookup, lookup, int(lookup) if lookup.isdigit() else -1),
                ).fetchone()
        except Exception:
            pass

    if u_row:
        for key in ("display_name", "full_name", "name"):
            val = u_row[key] if key in u_row.keys() else None
            if val and str(val).strip() and "@" not in str(val):
                return str(val).strip()
        if "username" in u_row.keys() and u_row["username"]:
            val = str(u_row["username"]).strip()
            if val and "@" not in val:
                return val

    clean = lookup.strip()
    prefix = clean.split("@")[0].strip() if "@" in clean else clean
    return prefix.capitalize() if prefix else "Provider"


def get_customer_providers(
    category: str = "sitter", city: str | None = None
) -> list[dict]:
    """
    Endpoint 2:
    category=sitter -> providers with sitter_enabled, return sitter_price.
    category=packages -> providers with >=1 enabled package, return min_package_price.
    Include name, city, rating, review_count.
    """
    category_clean = (category or "sitter").strip().lower()

    # Discover provider candidates from pawstay.db and provider.db
    providers_info = {}

    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                # Users with provider roles
                u_rows = p_db.execute(
                    """
                    SELECT id, full_name, username, email, city, profile_image, role
                    FROM users
                    WHERE LOWER(role) IN ('pet service', 'service provider', 'walker')
                    """
                ).fetchall()
                for u in u_rows:
                    disp_name = get_provider_display_name(u["username"] or u["email"], u)
                    uname = (u["username"] or u["email"] or "").split("@")[0]
                    entry = {
                        "id": u["id"],
                        "name": disp_name,
                        "username": uname,
                        "email": u["email"],
                        "city": u["city"] or "",
                        "profile_image": u["profile_image"],
                    }
                    if u["username"]:
                        providers_info[u["username"]] = entry
                    if u["email"]:
                        providers_info[u["email"]] = entry
        except Exception:
            pass

    # Read all provider profiles from provider.db
    with connection() as db:
        rows = db.execute("SELECT * FROM provider_profiles").fetchall()
        for r in rows:
            lookup = r["lookup"]
            if lookup not in providers_info:
                u = None
                if os.path.exists(PAWSTAY_DB_PATH):
                    try:
                        with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                            p_db.row_factory = sqlite3.Row
                            u = p_db.execute(
                                "SELECT id, full_name, username, email, city, profile_image FROM users WHERE username = ? OR email = ?",
                                (lookup, lookup),
                            ).fetchone()
                    except Exception:
                        pass

                disp_name = get_provider_display_name(lookup, u)
                uname = (u["username"] if u else lookup) or lookup
                if "@" in uname:
                    uname = uname.split("@")[0]
                providers_info[lookup] = {
                    "id": u["id"] if u else (len(providers_info) + 1),
                    "name": disp_name,
                    "username": uname,
                    "city": r["city"] or (u["city"] if u else "") or "",
                    "profile_image": u["profile_image"] if u else None,
                }

    seen_ids = set()
    result = []
    for lookup, info in providers_info.items():
        if info["id"] in seen_ids:
            continue
        profile = get_profile(lookup)
        packages = get_packages(lookup)
        rating, review_count = get_real_reviews_stats(lookup)

        # Merge city: prefer profile city if specified, else user city
        city_val = profile["city"] or info.get("city") or ""
        if city and city.strip() and city.strip().lower() not in city_val.lower():
            continue

        if category_clean == "sitter":
            if not profile["sitter_enabled"]:
                continue
            seen_ids.add(info["id"])
            item = {
                "id": info["id"],
                "name": info["name"],
                "username": info["username"],
                "city": city_val,
                "sitter_price": profile["sitter_price"],
                "rating": rating,
                "review_count": review_count,
                "bio": profile["bio"],
                "experience_years": profile["experience_years"],
                "pet_types": profile["pet_types"],
                "profile_image": info.get("profile_image"),
            }
            result.append(item)

        elif category_clean == "packages":
            enabled_pkgs = [p for p in packages if p["enabled"]]
            if not enabled_pkgs:
                continue
            seen_ids.add(info["id"])
            min_price = min(p["price"] for p in enabled_pkgs)
            item = {
                "id": info["id"],
                "name": info["name"],
                "username": info["username"],
                "city": city_val,
                "min_package_price": min_price,
                "rating": rating,
                "review_count": review_count,
                "bio": profile["bio"],
                "experience_years": profile["experience_years"],
                "pet_types": profile["pet_types"],
                "profile_image": info.get("profile_image"),
            }
            result.append(item)

    return result


def get_customer_provider_detail(lookup: str) -> dict:
    """
    Endpoint 3:
    Customer provider detail: profile + only ENABLED services/packages.
    NEVER return email/phone.
    """
    lookup_clean = lookup.strip()
    profile = get_profile(lookup_clean)
    packages = get_packages(lookup_clean)
    rating, review_count = get_real_reviews_stats(lookup_clean)

    # Provider identity from pawstay.db (WITHOUT email or phone_number)
    u_row = None
    if os.path.exists(PAWSTAY_DB_PATH):
        try:
            with sqlite3.connect(PAWSTAY_DB_PATH) as p_db:
                p_db.row_factory = sqlite3.Row
                u_row = p_db.execute(
                    "SELECT id, full_name, username, profile_image, city FROM users WHERE username = ? OR email = ? OR id = ?",
                    (lookup_clean, lookup_clean, int(lookup_clean) if lookup_clean.isdigit() else -1),
                ).fetchone()
                if u_row:
                    if not profile["city"] and u_row["city"]:
                        profile["city"] = u_row["city"]
        except Exception:
            pass

    name = get_provider_display_name(lookup_clean, u_row)
    username = (u_row["username"] if u_row else lookup_clean) or lookup_clean
    if "@" in username:
        username = username.split("@")[0]
    provider_id = u_row["id"] if u_row else 1
    profile_image = u_row["profile_image"] if u_row else None

    # Only ENABLED packages
    enabled_packages = [p for p in packages if p["enabled"]]

    detail = {
        "id": provider_id,
        "name": name,
        "username": username,
        "bio": profile["bio"],
        "city": profile["city"],
        "experience_years": profile["experience_years"],
        "pet_types": profile["pet_types"],
        "profile_image": profile_image,
        "rating": rating,
        "review_count": review_count,
    }

    # Only ENABLED sitter service
    if profile["sitter_enabled"]:
        detail["sitter_service"] = {
            "sitter_enabled": True,
            "sitter_price": profile["sitter_price"],
            "sitter_duration_mins": profile["sitter_duration_mins"],
        }
    else:
        detail["sitter_service"] = None

    detail["packages"] = enabled_packages

    # Ensure email and phone are NEVER present
    detail.pop("email", None)
    detail.pop("phone", None)
    detail.pop("phone_number", None)

    return detail


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
