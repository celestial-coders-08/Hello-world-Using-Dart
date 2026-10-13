"""Dedicated authenticated admin API for PawStay."""

import os
import sys
from datetime import date, datetime, time, timedelta

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from sqlalchemy import String, cast, func
from sqlalchemy.orm import Session

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

load_dotenv(os.path.join(BACKEND_DIR, ".env"))

from admin.analytics import get_sales_report
from database.db import Base, engine, get_db
from database.models import Pet, Review, User
from payment.auth import authenticated_user
from seller.seller_db import (
    get_analytics as get_seller_analytics,
    list_verifications,
    update_verification_status,
)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="PawStay Admin API",
    description="Authenticated dashboard reporting and seller verification review.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SellerVerificationReviewRequest(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        if value not in {"Approved", "Rejected"}:
            raise ValueError("Verification status must be Approved or Rejected.")
        return value


def require_admin(authorization: str | None) -> None:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Admin sign-in is required.")
    claims = authenticated_user(authorization[7:].strip())
    admin_email = os.getenv("ADMIN_EMAIL", "admin@pawstay.com").strip().lower()
    if claims["user_id"] != 999999 or claims["email"] != admin_email:
        raise HTTPException(status_code=403, detail="Admin access is required.")


def _admin_user_stats(db: Session) -> dict:
    total_users = db.query(func.count(User.id)).scalar() or 0
    total_providers = (
        db.query(func.count(User.id))
        .filter(
            func.lower(User.role).in_(
                ["pet service", "service provider", "walker"]
            )
        )
        .scalar()
        or 0
    )
    total_pets = db.query(func.count(Pet.id)).scalar() or 0
    verified_users = (
        db.query(func.count(User.id))
        .filter(User.is_verified.is_(True))
        .scalar()
        or 0
    )
    sales = get_sales_report("all")
    return {
        "total_users": total_users,
        "active_users_today": None,
        "verified_users": verified_users,
        "total_providers": total_providers,
        "total_pets": total_pets,
        "total_revenue": sales["gross_volume"],
        "monthly_revenue": get_sales_report("month")["gross_volume"],
        "platform_profit": None,
        "total_orders": sales["total_orders"],
    }


def _created_at_label(value: str | None) -> str:
    if not value:
        return "N/A"
    try:
        return datetime.fromisoformat(value).strftime("%b %d, %Y")
    except ValueError:
        return "N/A"


@app.get("/")
def health_check() -> dict:
    return {"status": "ok", "service": "PawStay Admin API"}


@app.get("/admin/stats")
def get_admin_stats(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)
    stats = _admin_user_stats(db)
    verifications = list_verifications()
    stats["pending_providers"] = sum(
        item["status"] == "Pending" for item in verifications
    )
    return stats


@app.get("/admin/analytics")
def get_admin_analytics(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)
    today = date.today()
    start = today - timedelta(days=6)
    registrations = (
        db.query(func.date(User.created_at), func.count(User.id))
        .filter(User.created_at >= datetime.combine(start, time.min))
        .group_by(func.date(User.created_at))
        .all()
    )
    registrations_by_date = {
        str(registration_date): int(count)
        for registration_date, count in registrations
    }
    return {
        "signup_trend": [
            {
                "date": (start + timedelta(days=offset)).isoformat(),
                "label": (start + timedelta(days=offset)).strftime("%a"),
                "count": registrations_by_date.get(
                    (start + timedelta(days=offset)).isoformat(), 0
                ),
            }
            for offset in range(7)
        ],
        "stats": _admin_user_stats(db),
    }


@app.get("/admin/sales")
def get_admin_sales(
    period: str = "month",
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)
    if period not in {"week", "month", "all"}:
        raise HTTPException(status_code=422, detail="Unsupported reporting period.")
    return get_sales_report(period)


@app.get("/admin/users")
def get_admin_users(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> list[dict]:
    require_admin(authorization)
    users = (
        db.query(
            User.id,
            User.full_name,
            User.username,
            User.email,
            User.phone_number,
            User.city,
            User.state,
            User.role,
            User.is_verified,
            cast(User.created_at, String).label("created_at"),
        )
        .order_by(User.id.desc())
        .all()
    )
    result = []
    for user in users:
        pet_count = (
            db.query(func.count(Pet.id))
            .filter(
                Pet.user_id.in_(
                    [user.email, user.username, str(user.id)]
                )
            )
            .scalar()
            or 0
        )
        result.append(
            {
                "id": user.id,
                "full_name": user.full_name,
                "username": user.username,
                "email": user.email,
                "phone_number": user.phone_number or "N/A",
                "city": user.city,
                "state": user.state,
                "role": user.role,
                "is_verified": user.is_verified,
                "created_at": _created_at_label(user.created_at),
                "pet_count": pet_count,
                "status": "Active" if user.is_verified else "Pending",
            }
        )
    return result


@app.get("/admin/providers")
def get_admin_providers(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> list[dict]:
    require_admin(authorization)
    providers = (
        db.query(
            User.id,
            User.full_name,
            User.username,
            User.email,
            User.phone_number,
            User.city,
            User.walking_charge,
            User.daycare_charge,
            User.is_verified,
        )
        .filter(
            func.lower(User.role).in_(
                ["pet service", "service provider", "walker"]
            )
        )
        .order_by(User.id.desc())
        .all()
    )
    result = []
    for provider in providers:
        average_rating, review_count = db.query(
            func.avg(Review.rating), func.count(Review.id)
        ).filter(Review.provider_lookup == provider.username).first()
        result.append(
            {
                "id": provider.id,
                "full_name": provider.full_name,
                "username": provider.username,
                "email": provider.email,
                "phone_number": provider.phone_number or "N/A",
                "city": provider.city,
                "walking_charge": provider.walking_charge,
                "daycare_charge": provider.daycare_charge,
                "rating": (
                    round(float(average_rating), 1)
                    if average_rating is not None
                    else None
                ),
                "review_count": int(review_count or 0),
                "is_verified": provider.is_verified,
                "status": "Approved" if provider.is_verified else "Pending Review",
            }
        )
    return result


@app.get("/admin/seller-verifications")
def read_admin_seller_verifications(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> list[dict]:
    require_admin(authorization)
    verifications = list_verifications()
    if not verifications:
        return []

    seller_lookups = {item["seller_lookup"] for item in verifications}
    sellers = (
        db.query(
            User.id,
            User.full_name,
            User.username,
            User.email,
            User.phone_number,
            User.city,
            User.state,
            User.profile_image,
        )
        .filter(
            func.lower(User.role) == "seller",
            User.username.in_(seller_lookups),
        )
        .all()
    )
    sellers_by_lookup = {seller.username: seller for seller in sellers}
    result = []
    for verification in verifications:
        seller = sellers_by_lookup.get(verification["seller_lookup"])
        if seller is None:
            continue
        result.append(
            {
                "id": seller.id,
                "full_name": seller.full_name,
                "username": seller.username,
                "email": seller.email,
                "phone_number": seller.phone_number or "",
                "city": seller.city,
                "state": seller.state,
                "profile_image": seller.profile_image or "",
                "is_shop_owner": verification["is_shop_owner"],
                "shop_proof_url": verification["shop_proof_url"],
                "aadhaar_url": verification["aadhaar_url"],
                "face_images": verification["face_images"],
                "completed_orders": get_seller_analytics(
                    verification["seller_lookup"]
                )["payments_received_count"],
                "status": verification["status"],
                "created_at": verification["created_at"],
                "updated_at": verification["updated_at"],
            }
        )
    return result


@app.patch("/admin/seller-verifications/{seller_lookup}")
def review_admin_seller_verification(
    seller_lookup: str,
    payload: SellerVerificationReviewRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    require_admin(authorization)
    record = update_verification_status(seller_lookup, payload.status)
    if record is None:
        raise HTTPException(status_code=404, detail="Seller verification not found.")
    return record


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8005)
