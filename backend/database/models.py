"""
SQLAlchemy ORM models for PawStay database.
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from .db import Base
import hashlib
import os

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String(100), nullable=False)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(120), unique=True, index=True, nullable=False)
    phone_number = Column(String(20), nullable=True)  # Phone number for OTP & account lookup
    profile_image = Column(Text, nullable=True)
    password_hash = Column(String(255), nullable=True)  # Populated during signup/login
    bio = Column(String(500), nullable=True)
    experience_years = Column(Integer, default=0, nullable=True)
    pet_types = Column(Text, default="[]", nullable=True)
    sitter_enabled = Column(Boolean, default=False, nullable=True)
    sitter_price = Column(Integer, nullable=True)
    sitter_duration_mins = Column(Integer, default=60, nullable=True)

    state = Column(String(100), nullable=False)
    city = Column(String(100), nullable=False)
    postal_code = Column(String(20), nullable=False)
    role = Column(String(50), default="User", nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def set_password(self, password: str):
        salt = os.urandom(16)
        pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
        self.password_hash = f"{salt.hex()}:{pwd_hash.hex()}"


    def check_password(self, password: str) -> bool:
        if not self.password_hash or ":" not in self.password_hash:
            return False
        try:
            salt_hex, hash_hex = self.password_hash.split(":", 1)
            salt = bytes.fromhex(salt_hex)
            expected_hash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000).hex()
            return expected_hash == hash_hex
        except Exception:
            return False


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(120), index=True, nullable=False)
    code = Column(String(10), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(120), index=True, nullable=False)
    token = Column(String(64), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Pet(Base):
    __tablename__ = "pets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(120), index=True, nullable=False)
    name = Column(String(100), nullable=False)
    type = Column(String(50), nullable=False)
    age = Column(Integer, default=1, nullable=False)
    dietary_preferences = Column(Text, nullable=True)
    health_status = Column(Text, nullable=True)
    profile_image = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Review(Base):
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    provider_lookup = Column(String(120), index=True, nullable=False)
    user_lookup = Column(String(120), index=True, nullable=False)
    rating = Column(Integer, nullable=False)
    description = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ProviderPackage(Base):
    __tablename__ = "provider_packages"

    id = Column(Integer, primary_key=True, index=True)
    provider_lookup = Column(String(120), index=True, nullable=False)
    tier = Column(String(20), nullable=False)  # bronze, silver, gold
    enabled = Column(Boolean, default=False, nullable=False)
    price = Column(Integer, default=0, nullable=False)
    duration_value = Column(Integer, default=1, nullable=False)
    duration_unit = Column(String(20), default="hours", nullable=False)  # hours, days
    meals_per_day = Column(Integer, default=0, nullable=False)
    walks_per_day = Column(Integer, default=0, nullable=False)
    inclusions = Column(Text, default="[]", nullable=False)
    description = Column(Text, default="", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    provider_id = Column(String(120), index=True, nullable=True)
    customer_id = Column(String(120), index=True, nullable=True)
    provider_lookup = Column(String(120), index=True, nullable=True)
    customer_lookup = Column(String(120), index=True, nullable=True)
    service_type = Column(String(50), nullable=False)  # sitter, package
    package_id = Column(Integer, nullable=True)
    tier = Column(String(20), nullable=True)
    price_snapshot = Column(Integer, nullable=False)
    start_datetime = Column(String(100), nullable=True)
    end_datetime = Column(String(100), nullable=True)
    pet_name = Column(String(100), nullable=True)
    pet_type = Column(String(50), nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(String(50), default="pending", nullable=False)  # pending, accepted, declined, completed, cancelled
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    recipient_id = Column(String(120), index=True, nullable=False)
    recipient_role = Column(String(50), nullable=True)  # provider, customer
    type = Column(String(50), default="new_booking", nullable=False)
    booking_id = Column(Integer, nullable=True)
    title = Column(String(150), nullable=True)
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

