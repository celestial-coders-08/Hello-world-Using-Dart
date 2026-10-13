"""Database-backed admin reporting for marketplace payments."""

from datetime import date, datetime, timedelta

from seller.seller_db import connection


def get_sales_report(period: str) -> dict:
    if period not in {"week", "month", "all"}:
        raise ValueError("Unsupported reporting period.")

    today = date.today()
    if period == "week":
        start = today - timedelta(days=6)
        bucket_dates = [start + timedelta(days=offset) for offset in range(7)]
        bucket_format = "day"
    elif period == "month":
        start = today - timedelta(days=29)
        bucket_dates = [start + timedelta(days=offset) for offset in range(30)]
        bucket_format = "day"
    else:
        start = None
        bucket_dates = []
        bucket_format = "month"

    with connection() as db:
        date_filter = ""
        parameters: tuple[str, ...] = ()
        if start is not None:
            date_filter = "AND date(created_at) BETWEEN ? AND ?"
            parameters = (start.isoformat(), today.isoformat())
        totals = db.execute(
            f"""
            SELECT
                COUNT(*) AS order_count,
                COALESCE(SUM(CASE WHEN payment_status = 'Paid'
                                  THEN amount_paise ELSE 0 END), 0) AS gross_volume,
                COALESCE(SUM(CASE WHEN payment_status = 'Paid'
                                  THEN 1 ELSE 0 END), 0) AS paid_count
            FROM marketplace_payments
            WHERE 1 = 1 {date_filter}
            """,
            parameters,
        ).fetchone()
        status_rows = db.execute(
            f"""
            SELECT payment_status, COUNT(*) AS order_count
            FROM marketplace_payments
            WHERE 1 = 1 {date_filter}
            GROUP BY payment_status
            """,
            parameters,
        ).fetchall()
        paid_date_filter = ""
        if start is not None:
            paid_date_filter = "AND date(created_at) BETWEEN ? AND ?"
        payment_alias_date_filter = ""
        if start is not None:
            payment_alias_date_filter = "AND date(p.created_at) BETWEEN ? AND ?"
        date_group = (
            "strftime('%Y-%m', created_at)"
            if bucket_format == "month"
            else "date(created_at)"
        )
        revenue_rows = db.execute(
            f"""
            SELECT {date_group} AS bucket,
                   COALESCE(SUM(amount_paise), 0) AS gross_volume
            FROM marketplace_payments
            WHERE payment_status = 'Paid' {paid_date_filter}
            GROUP BY bucket
            ORDER BY bucket
            """,
            parameters,
        ).fetchall()
        if bucket_format == "month":
            first_month = (
                datetime.strptime(revenue_rows[0]["bucket"], "%Y-%m").date()
                if revenue_rows
                else today.replace(day=1)
            )
            month = first_month.replace(day=1)
            while month <= today.replace(day=1):
                bucket_dates.append(month)
                next_month = month.replace(day=28) + timedelta(days=4)
                month = next_month.replace(day=1)
        category_rows = db.execute(
            f"""
            SELECT COALESCE(NULLIF(lower(sp.listing_type), ''), 'other') AS category,
                   COALESCE(SUM(COALESCE(pi.amount_paise, p.amount_paise)), 0)
                       AS gross_volume
            FROM marketplace_payments p
            LEFT JOIN marketplace_payment_items pi ON pi.payment_id = p.id
            LEFT JOIN seller_products sp
                ON sp.id = COALESCE(pi.product_id, p.product_id)
            WHERE p.payment_status = 'Paid' {payment_alias_date_filter}
            GROUP BY category
            ORDER BY gross_volume DESC
            """,
            parameters,
        ).fetchall()
        orders = db.execute(
            f"""
            SELECT p.order_code, p.buyer_name, p.buyer_email, p.product_name,
                   p.amount_paise, p.payment_status, p.created_at,
                   COALESCE(NULLIF(lower(sp.listing_type), ''), 'other') AS category
            FROM marketplace_payments p
            LEFT JOIN seller_products sp ON sp.id = p.product_id
            WHERE 1 = 1 {payment_alias_date_filter}
            ORDER BY p.created_at DESC, p.id DESC
            LIMIT 100
            """,
            parameters,
        ).fetchall()

    revenues_by_bucket = {
        row["bucket"]: int(row["gross_volume"]) / 100 for row in revenue_rows
    }
    categories = [
        {
            "category": row["category"],
            "amount": int(row["gross_volume"]) / 100,
        }
        for row in category_rows
    ]
    revenue_series = []
    for bucket_date in bucket_dates:
        bucket = (
            bucket_date.strftime("%Y-%m")
            if bucket_format == "month"
            else bucket_date.isoformat()
        )
        revenue_series.append(
            {
                "label": (
                    bucket_date.strftime("%b")
                    if bucket_format == "month"
                    else bucket_date.strftime("%a")
                ),
                "date": bucket,
                "amount": revenues_by_bucket.get(bucket, 0),
            }
        )

    gross_volume = int(totals["gross_volume"]) / 100
    paid_count = int(totals["paid_count"])
    return {
        "total_orders": int(totals["order_count"]),
        "status_counts": {
            str(row["payment_status"]): int(row["order_count"])
            for row in status_rows
        },
        "paid_orders": paid_count,
        "gross_volume": gross_volume,
        "average_order_value": gross_volume / paid_count if paid_count else 0,
        "commission_revenue": None,
        "revenue_series": revenue_series,
        "category_sales": categories,
        "orders": [
            {
                "order_id": row["order_code"],
                "customer_name": row["buyer_name"],
                "customer_email": row["buyer_email"],
                "item_description": row["product_name"],
                "category": row["category"],
                "amount": int(row["amount_paise"]) / 100,
                "payment_method": "N/A",
                "timestamp": row["created_at"],
                "status": row["payment_status"],
            }
            for row in orders
        ],
    }
