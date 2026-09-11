"""PawStay provider API with isolated provider profile storage."""

import os
import sys


BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator

from service_provider.provider_db import get_profile, update_profile, update_status

app = FastAPI(
    title="PawStay Service Provider API",
    description="Provider-only API backed by service_provider/provider.db",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ProviderProfileRequest(BaseModel):
    lookup: str
    walking_charge: int
    daycare_charge: int
    daycare_food_charge: int
    provider_description: str

    @field_validator("walking_charge", "daycare_charge", "daycare_food_charge")
    @classmethod
    def positive_charge(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("Charges must be greater than zero.")
        return value

    @field_validator("provider_description")
    @classmethod
    def non_empty_description(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Description cannot be empty.")
        return value


class ProviderStatusRequest(BaseModel):
    lookup: str | None = None
    provider_lookup: str | None = None
    is_online: bool


@app.get("/")
def health_check():
    return {"status": "ok", "service": "PawStay provider API"}


@app.get("/provider/profile")
def read_provider_profile(lookup: str):
    if not lookup.strip():
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    profile = get_profile(lookup)
    return {
        **profile,
        "is_complete": all(
            profile[key] is not None
            for key in (
                "walking_charge",
                "daycare_charge",
                "daycare_food_charge",
                "provider_description",
            )
        ),
    }


@app.put("/provider/profile")
def save_provider_profile(payload: ProviderProfileRequest):
    if not payload.lookup.strip():
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    profile = update_profile(payload.lookup, payload.model_dump())
    return {"success": True, "profile": profile}


@app.patch("/provider/status")
def save_provider_status(payload: ProviderStatusRequest):
    lookup = payload.lookup or payload.provider_lookup
    if not lookup:
        raise HTTPException(status_code=400, detail="Provider lookup is required.")
    update_status(lookup, payload.is_online)
    return {"success": True, "is_online": payload.is_online}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)


