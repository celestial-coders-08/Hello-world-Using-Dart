"""Payment and marketplace order persistence in the seller SQLite database."""

import uuid

from seller.seller_db import connection


def create_payment_order(
    *,
    user_id: int,
    buyer_email: str,
    buyer_name: str,
    razorpay_order_id: str,
    amount_paise: int,
    shipping_address: str = "",
    items: list[dict] | None = None,
    product_id: int | None = None,
) -> dict | None:
    checkout_items = items or (
        [{"product_id": product_id, "quantity": 1}] if product_id is not None else []
    )
    if not checkout_items:
        raise ValueError("A checkout must contain at least one product.")

    with connection() as db:
        product_ids = [item["product_id"] for item in checkout_items]
        placeholders = ",".join("?" for _ in product_ids)
        products = db.execute(
            f"""
            SELECT id, seller_lookup, name, price, stock_quantity
            FROM seller_products WHERE id IN ({placeholders})
            """,
            product_ids,
        ).fetchall()
        products_by_id = {int(product["id"]): product for product in products}
        if len(products_by_id) != len(checkout_items):
            return None
        calculated_amount = sum(
            int(round(float(products_by_id[item["product_id"]]["price"]) * 100))
            * item["quantity"]
            for item in checkout_items
        )
        if calculated_amount != amount_paise:
            return None

        for item in checkout_items:
            cursor = db.execute(
                """
                UPDATE seller_products
                SET stock_quantity = stock_quantity - ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND stock_quantity >= ?
                """,
                (item["quantity"], item["product_id"], item["quantity"]),
            )
            if cursor.rowcount != 1:
                db.rollback()
                return None

        order_code = f"PS-{uuid.uuid4().hex[:12].upper()}"
        first_item = checkout_items[0]
        first_product = products_by_id[first_item["product_id"]]
        db.execute(
            """
            INSERT INTO marketplace_payments (
                order_code, product_id, seller_lookup, buyer_user_id,
                buyer_email, buyer_name, product_name, razorpay_order_id,
                amount_paise, shipping_address, payment_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending')
            """,
            (
                order_code,
                first_item["product_id"],
                first_product["seller_lookup"],
                user_id,
                buyer_email,
                buyer_name,
                first_product["name"],
                razorpay_order_id,
                amount_paise,
                shipping_address,
            ),
        )
        payment_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        line_items = []
        for item in checkout_items:
            product = products_by_id[item["product_id"]]
            line_amount = int(round(float(product["price"]) * 100)) * item["quantity"]
            db.execute(
                """
                INSERT INTO marketplace_payment_items (
                    payment_id, product_id, seller_lookup, product_name,
                    quantity, amount_paise
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    payment_id,
                    item["product_id"],
                    product["seller_lookup"],
                    product["name"],
                    item["quantity"],
                    line_amount,
                ),
            )
            line_items.append(
                {
                    "product_id": item["product_id"],
                    "product_name": product["name"],
                    "seller_lookup": product["seller_lookup"],
                    "quantity": item["quantity"],
                    "amount": line_amount / 100,
                }
            )
        db.commit()
        return {
            "order_code": order_code,
            "product_id": first_product["id"],
            "product_name": first_product["name"],
            "seller_lookup": first_product["seller_lookup"],
            "items": line_items,
        }


def expire_pending_payments() -> None:
    with connection() as db:
        expired = db.execute(
            """
            SELECT id, product_id FROM marketplace_payments
            WHERE payment_status = 'Pending'
              AND datetime(created_at) <= datetime('now', '-15 minutes')
            """
        ).fetchall()
        for payment in expired:
            items = db.execute(
                """
                SELECT product_id, quantity FROM marketplace_payment_items
                WHERE payment_id = ?
                """,
                (payment["id"],),
            ).fetchall()
            if not items:
                items = [{"product_id": payment["product_id"], "quantity": 1}]
            for item in items:
                db.execute(
                    """
                    UPDATE seller_products
                    SET stock_quantity = stock_quantity + ?,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                    """,
                    (item["quantity"], item["product_id"]),
                )
        db.execute(
            """
            UPDATE marketplace_payments
            SET payment_status = 'Expired'
            WHERE payment_status = 'Pending'
              AND datetime(created_at) <= datetime('now', '-15 minutes')
            """
        )
        db.commit()


def finalize_payment(
    *,
    user_id: int,
    razorpay_order_id: str,
    razorpay_payment_id: str,
) -> dict | None:
    with connection() as db:
        payment = db.execute(
            """
            SELECT * FROM marketplace_payments
            WHERE razorpay_order_id = ? AND buyer_user_id = ?
            """,
            (razorpay_order_id, user_id),
        ).fetchone()
        if payment is None:
            return None
        if payment["payment_status"] == "Paid":
            if payment["razorpay_payment_id"] != razorpay_payment_id:
                return None
            return _payment_result(payment)
        if payment["payment_status"] != "Pending":
            return None
        items = db.execute(
            """
            SELECT product_id, seller_lookup, product_name, quantity, amount_paise
            FROM marketplace_payment_items WHERE payment_id = ?
            ORDER BY product_id
            """,
            (payment["id"],),
        ).fetchall()
        if not items:
            items = [
                {
                    "product_id": payment["product_id"],
                    "seller_lookup": payment["seller_lookup"],
                    "product_name": payment["product_name"],
                    "quantity": 1,
                    "amount_paise": payment["amount_paise"],
                }
            ]

        order_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(seller_orders)")
        }
        required_columns = {
            "buyer_user_id",
            "customer_email",
            "product_id",
            "product_name",
            "razorpay_order_id",
            "razorpay_payment_id",
        }
        if not required_columns.issubset(order_columns):
            raise RuntimeError("Seller order database migration did not complete.")

        for index, item in enumerate(items):
            line_order_code = (
                payment["order_code"]
                if len(items) == 1
                else f"{payment['order_code']}-{index + 1}"
            )
            line_amount = item["amount_paise"] / 100
            db.execute(
                """
                INSERT INTO seller_orders (
                    seller_lookup, order_code, customer_name, total_amount, quantity,
                    shipping_address, order_status, payment_status, buyer_user_id,
                    customer_email, product_id, product_name, razorpay_order_id,
                    razorpay_payment_id
                ) VALUES (?, ?, ?, ?, ?, ?, 'Pending', 'Paid', ?, ?, ?, ?, ?, ?)
                """,
                (
                    item["seller_lookup"],
                    line_order_code,
                    payment["buyer_name"],
                    line_amount,
                    item["quantity"],
                    payment["shipping_address"],
                    payment["buyer_user_id"],
                    payment["buyer_email"],
                    item["product_id"],
                    item["product_name"],
                    razorpay_order_id,
                    razorpay_payment_id,
                ),
            )
        db.execute(
            """
            UPDATE marketplace_payments
            SET payment_status = 'Paid', razorpay_payment_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (razorpay_payment_id, payment["id"]),
        )
        db.commit()
        updated = db.execute(
            "SELECT * FROM marketplace_payments WHERE id = ?",
            (payment["id"],),
        ).fetchone()
    return _payment_result(updated)


def get_buyer_orders(user_id: int) -> list[dict]:
    expire_pending_payments()
    with connection() as db:
        rows = db.execute(
            """
            SELECT *
            FROM marketplace_payments p
            WHERE p.buyer_user_id = ?
              AND p.payment_status = 'Paid'
            ORDER BY p.created_at DESC
            """,
            (user_id,),
        ).fetchall()
        orders = []
        for row in rows:
            items = _get_payment_items(db, row)
            statuses = db.execute(
                """
                SELECT DISTINCT order_status FROM seller_orders
                WHERE razorpay_order_id = ?
                """,
                (row["razorpay_order_id"],),
            ).fetchall()
            order_statuses = [status["order_status"] for status in statuses]
            order_status = (
                "Awaiting payment"
                if not order_statuses
                else (
                    order_statuses[0]
                    if len(order_statuses) == 1
                    else next(
                        (
                            status
                            for status in order_statuses
                            if status != "Delivered"
                        ),
                        "Delivered",
                    )
                )
            )
            seller_names = list(dict.fromkeys(item["seller_lookup"] for item in items))
            product_names = [
                (
                    item["product_name"]
                    if item["quantity"] == 1
                    else f"{item['product_name']} × {item['quantity']}"
                )
                for item in items
            ]
            orders.append(
                {
                    "order_code": row["order_code"],
                    "product_id": row["product_id"],
                    "product_name": ", ".join(product_names),
                    "seller_lookup": (
                        seller_names[0] if len(seller_names) == 1 else "Multiple sellers"
                    ),
                    "amount_paise": row["amount_paise"],
                    "total_amount": row["amount_paise"] / 100,
                    "payment_status": row["payment_status"],
                    "razorpay_payment_id": row["razorpay_payment_id"],
                    "payment_id": row["razorpay_payment_id"],
                    "created_at": row["created_at"],
                    "order_status": order_status,
                    "items": [
                        {
                            **dict(item),
                            "amount": item["amount_paise"] / 100,
                        }
                        for item in items
                    ],
                }
            )
    return orders


def _get_payment_items(db, payment) -> list[dict]:
    items = db.execute(
        """
        SELECT product_id, seller_lookup, product_name, quantity, amount_paise
        FROM marketplace_payment_items WHERE payment_id = ?
        ORDER BY product_id
        """,
        (payment["id"],),
    ).fetchall()
    if items:
        return [dict(item) for item in items]
    return [
        {
            "product_id": payment["product_id"],
            "seller_lookup": payment["seller_lookup"],
            "product_name": payment["product_name"],
            "quantity": 1,
            "amount_paise": payment["amount_paise"],
        }
    ]


def _payment_result(payment) -> dict:
    return {
        "order_code": payment["order_code"],
        "payment_status": payment["payment_status"],
        "razorpay_order_id": payment["razorpay_order_id"],
        "razorpay_payment_id": payment["razorpay_payment_id"],
        "product_id": payment["product_id"],
        "product_name": payment["product_name"],
        "amount": payment["amount_paise"] / 100,
        "items": _get_payment_items_from_payment(payment),
    }


def _get_payment_items_from_payment(payment) -> list[dict]:
    with connection() as db:
        items = _get_payment_items(db, payment)
    return [
        {
            **item,
            "amount": item["amount_paise"] / 100,
        }
        for item in items
    ]
