"""SQLite storage for seller-owned products and orders."""

import os
import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Iterator

DATABASE_PATH = os.path.join(os.path.dirname(__file__), "seller.db")


@contextmanager
def connection() -> Iterator[sqlite3.Connection]:
    os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)
    db = sqlite3.connect(DATABASE_PATH)
    db.row_factory = sqlite3.Row
    try:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS seller_products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                seller_lookup TEXT NOT NULL,
                listing_type TEXT NOT NULL DEFAULT 'other',
                name TEXT NOT NULL,
                subhead_tag TEXT NOT NULL DEFAULT '',
                offer_tag TEXT NOT NULL DEFAULT '',
                brand TEXT NOT NULL DEFAULT '',
                animal_type TEXT NOT NULL DEFAULT '',
                breed TEXT NOT NULL DEFAULT '',
                suitable_for TEXT NOT NULL DEFAULT '[]',
                price REAL NOT NULL CHECK (price > 0),
                mrp REAL NOT NULL CHECK (mrp > 0),
                stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
                sku TEXT,
                category_id INTEGER NOT NULL DEFAULT 1,
                pet_type TEXT NOT NULL DEFAULT 'Other',
                description TEXT NOT NULL DEFAULT '',
                image_url TEXT NOT NULL DEFAULT '',
                image_urls TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (seller_lookup, sku)
            )
            """
        )
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS seller_orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                seller_lookup TEXT NOT NULL,
                order_code TEXT NOT NULL,
                customer_name TEXT NOT NULL DEFAULT '',
                pet_name TEXT NOT NULL DEFAULT '',
                pet_breed TEXT NOT NULL DEFAULT '',
                shipping_address TEXT NOT NULL DEFAULT '',
                total_amount REAL NOT NULL CHECK (total_amount >= 0),
                quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
                order_status TEXT NOT NULL DEFAULT 'Pending',
                payment_status TEXT NOT NULL DEFAULT 'Pending',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (seller_lookup, order_code)
            )
            """
        )
        product_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(seller_products)")
        }
        product_migrations = {
            "listing_type": "TEXT NOT NULL DEFAULT 'other'",
            "animal_type": "TEXT NOT NULL DEFAULT ''",
            "breed": "TEXT NOT NULL DEFAULT ''",
            "suitable_for": "TEXT NOT NULL DEFAULT '[]'",
            "image_urls": "TEXT NOT NULL DEFAULT '[]'",
        }
        for name, definition in product_migrations.items():
            if name not in product_columns:
                db.execute(
                    f"ALTER TABLE seller_products ADD COLUMN {name} {definition}"
                )

        order_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(seller_orders)")
        }
        if "payment_status" not in order_columns:
            db.execute(
                "ALTER TABLE seller_orders ADD COLUMN payment_status "
                "TEXT NOT NULL DEFAULT 'Pending'"
            )
        db.commit()
        yield db
    finally:
        db.close()


def initialize_database() -> None:
    with connection():
        pass


def list_products(seller_lookup: str) -> list[dict]:
    with connection() as db:
        rows = db.execute(
            """
            SELECT * FROM seller_products
            WHERE seller_lookup = ?
            ORDER BY created_at DESC, id DESC
            """,
            (seller_lookup,),
        ).fetchall()
    return [_decode_product(dict(row)) for row in rows]


def create_product(seller_lookup: str, product: dict) -> dict:
    with connection() as db:
        cursor = db.execute(
            """
            INSERT INTO seller_products (
                seller_lookup, listing_type, name, subhead_tag, offer_tag, brand,
                animal_type, breed, suitable_for, price, mrp, sku, category_id,
                pet_type, description, image_url, image_urls
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                seller_lookup,
                product.get("listing_type", "other"),
                product["name"],
                product.get("subhead_tag", ""),
                product.get("offer_tag", ""),
                product.get("brand", ""),
                product.get("animal_type", ""),
                product.get("breed", ""),
                json.dumps(product.get("suitable_for", [])),
                product["price"],
                product.get("mrp", product["price"]),
                product.get("sku"),
                product.get("category_id", 1),
                product.get("pet_type", "Other"),
                product.get("description", ""),
                product.get("image_url", ""),
                json.dumps(product.get("image_urls", [])),
            ),
        )
        db.commit()
        row = db.execute(
            "SELECT * FROM seller_products WHERE id = ?", (cursor.lastrowid,)
        ).fetchone()
    return _decode_product(dict(row))


def _decode_product(product: dict) -> dict:
    product.pop("stock_quantity", None)
    try:
        product["image_urls"] = json.loads(product.get("image_urls") or "[]")
        product["suitable_for"] = json.loads(product.get("suitable_for") or "[]")
    except (json.JSONDecodeError, TypeError):
        product["image_urls"] = []
        product["suitable_for"] = []
    if not product["image_urls"] and product.get("image_url"):
        product["image_urls"] = [product["image_url"]]
    return product


def list_orders(seller_lookup: str) -> list[dict]:
    with connection() as db:
        rows = db.execute(
            """
            SELECT * FROM seller_orders
            WHERE seller_lookup = ?
            ORDER BY created_at DESC, id DESC
            """,
            (seller_lookup,),
        ).fetchall()
    return [dict(row) for row in rows]


def update_order_status(
    seller_lookup: str, order_id: int, order_status: str
) -> dict | None:
    with connection() as db:
        cursor = db.execute(
            """
            UPDATE seller_orders
            SET order_status = ?
            WHERE id = ? AND seller_lookup = ?
            """,
            (order_status, order_id, seller_lookup),
        )
        db.commit()
        if cursor.rowcount == 0:
            return None
        row = db.execute(
            "SELECT * FROM seller_orders WHERE id = ? AND seller_lookup = ?",
            (order_id, seller_lookup),
        ).fetchone()
    return dict(row)


def get_analytics(seller_lookup: str) -> dict:
    with connection() as db:
        row = db.execute(
            """
            SELECT
                COALESCE(SUM(CASE WHEN payment_status = 'Paid'
                                  THEN total_amount ELSE 0 END), 0) AS total_revenue,
                COUNT(*) AS total_orders,
                COALESCE(SUM(CASE WHEN payment_status = 'Paid'
                                  THEN quantity ELSE 0 END), 0) AS products_sold,
                COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) AS completed_orders
                ,COUNT(CASE WHEN payment_status = 'Paid' THEN 1 END) AS paid_orders
                ,COALESCE(SUM(CASE WHEN payment_status = 'Paid'
                                   THEN total_amount ELSE 0 END), 0) AS payments_received
            FROM seller_orders
            WHERE seller_lookup = ?
            """,
            (seller_lookup,),
        ).fetchone()
        status_rows = db.execute(
            """
            SELECT order_status, COUNT(*) AS order_count
            FROM seller_orders
            WHERE seller_lookup = ?
            GROUP BY order_status
            ORDER BY order_status
            """,
            (seller_lookup,),
        ).fetchall()
        revenue_rows = db.execute(
            """
            SELECT date(created_at) AS order_date,
                   COALESCE(SUM(total_amount), 0) AS daily_revenue
            FROM seller_orders
            WHERE seller_lookup = ?
              AND payment_status = 'Paid'
              AND date(created_at) >= date('now', '-6 days')
            GROUP BY date(created_at)
            """,
            (seller_lookup,),
        ).fetchall()
    revenue = float(row["total_revenue"])
    valid_orders = int(row["completed_orders"])
    with connection() as db:
        product_count = db.execute(
            "SELECT COUNT(*) FROM seller_products WHERE seller_lookup = ?",
            (seller_lookup,),
        ).fetchone()[0]
        category_rows = db.execute(
            """
            SELECT listing_type, animal_type, COUNT(*) AS listing_count
            FROM seller_products
            WHERE seller_lookup = ?
            GROUP BY listing_type, animal_type
            """,
            (seller_lookup,),
        ).fetchall()
    category_counts = {"food": 0, "pets": 0, "other": 0, "dogs": 0, "cats": 0}
    for category in category_rows:
        listing_type = category["listing_type"]
        count = int(category["listing_count"])
        if listing_type in category_counts:
            category_counts[listing_type] += count
        if listing_type == "pets":
            animal_type = category["animal_type"].strip().lower()
            if animal_type == "dog":
                category_counts["dogs"] += count
            elif animal_type == "cat":
                category_counts["cats"] += count
    daily_totals = {
        item["order_date"]: float(item["daily_revenue"])
        for item in revenue_rows
    }
    today = datetime.now(timezone.utc).date()
    return {
        "total_revenue": revenue,
        "payments_received": float(row["payments_received"]),
        "payments_received_count": int(row["paid_orders"]),
        "total_products": int(product_count),
        "category_counts": category_counts,
        "total_orders": int(row["total_orders"]),
        "average_order_value": revenue / valid_orders if valid_orders else 0,
        "products_sold": int(row["products_sold"]),
        "orders_by_status": {
            item["order_status"]: int(item["order_count"])
            for item in status_rows
        },
        "revenue_by_day": [
            {
                "date": (today - timedelta(days=offset)).isoformat(),
                "revenue": daily_totals.get(
                    (today - timedelta(days=offset)).isoformat(), 0
                ),
            }
            for offset in range(6, -1, -1)
        ],
    }
