"""PawStay provider API with new service model (Sitter + 3 Packages)."""

import os
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from service_provider.provider_db import (
    create_booking,
    get_customer_provider_detail,
    get_customer_providers,
    get_dashboard_stats,
    get_profile,
    get_services,
    update_services,
    update_status,
    list_provider_bookings,
    get_provider_booking_detail,
    update_booking_status,
    list_customer_bookings,
    add_notification,
    list_notifications,
    get_unread_notifications_count,
    mark_notification_read,
    mark_all_notifications_read,
)

app = FastAPI(
    title="PawStay Service Provider API",
    description="Provider-only API backed by service_provider/provider.db with support for Pet Sitter and Packages",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class ProfileSchema(BaseModel):
    bio: str = Field(default="", max_length=500)
    city: str = ""
    experience_years: int = 0
    pet_types: list[str] = Field(default_factory=list)


class SitterServiceSchema(BaseModel):
    sitter_enabled: bool = False
    sitter_price: float = 0.0
    sitter_duration_mins: int = 60


class PackageSchema(BaseModel):
    id: int | None = None
    tier: str  # bronze, silver, gold
    enabled: bool = False
    price: float = 0.0
    duration_value: int = 1
    duration_unit: str = "hours"
    meals_per_day: int = 0
    walks_per_day: int = 0
    inclusions: list[str] = Field(default_factory=list)
    description: str = ""


class ProviderServicesRequest(BaseModel):
    lookup: str | None = None
    provider_lookup: str | None = None
    profile: ProfileSchema = Field(default_factory=ProfileSchema)
    sitter_service: SitterServiceSchema = Field(default_factory=SitterServiceSchema)
    packages: list[PackageSchema] = Field(default_factory=list)


class ProviderStatusRequest(BaseModel):
    lookup: str | None = None
    provider_lookup: str | None = None
    is_online: bool


class BookingRequest(BaseModel):
    provider_lookup: str | None = None
    provider_id: str | None = None
    customer_lookup: str | None = None
    customer_id: str | None = None
    service_type: str  # sitter or package
    package_id: int | None = None
    tier: str | None = None
    price: float | None = None
    start_datetime: str | None = None
    end_datetime: str | None = None
    pet_name: str | None = None
    pet_type: str | None = None
    notes: str | None = None


class BookingStatusUpdateRequest(BaseModel):
    status: str  # accepted, declined, completed, cancelled
    provider_lookup: str | None = None
    provider_id: str | None = None


class NotificationMarkAllReadRequest(BaseModel):
    recipient_id: str | None = None
    role: str | None = None


# ---------------------------------------------------------------------------
# Health Check
# ---------------------------------------------------------------------------
@app.get("/")
def health_check():
    return {"status": "ok", "service": "PawStay provider API"}


# ---------------------------------------------------------------------------
# Endpoint 1: Provider GET / PUT Services
# profile + sitter service + 3 packages in one payload
# Server validation: price>0 if enabled; at least one service enabled;
# silver>=bronze, gold>=silver (only among enabled); bio<=500
# ---------------------------------------------------------------------------
@app.get("/provider/services")
def read_provider_services(lookup: str = Query(..., alias="lookup")):
    clean_lookup = lookup.strip()
    if not clean_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    return get_services(clean_lookup)


@app.put("/provider/services")
def save_provider_services(
    payload: ProviderServicesRequest, lookup: str | None = None
):
    target_lookup = (payload.lookup or payload.provider_lookup or lookup or "").strip()
    if not target_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")

    data = payload.model_dump()
    try:
        updated = update_services(target_lookup, data)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# Aliases for /provider/profile to maintain backward compatibility
@app.get("/provider/profile")
def read_provider_profile(lookup: str = Query(..., alias="lookup")):
    clean_lookup = lookup.strip()
    if not clean_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    services = get_services(clean_lookup)
    is_complete = bool(
        services["sitter_service"]["sitter_enabled"]
        or any(p["enabled"] for p in services["packages"])
    )
    return {
        **services,
        "is_complete": is_complete,
    }


@app.put("/provider/profile")
def save_provider_profile(payload: dict):
    target_lookup = str(
        payload.get("lookup") or payload.get("provider_lookup") or ""
    ).strip()
    if not target_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")

    # If payload is structured as profile+sitter+packages:
    if "profile" in payload or "sitter_service" in payload or "packages" in payload:
        try:
            updated = update_services(target_lookup, payload)
            return {"success": True, **updated}
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

    # Backward compatibility for old payloads
    old_walking = payload.get("walking_charge") or payload.get("sitter_price") or 0
    old_desc = (
        payload.get("provider_description") or payload.get("bio") or ""
    ).strip()

    services_payload = {
        "profile": {"bio": old_desc[:500]},
        "sitter_service": {
            "sitter_enabled": bool(old_walking > 0),
            "sitter_price": float(old_walking),
            "sitter_duration_mins": 60,
        },
        "packages": [],
    }
    try:
        updated = update_services(target_lookup, services_payload)
        return {"success": True, **updated}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.patch("/provider/status")
def save_provider_status(payload: ProviderStatusRequest):
    lookup = payload.lookup or payload.provider_lookup
    if not lookup or not lookup.strip():
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    update_status(lookup.strip(), payload.is_online)
    return {"success": True, "is_online": payload.is_online}


# ---------------------------------------------------------------------------
# Endpoint 2: Customer list
# category=sitter -> providers with sitter_enabled, return "sitter_price"
# category=packages -> providers with >=1 enabled package, return "min_package_price"
# Include name, city, rating, review_count (computed from real reviews)
# ---------------------------------------------------------------------------
@app.get("/services")
def list_services_for_customer(
    category: str = Query("sitter"), city: str | None = None
):
    return get_customer_providers(category=category, city=city)


# ---------------------------------------------------------------------------
# Endpoint 3: Customer provider detail
# profile + only ENABLED services/packages. NEVER return email/phone.
# ---------------------------------------------------------------------------
@app.get("/services/{lookup}")
def read_customer_provider_detail(lookup: str):
    clean_lookup = lookup.strip()
    if not clean_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    return get_customer_provider_detail(clean_lookup)


@app.get("/provider/detail/{lookup}")
def read_provider_detail_path(lookup: str):
    return get_customer_provider_detail(lookup.strip())


@app.get("/provider/detail")
def read_provider_detail_query(lookup: str = Query(...)):
    return get_customer_provider_detail(lookup.strip())


# ---------------------------------------------------------------------------
# Endpoint 4: Dashboard stats
# enabled services summary, bookings count and earnings per package, rating
# Rating/review_count computed from real reviews (null/0 -> client shows "New").
# If bookings exist, store package_id + price_snapshot.
# ---------------------------------------------------------------------------
@app.get("/provider/dashboard-stats")
@app.get("/provider/stats")
def read_provider_dashboard_stats(
    lookup: str | None = None, provider_lookup: str | None = None
):
    target = (lookup or provider_lookup or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    return get_dashboard_stats(target)


# ---------------------------------------------------------------------------
# Bookings: store package_id + price_snapshot
# ---------------------------------------------------------------------------
# Bookings: create, list, detail, and status updates
# ---------------------------------------------------------------------------
@app.post("/provider/bookings")
@app.post("/bookings")
def handle_create_booking(payload: BookingRequest):
    p_lookup = (payload.provider_id or payload.provider_lookup or "").strip()
    c_lookup = (payload.customer_id or payload.customer_lookup or "").strip()
    if not p_lookup:
        raise HTTPException(status_code=400, detail="Provider lookup/id is required.")
    if not c_lookup:
        raise HTTPException(status_code=400, detail="Customer lookup/id is required.")

    try:
        booking = create_booking(
            provider_lookup=p_lookup,
            service_type=payload.service_type,
            package_id=payload.package_id,
            tier=payload.tier,
            price=payload.price,
            customer_lookup=c_lookup,
            start_datetime=payload.start_datetime,
            end_datetime=payload.end_datetime,
            pet_name=payload.pet_name,
            pet_type=payload.pet_type,
            notes=payload.notes,
            provider_id=p_lookup,
            customer_id=c_lookup,
        )
        return {"success": True, "booking": booking}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/provider/bookings")
def get_provider_bookings(
    provider_lookup: str | None = Query(None),
    provider_id: str | None = Query(None),
    lookup: str | None = Query(None),
    status_filter: str | None = Query(None),
    status: str | None = Query(None),
):
    target = (provider_id or provider_lookup or lookup or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="Provider lookup/id is required.")
    st = status_filter or status
    return list_provider_bookings(target, status_filter=st)


@app.get("/provider/bookings/{booking_id}")
def get_booking_detail(
    booking_id: int,
    provider_lookup: str | None = Query(None),
    provider_id: str | None = Query(None),
):
    target = (provider_id or provider_lookup or "").strip()
    try:
        booking = get_provider_booking_detail(
            booking_id,
            provider_lookup=target if target else None,
        )
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")
        return booking
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.patch("/provider/bookings/{booking_id}/status")
@app.post("/provider/bookings/{booking_id}/status")
@app.patch("/bookings/{booking_id}/status")
def handle_update_booking_status(
    booking_id: int,
    payload: BookingStatusUpdateRequest,
):
    target_provider = (payload.provider_id or payload.provider_lookup or "").strip()
    try:
        updated = update_booking_status(
            booking_id=booking_id,
            new_status=payload.status,
            provider_lookup=target_provider if target_provider else None,
        )
        return {"success": True, "booking": updated}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/customer/bookings")
@app.get("/bookings/customer")
def get_customer_bookings(
    customer_lookup: str | None = Query(None),
    customer_id: str | None = Query(None),
    status_filter: str | None = Query(None),
):
    target = (customer_id or customer_lookup or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="Customer lookup/id is required.")
    return list_customer_bookings(target, status_filter=status_filter)


# ---------------------------------------------------------------------------
# Notifications endpoints (both provider & customer roles)
# ---------------------------------------------------------------------------
@app.get("/notifications")
def get_notifications(
    recipient_id: str | None = Query(None),
    user_id: str | None = Query(None),
    lookup: str | None = Query(None),
    role: str | None = Query(None),
    limit: int = Query(50),
):
    target = (recipient_id or user_id or lookup or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="Recipient id/lookup is required.")
    return list_notifications(target, role=role, limit=limit)


@app.get("/notifications/unread-count")
def get_unread_count(
    recipient_id: str | None = Query(None),
    user_id: str | None = Query(None),
    lookup: str | None = Query(None),
    role: str | None = Query(None),
):
    target = (recipient_id or user_id or lookup or "").strip()
    if not target:
        return {"unread_count": 0}
    count = get_unread_notifications_count(target, role=role)
    return {"unread_count": count}


@app.post("/notifications/{notification_id}/read")
@app.patch("/notifications/{notification_id}/read")
def handle_mark_notification_read(notification_id: int):
    success = mark_notification_read(notification_id)
    return {"success": success}


@app.post("/notifications/mark-all-read")
def handle_mark_all_read(payload: NotificationMarkAllReadRequest):
    target = (payload.recipient_id or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="Recipient ID is required.")
    success = mark_all_notifications_read(target, role=payload.role)
    return {"success": success}



if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)
