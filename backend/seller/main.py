"""PawStay Seller API backed by seller/seller.db."""

import os
import json
import sqlite3
import sys
import uuid

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlalchemy import func, or_
from starlette.staticfiles import StaticFiles

from database.db import SessionLocal
from database.models import User
from seller.seller_db import (
    create_product,
    get_analytics,
    initialize_database,
    list_orders,
    list_products,
    update_order_status,
)

initialize_database()
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
MAX_LISTING_IMAGES = 5
MAX_IMAGE_SIZE = 5 * 1024 * 1024

app = FastAPI(
    title="PawStay Seller API",
    description="Seller listings, order management, and sales analytics.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount(
    "/seller/media",
    StaticFiles(directory=UPLOAD_DIR),
    name="seller-media",
)


class ProductRequest(BaseModel):
    seller_lookup: str
    name: str = Field(min_length=1, max_length=200)
    subhead_tag: str = ""
    offer_tag: str = ""
    brand: str = ""
    price: float = Field(gt=0)
    mrp: float = Field(gt=0)
    sku: str | None = None
    category_id: int = Field(default=1, ge=1)
    pet_type: str = "Other"
    description: str = ""
    image_url: str = ""

    @field_validator("seller_lookup", "name")
    @classmethod
    def required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be empty.")
        return value

    @model_validator(mode="after")
    def mrp_not_below_price(self) -> "ProductRequest":
        if self.mrp < self.price:
            raise ValueError("MRP must be greater than or equal to the selling price.")
        return self


class OrderStatusRequest(BaseModel):
    seller_lookup: str
    order_status: str

    @field_validator("order_status")
    @classmethod
    def allowed_status(cls, value: str) -> str:
        statuses = {
            "Pending",
            "Confirmed",
            "Processing",
            "Shipped",
            "Delivered",
            "Cancelled",
        }
        normalized = value.strip().title()
        if normalized not in statuses:
            raise ValueError("Unsupported order status.")
        return normalized


def require_seller(lookup: str) -> str:
    normalized = lookup.strip()
    if not normalized:
        raise HTTPException(status_code=400, detail="Seller lookup is required.")

    user_conditions = [
        func.lower(User.email) == normalized.lower(),
        func.lower(User.username) == normalized.lower(),
    ]
    if normalized.isdigit():
        user_conditions.append(User.id == int(normalized))

    with SessionLocal() as db:
        seller_user = (
            db.query(User)
            .filter(or_(*user_conditions), func.lower(User.role) == "seller")
            .first()
        )

    if seller_user is None:
        raise HTTPException(status_code=403, detail="A valid seller account is required.")

    # Use the canonical username so email and username logins share one seller store.
    return seller_user.username


@app.get("/")
def health_check():
    return {"status": "ok", "service": "PawStay seller API"}


@app.get("/seller/products")
def read_products(
    lookup: str = Query(min_length=1),
    listing_type: str | None = None,
    animal_type: str | None = None,
):
    seller_lookup = require_seller(lookup)
    products = list_products(seller_lookup)
    if listing_type:
        products = [
            item
            for item in products
            if item.get("listing_type", "other").lower() == listing_type.lower()
        ]
    if animal_type:
        products = [
            item
            for item in products
            if item.get("animal_type", "").lower() == animal_type.lower()
        ]
    return products


@app.post("/seller/products", status_code=201)
def add_product(payload: ProductRequest):
    seller_lookup = require_seller(payload.seller_lookup)
    product = payload.model_dump(exclude={"seller_lookup"})
    if product["sku"] is not None:
        product["sku"] = product["sku"].strip() or None
    try:
        return create_product(seller_lookup, product)
    except sqlite3.IntegrityError as error:
        if "UNIQUE constraint failed" in str(error):
            raise HTTPException(status_code=409, detail="This SKU is already in use.") from error
        raise


@app.post("/seller/listings", status_code=201)
async def add_listing(
    seller_lookup: str = Form(),
    listing_type: str = Form(),
    price: float = Form(gt=0),
    name: str = Form(default=""),
    brand: str = Form(default=""),
    animal_type: str = Form(default=""),
    breed: str = Form(default=""),
    suitable_for: str = Form(default="[]"),
    description: str = Form(default=""),
    images: list[UploadFile] = File(default=[]),
):
    canonical_lookup = require_seller(seller_lookup)
    listing_type = listing_type.strip().lower()
    if listing_type not in {"food", "pets", "other"}:
        raise HTTPException(
            status_code=422,
            detail="Listing type must be food, pets, or other.",
        )
    if len(images) > MAX_LISTING_IMAGES:
        raise HTTPException(
            status_code=422,
            detail=f"Select no more than {MAX_LISTING_IMAGES} images.",
        )

    name = name.strip()
    brand = brand.strip()
    animal_type = animal_type.strip()
    breed = breed.strip()
    description = description.strip()
    if listing_type == "food" and not brand:
        raise HTTPException(
            status_code=422,
            detail="Food listings require a brand.",
        )
    if listing_type == "pets" and (animal_type not in {"Dog", "Cat", "Other"} or not breed):
        raise HTTPException(
            status_code=422,
            detail="Pet listings require a valid animal type and breed.",
        )
    if listing_type == "other" and (not name or not description):
        raise HTTPException(
            status_code=422,
            detail="Other item listings require a name and description.",
        )
    if not images:
        raise HTTPException(status_code=422, detail="Select at least one image.")

    try:
        suitable_for_values = json.loads(suitable_for)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=422,
            detail="Food eligible animals must be a JSON list.",
        ) from error
    if not isinstance(suitable_for_values, list) or any(
        value not in {"Dog", "Cat", "Other"} for value in suitable_for_values
    ):
        raise HTTPException(
            status_code=422,
            detail="Food eligible animals must be Dog, Cat, or Other.",
        )
    if listing_type == "food" and not suitable_for_values:
        raise HTTPException(
            status_code=422,
            detail="Select at least one animal that can eat this food.",
        )

    saved_paths: list[str] = []
    image_urls: list[str] = []
    try:
        for image in images:
            contents = await image.read(MAX_IMAGE_SIZE + 1)
            if len(contents) > MAX_IMAGE_SIZE:
                raise HTTPException(
                    status_code=413,
                    detail="Each image must be 5 MB or smaller.",
                )
            if contents.startswith(b"\xff\xd8\xff"):
                extension = ".jpg"
            elif contents.startswith(b"\x89PNG\r\n\x1a\n"):
                extension = ".png"
            elif contents.startswith(b"RIFF") and contents[8:12] == b"WEBP":
                extension = ".webp"
            else:
                raise HTTPException(
                    status_code=415,
                    detail="Images must be JPEG, PNG, or WebP files.",
                )
            filename = f"{uuid.uuid4().hex}{extension}"
            destination = os.path.join(UPLOAD_DIR, filename)
            with open(destination, "xb") as output:
                output.write(contents)
            saved_paths.append(destination)
            image_urls.append(f"/seller/media/{filename}")

        if listing_type == "food":
            listing_name = f"{brand} food"
            pet_type = ", ".join(suitable_for_values)
        elif listing_type == "pets":
            listing_name = f"{animal_type} - {breed}"
            pet_type = animal_type
        else:
            listing_name = name
            pet_type = "Other"

        return create_product(
            canonical_lookup,
            {
                "listing_type": listing_type,
                "name": listing_name,
                "brand": brand,
                "animal_type": animal_type if listing_type != "food" else "",
                "breed": breed,
                "suitable_for": suitable_for_values,
                "price": price,
                "mrp": price,
                "category_id": 1,
                "pet_type": pet_type,
                "description": description,
                "image_url": image_urls[0],
                "image_urls": image_urls,
            },
        )
    except Exception:
        for saved_path in saved_paths:
            if os.path.exists(saved_path):
                os.remove(saved_path)
        raise
    finally:
        for image in images:
            await image.close()


@app.get("/seller/orders")
def read_orders(lookup: str = Query(min_length=1)):
    return list_orders(require_seller(lookup))


@app.patch("/seller/orders/{order_id}/status")
def save_order_status(order_id: int, payload: OrderStatusRequest):
    seller_lookup = require_seller(payload.seller_lookup)
    order = update_order_status(seller_lookup, order_id, payload.order_status)
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found.")
    return order


@app.get("/seller/analytics")
def read_analytics(lookup: str = Query(min_length=1)):
    return get_analytics(require_seller(lookup))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8003)
