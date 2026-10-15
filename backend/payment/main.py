"""Razorpay checkout, payment verification, and customer order endpoints."""

import base64
import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from dotenv import load_dotenv
from fastapi import APIRouter, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator, model_validator
from database.db import SessionLocal
from database.models import User
from payment.auth import authenticated_user
from payment.payment_db import (
    create_payment_order,
    expire_pending_payments,
    finalize_payment,
    get_buyer_orders,
)
from seller.seller_db import (
    connection,
    _decode_product,
    get_buyer_address,
    initialize_database,
    save_buyer_address,
)

load_dotenv(Path(__file__).resolve().parents[1] / ".env")
initialize_database()
router = APIRouter()
app = FastAPI(
    title="PawStay Payment API",
    description="Marketplace checkout, payment verification, and customer orders.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
_RAZORPAY_API = "https://api.razorpay.com/v1"
_ORDER_EXPIRY_SECONDS = 15 * 60


class CartItemRequest(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0, le=1000)


class CreateOrderRequest(BaseModel):
    product_id: int | None = Field(default=None, gt=0)
    items: list[CartItemRequest] | None = Field(
        default=None, min_length=1, max_length=50
    )

    @model_validator(mode="after")
    def exactly_one_checkout_shape(self):
        if (self.product_id is None) == (self.items is None):
            raise ValueError("Provide either product_id or items.")
        if self.items is not None:
            quantities: dict[int, int] = {}
            for item in self.items:
                quantities[item.product_id] = (
                    quantities.get(item.product_id, 0) + item.quantity
                )
            if any(quantity > 1000 for quantity in quantities.values()):
                raise ValueError("A product quantity cannot exceed 1000.")
        return self

    def checkout_items(self) -> list[dict[str, int]]:
        if self.items is not None:
            quantities: dict[int, int] = {}
            for item in self.items:
                quantities[item.product_id] = (
                    quantities.get(item.product_id, 0) + item.quantity
                )
            return [
                {"product_id": product_id, "quantity": quantity}
                for product_id, quantity in quantities.items()
            ]
        return [{"product_id": self.product_id, "quantity": 1}]


class VerifyPaymentRequest(BaseModel):
    razorpay_order_id: str = Field(min_length=1)
    razorpay_payment_id: str = Field(min_length=1)
    razorpay_signature: str = Field(min_length=1)

    @classmethod
    def _validate_gateway_id(cls, value: str, prefix: str) -> str:
        suffix = value.removeprefix(prefix)
        if not suffix or not suffix.isalnum():
            raise ValueError("Invalid Razorpay identifier.")
        return value

    @field_validator("razorpay_order_id")
    @classmethod
    def valid_order_id(cls, value: str) -> str:
        return cls._validate_gateway_id(value, "order_")

    @field_validator("razorpay_payment_id")
    @classmethod
    def valid_payment_id(cls, value: str) -> str:
        return cls._validate_gateway_id(value, "pay_")


class BuyerAddressRequest(BaseModel):
    apartment_flat: str = Field(min_length=1, max_length=200)
    street_address: str = Field(min_length=1, max_length=300)
    state: str = Field(min_length=1, max_length=100)
    city: str = Field(min_length=1, max_length=100)
    postal_code: str = Field(min_length=1, max_length=20)

    @field_validator(
        "apartment_flat", "street_address", "state", "city", "postal_code"
    )
    @classmethod
    def address_fields_are_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Address fields cannot be blank.")
        return value


def _current_user(authorization: str | None) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401, detail="Please sign in to place or view orders."
        )
    identity = authenticated_user(authorization[7:].strip())
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == identity["user_id"]).first()
        if (
            user is None
            or user.email.strip().lower() != identity["email"]
            or not user.is_verified
        ):
            raise HTTPException(
                status_code=401, detail="Please sign in again to continue."
            )
        db.expunge(user)
    return user


def _razorpay_credentials() -> tuple[str, str]:
    raw_key_id = (os.getenv("RAZORPAY_KEY_ID") or "").strip()
    raw_api_key = (os.getenv("RAZORPAY_API_KEY") or "").strip()
    key_secret = (os.getenv("RAZORPAY_KEY_SECRET") or "").strip()

    key_id = ""
    for candidate in [raw_key_id, raw_api_key]:
        if candidate.startswith("rzp_test_") or candidate.startswith("rzp_live_"):
            key_id = candidate
            break

    if not key_id:
        if raw_key_id and len(raw_key_id) == 14 and raw_key_id.isalnum():
            key_id = f"rzp_test_{raw_key_id}"
        elif raw_api_key and len(raw_api_key) == 14 and raw_api_key.isalnum():
            key_id = f"rzp_test_{raw_api_key}"
        else:
            key_id = raw_key_id or raw_api_key

    if not key_id or not key_secret:
        raise HTTPException(
            status_code=503,
            detail="Razorpay is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.",
        )
    return key_id, key_secret


def _razorpay_request(method: str, path: str, payload: dict | None = None) -> dict:
    key_id, key_secret = _razorpay_credentials()
    credentials = base64.b64encode(f"{key_id}:{key_secret}".encode()).decode()
    body = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(
        f"{_RAZORPAY_API}{path}",
        data=body,
        method=method,
        headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            result = json.loads(response.read())
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        try:
            message = json.loads(detail).get("error", {}).get("description")
        except (json.JSONDecodeError, AttributeError):
            message = None
        raise HTTPException(
            status_code=502,
            detail=message or "Razorpay rejected the payment request.",
        ) from error
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=502, detail="Razorpay returned an invalid response."
        ) from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise HTTPException(
            status_code=502,
            detail="Razorpay could not be reached. Please try again.",
        ) from error
    if not isinstance(result, dict):
        raise HTTPException(
            status_code=502, detail="Razorpay returned an invalid response."
        )
    return result


@router.get("/shop/products")
def marketplace_products():
    expire_pending_payments()
    with connection() as db:
        rows = db.execute(
            """
            SELECT * FROM seller_products
            ORDER BY created_at DESC, id DESC
            """
        ).fetchall()
    return [_decode_product(dict(row)) for row in rows]


@router.get("/payments/address")
def buyer_address(authorization: str | None = Header(default=None)):
    user = _current_user(authorization)
    return get_buyer_address(user.id)


@router.put("/payments/address")
def update_buyer_address(
    payload: BuyerAddressRequest,
    authorization: str | None = Header(default=None),
):
    user = _current_user(authorization)
    return save_buyer_address(user.id, payload.model_dump())


@router.post("/payments/orders", status_code=201)
def create_checkout_order(
    payload: CreateOrderRequest,
    authorization: str | None = Header(default=None),
):
    user = _current_user(authorization)
    saved_address = get_buyer_address(user.id)
    if saved_address is None:
        raise HTTPException(
            status_code=400,
            detail="Save a shipping address before placing your order.",
        )
    shipping_address = ", ".join(
        [
            saved_address["apartment_flat"],
            saved_address["street_address"],
            saved_address["city"],
            saved_address["state"],
            saved_address["postal_code"],
        ]
    )
    expire_pending_payments()
    items = payload.checkout_items()
    product_ids = [item["product_id"] for item in items]
    placeholders = ",".join("?" for _ in product_ids)
    with connection() as db:
        products = db.execute(
            f"""
            SELECT id, name, price, stock_quantity
            FROM seller_products WHERE id IN ({placeholders})
            """,
            product_ids,
        ).fetchall()
    products_by_id = {int(product["id"]): product for product in products}
    if len(products_by_id) != len(items):
        raise HTTPException(status_code=404, detail="A listing no longer exists.")
    for item in items:
        product = products_by_id[item["product_id"]]
        if int(product["stock_quantity"]) < item["quantity"]:
            raise HTTPException(
                status_code=409,
                detail=f"{product['name']} does not have enough stock.",
            )

    amount_paise = sum(
        int(round(float(products_by_id[item["product_id"]]["price"]) * 100))
        * item["quantity"]
        for item in items
    )
    if amount_paise <= 0:
        raise HTTPException(status_code=400, detail="The cart total must be positive.")
    first_product_id = items[0]["product_id"]
    receipt = f"ps_{user.id}_{int(time.time())}_{uuid.uuid4().hex[:8]}"[:40]
    razorpay_order = _razorpay_request(
        "POST",
        "/orders",
        {
            "amount": amount_paise,
            "currency": "INR",
            "receipt": receipt,
            "notes": {
                "buyer_user_id": str(user.id),
                "item_count": str(sum(item["quantity"] for item in items)),
            },
        },
    )
    razorpay_order_id = razorpay_order.get("id")
    if not isinstance(razorpay_order_id, str) or not razorpay_order_id:
        raise HTTPException(
            status_code=502, detail="Razorpay did not return an order ID."
        )

    payment_order = create_payment_order(
        items=items,
        user_id=user.id,
        buyer_email=user.email,
        buyer_name=user.full_name,
        razorpay_order_id=razorpay_order_id,
        amount_paise=amount_paise,
        shipping_address=shipping_address,
    )
    if payment_order is None:
        raise HTTPException(
            status_code=409,
            detail="This listing sold out or changed price. Refresh the shop and try again.",
        )

    key_id, _ = _razorpay_credentials()
    return {
        **payment_order,
        "product_id": first_product_id,
        "razorpay_order_id": razorpay_order_id,
        "key_id": key_id,
        "amount_paise": amount_paise,
        "currency": "INR",
        "customer_name": user.full_name,
        "customer_email": user.email,
        "customer_phone": user.phone_number or "",
    }


@router.post("/payments/verify")
def verify_checkout_payment(
    payload: VerifyPaymentRequest,
    authorization: str | None = Header(default=None),
):
    user = _current_user(authorization)
    _, key_secret = _razorpay_credentials()
    with connection() as db:
        payment = db.execute(
            """
            SELECT * FROM marketplace_payments
            WHERE razorpay_order_id = ? AND buyer_user_id = ?
            """,
            (payload.razorpay_order_id, user.id),
        ).fetchone()
    if payment is None:
        raise HTTPException(status_code=404, detail="Payment order not found.")

    expected_signature = hmac.new(
        key_secret.encode(),
        f"{payload.razorpay_order_id}|{payload.razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(payload.razorpay_signature, expected_signature):
        raise HTTPException(status_code=400, detail="Payment signature is invalid.")

    gateway_payment = _razorpay_request(
        "GET", f"/payments/{payload.razorpay_payment_id}"
    )
    if (
        gateway_payment.get("order_id") != payload.razorpay_order_id
        or gateway_payment.get("amount") != payment["amount_paise"]
        or gateway_payment.get("status") != "captured"
    ):
        raise HTTPException(
            status_code=409,
            detail="Razorpay has not confirmed a captured payment for this order.",
        )

    result = finalize_payment(
        user_id=user.id,
        razorpay_order_id=payload.razorpay_order_id,
        razorpay_payment_id=payload.razorpay_payment_id,
    )
    if result is None:
        raise HTTPException(
            status_code=409,
            detail="This checkout expired or has already been completed.",
        )
    return result


@router.get("/payments/orders")
def buyer_orders(authorization: str | None = Header(default=None)):
    user = _current_user(authorization)
    return get_buyer_orders(user.id)


app.include_router(router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8004)
