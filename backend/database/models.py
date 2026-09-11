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
    walking_charge = Column(Integer, nullable=True)
    daycare_charge = Column(Integer, nullable=True)
    daycare_food_charge = Column(Integer, nullable=True)
    provider_description = Column(Text, nullable=True)

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
