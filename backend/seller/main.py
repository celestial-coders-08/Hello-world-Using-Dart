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
    create_verification,
    get_analytics,
    get_verification,
    initialize_database,
    list_orders,
    list_products,
    update_product,
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


class ProductUpdateRequest(BaseModel):
    description: str = Field(max_length=4000)
    price: float = Field(gt=0)
    stock_quantity: int | None = Field(default=None, ge=0)
    in_stock: bool | None = None

    @model_validator(mode="after")
    def require_stock_value(self) -> "ProductUpdateRequest":
        if self.stock_quantity is None and self.in_stock is None:
            raise ValueError("Provide a stock quantity or stock status.")
        return self


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


MAX_DOC_SIZE = 1 * 1024 * 1024  # 1 MB maximum for documents


@app.patch("/seller/products/{product_id}")
def save_product(
    product_id: int,
    payload: ProductUpdateRequest,
    seller_lookup: str = Query(min_length=1),
):
    seller_lookup = require_seller(seller_lookup)
    product = update_product(
        seller_lookup,
        product_id,
        description=payload.description.strip(),
        price=payload.price,
        stock_quantity=(
            payload.stock_quantity
            if payload.stock_quantity is not None
            else int(payload.in_stock)
        ),
    )
    if product is None:
        raise HTTPException(status_code=404, detail="Listing not found.")
    return product


@app.get("/seller/verification")
def read_seller_verification(lookup: str = Query(min_length=1)):
    seller_lookup = require_seller(lookup)
    record = get_verification(seller_lookup)
    if not record:
        return {"status": "Unverified", "is_shop_owner": False}
    return record


@app.post("/seller/verification", status_code=201)
async def submit_seller_verification(
    seller_lookup: str = Form(),
    is_shop_owner: bool = Form(default=False),
    aadhaar_file: UploadFile = File(...),
    shop_proof_file: UploadFile | None = File(default=None),
    face_photos: list[UploadFile] = File(default=[]),
):
    canonical_lookup = require_seller(seller_lookup)

    if is_shop_owner and shop_proof_file is None:
        raise HTTPException(
            status_code=422,
            detail="Shop owners must upload a government-issued shop proof document.",
        )

    # Validate document file sizes (<= 1 MB)
    async def _save_doc(upload: UploadFile, prefix: str) -> str:
        contents = await upload.read(MAX_DOC_SIZE + 1)
        if len(contents) > MAX_DOC_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"{upload.filename or 'Document'} exceeds the maximum allowed size of 1 MB.",
            )
        filename = f"{prefix}_{uuid.uuid4().hex}_{os.path.basename(upload.filename or 'doc.pdf')}"
        dest = os.path.join(UPLOAD_DIR, filename)
        with open(dest, "wb") as f:
            f.write(contents)
        return f"/seller/media/{filename}"

    aadhaar_url = await _save_doc(aadhaar_file, "aadhaar")
    shop_proof_url = ""
    if is_shop_owner and shop_proof_file:
        shop_proof_url = await _save_doc(shop_proof_file, "shop_proof")

    face_urls = []
    for face in face_photos:
        contents = await face.read(MAX_IMAGE_SIZE + 1)
        filename = f"face_{uuid.uuid4().hex}.jpg"
        dest = os.path.join(UPLOAD_DIR, filename)
        with open(dest, "wb") as f:
            f.write(contents)
        face_urls.append(f"/seller/media/{filename}")

    record = create_verification(
        canonical_lookup,
        {
            "is_shop_owner": is_shop_owner,
            "shop_proof_url": shop_proof_url,
            "aadhaar_url": aadhaar_url,
            "face_images": face_urls,
            "status": "Approved",
        },
    )
    return record


@app.post("/seller/listings", status_code=201)
async def add_listing(
    seller_lookup: str = Form(),
    listing_type: str = Form(),
    price: float = Form(gt=0),
    stock_quantity: int = Form(default=1, ge=0),
    name: str = Form(default=""),
    brand: str = Form(default=""),
    animal_type: str = Form(default=""),
    breed: str = Form(default=""),
    suitable_for: str = Form(default="[]"),
    description: str = Form(default=""),
    has_health_issue: bool = Form(default=False),
    health_issue: str = Form(default=""),
    images: list[UploadFile] = File(default=[]),
):
    canonical_lookup = require_seller(seller_lookup)

    # Check seller verification & shop owner status
    verification = get_verification(canonical_lookup)
    is_shop_owner = verification.get("is_shop_owner", False) if verification else False

    listing_type = listing_type.strip().lower()
    if listing_type not in {"food", "pets", "other"}:
        raise HTTPException(
            status_code=422,
            detail="Listing type must be food, pets, or other.",
        )

    # Non-shop owners can only sell pets
    if not is_shop_owner and listing_type != "pets":
        raise HTTPException(
            status_code=403,
            detail="Individual sellers (non-shop owners) can only list pets for sale. Verify as a shop owner to list pet food or items.",
        )

    # Validate minimum 3 and maximum 5 images
    if len(images) < 3 or len(images) > 5:
        raise HTTPException(
            status_code=422,
            detail="Please select at least 3 images and no more than 5 images.",
        )

    name = name.strip()
    brand = brand.strip()
    animal_type = animal_type.strip()
    breed = breed.strip()
    description = description.strip()
    health_issue = health_issue.strip() if has_health_issue else ""

    if listing_type == "food" and not brand:
        raise HTTPException(
            status_code=422,
            detail="Food listings require a brand/food name.",
        )
    if listing_type == "pets" and (animal_type not in {"Dog", "Cat", "Other"} or not breed):
        raise HTTPException(
            status_code=422,
            detail="Pet listings require a valid animal type and breed.",
        )
    if listing_type == "other" and (not name or not description):
        raise HTTPException(
            status_code=422,
            detail="Pet item listings require an item name and description.",
        )

    try:
        suitable_for_values = json.loads(suitable_for)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=422,
            detail="Eligible target animals must be a JSON list.",
        ) from error
    if not isinstance(suitable_for_values, list) or any(
        value not in {"Dog", "Cat", "Other"} for value in suitable_for_values
    ):
        raise HTTPException(
            status_code=422,
            detail="Target animals must be Dog, Cat, or Other.",
        )
    if listing_type in {"food", "other"} and not suitable_for_values:
        raise HTTPException(
            status_code=422,
            detail="Select at least one animal that can use/eat this item.",
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
                extension = ".jpg"
            filename = f"{uuid.uuid4().hex}{extension}"
            destination = os.path.join(UPLOAD_DIR, filename)
            with open(destination, "xb") as output:
                output.write(contents)
            saved_paths.append(destination)
            image_urls.append(f"/seller/media/{filename}")

        if listing_type == "food":
            listing_name = f"{brand} food" if not name else name
            pet_type = ", ".join(suitable_for_values)
        elif listing_type == "pets":
            listing_name = f"{animal_type} - {breed}"
            pet_type = animal_type
        else:
            listing_name = name
            pet_type = ", ".join(suitable_for_values) if suitable_for_values else "Other"

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
                "stock_quantity": stock_quantity,
                "category_id": 1,
                "pet_type": pet_type,
                "description": description,
                "image_url": image_urls[0],
                "image_urls": image_urls,
                "has_health_issue": has_health_issue,
                "health_issue": health_issue,
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
