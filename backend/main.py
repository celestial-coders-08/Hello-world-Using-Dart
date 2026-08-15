"""
PawStay FastAPI Backend — main entry point.

Run with:
    python main.py

Endpoints:
    POST /signup        — register user, send OTP
    POST /verify-otp    — confirm OTP, activate account
    POST /resend-otp    — resend a fresh OTP

Security notes:
  • All DB access goes through SQLAlchemy ORM (parameterized) → no SQL injection
  • Unique username/email enforced at DB column level
  • All secrets loaded from .env
"""

import os
import sys

# Allow imports from backend root when running `python main.py` directly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import uvicorn
from fastapi import FastAPI, Depends, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session
from dotenv import load_dotenv

from database.db import get_db, engine
from database.models import Base, User, OtpCode
from Email_Veriication.otp_service import (
    generate_otp,
    save_otp,
    verify_otp as _verify_otp,
    send_otp_email,
    send_support_email,
)

load_dotenv()

# ---------------------------------------------------------------------------
# Create tables on startup (idempotent — safe to call every time)
# ---------------------------------------------------------------------------
Base.metadata.create_all(bind=engine)


def ensure_sqlite_schema_compatibility() -> None:
    """
    Keep the existing SQLite database file compatible with current ORM columns.
    """
    if engine.dialect.name != "sqlite":
        return

    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    with engine.begin() as connection:
        existing_columns = {column["name"] for column in inspector.get_columns("users")}
        if "phone_number" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN phone_number VARCHAR(20)"))
        if "profile_image" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN profile_image TEXT"))


ensure_sqlite_schema_compatibility()

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="PawStay API",
    description="Backend API for PawStay pet services platform",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Request / Response schemas (Pydantic validates input automatically)
# ---------------------------------------------------------------------------

class SignupRequest(BaseModel):
    full_name:   str
    username:    str
    email:       EmailStr
    password:    str = "Password123"
    state:       str
    city:        str
    postal_code: str
    role:        str = "User"

    @field_validator("username")
    @classmethod
    def username_alphanumeric(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Username must be at least 3 characters.")
        if not v.replace("_", "").replace(".", "").isalnum():
            raise ValueError("Username may only contain letters, digits, underscores, and dots.")
        return v

    @field_validator("postal_code")
    @classmethod
    def postal_digits(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit():
            raise ValueError("Postal code must contain digits only.")
        if len(v) < 4 or len(v) > 10:
            raise ValueError("Postal code must be between 4 and 10 digits.")
        return v

    @field_validator("full_name", "state", "city", "role")
    @classmethod
    def not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("This field cannot be empty.")
        return v


class LoginRequest(BaseModel):
    email_or_username: str
    password:          str


class OtpVerifyRequest(BaseModel):
    email: EmailStr
    otp:   str


class ResendOtpRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email:        EmailStr
    phone_number: str


class ResetPasswordRequest(BaseModel):
    email:        EmailStr
    otp:          str
    new_password: str


class ProfileResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: str
    role: str
    is_verified: bool
    profile_image: str | None = None


class UpdateProfilePhotoRequest(BaseModel):
    lookup: str
    profile_image: str


class DeleteAccountRequest(BaseModel):
    lookup: str
    password: str


class ContactRequest(BaseModel):
    full_name: str
    email: EmailStr
    message: str


class MessageResponse(BaseModel):
    success: bool
    message: str


def get_user_by_lookup(db: Session, lookup: str) -> User | None:
    lookup_value = lookup.strip()
    if not lookup_value:
        return None
    if "@" in lookup_value:
        lookup_value = lookup_value.lower()
    return (
        db.query(User)
        .filter((User.email == lookup_value) | (User.username == lookup_value))
        .first()
    )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "PawStay API"}


@app.get("/check-username", response_model=MessageResponse, tags=["Auth"])
def check_username(username: str, db: Session = Depends(get_db)):
    """
    Check if a username is available.
    Returns success=True if the username is free, success=False if taken.
    """
    username = username.strip()
    if len(username) < 3:
        return MessageResponse(success=False, message="Username must be at least 3 characters.")
    existing = db.query(User).filter(User.username == username).first()
    if existing:
        return MessageResponse(success=False, message="Username is already taken.")
    return MessageResponse(success=True, message="Username is available.")


@app.post("/signup", response_model=MessageResponse, tags=["Auth"])
def signup(payload: SignupRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """
    Register a new user.
    OTP email is sent in the background so the response returns immediately.
    Returns 409 if email or username is already taken.
    """
    # Check for duplicate email — ORM query, fully parameterized
    existing_email = (
        db.query(User).filter(User.email == payload.email).first()
    )
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    # Check for duplicate username
    existing_username = (
        db.query(User).filter(User.username == payload.username).first()
    )
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken. Please choose another.",
        )

    # Create an unverified user record
    new_user = User(
        full_name=payload.full_name,
        username=payload.username,
        email=str(payload.email),
        state=payload.state,
        city=payload.city,
        postal_code=payload.postal_code,
        role=payload.role,
        is_verified=False,
    )

    new_user.set_password(payload.password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Generate and persist OTP, schedule email in the background
    otp_code = generate_otp(4)
    save_otp(db, str(payload.email), otp_code)

    # Send email in background — endpoint returns immediately without waiting for SMTP
    background_tasks.add_task(
        send_otp_email, str(payload.email), otp_code, payload.full_name
    )

    return MessageResponse(
        success=True,
        message=f"Account created. A verification code has been sent to {payload.email}.",
    )


@app.post("/login", response_model=MessageResponse, tags=["Auth"])
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate user with email or username and password.
    Requires account to be verified via OTP.
    """
    identifier = payload.email_or_username.strip()
    user = get_user_by_lookup(db, identifier)

    if not user or not user.check_password(payload.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/username or password.",
        )

    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account unverified. Please verify your email with the OTP code first.",
        )

    return MessageResponse(
        success=True,
        message=f"Login successful! Welcome back, {user.full_name}.",
    )


@app.get("/profile", response_model=ProfileResponse, tags=["Profile"])
def get_profile(lookup: str, db: Session = Depends(get_db)):
    user = get_user_by_lookup(db, lookup)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    return ProfileResponse(
        id=user.id,
        full_name=user.full_name,
        username=user.username,
        email=user.email,
        role=user.role,
        is_verified=user.is_verified,
        profile_image=user.profile_image,
    )


@app.post("/profile/photo", response_model=MessageResponse, tags=["Profile"])
def update_profile_photo(payload: UpdateProfilePhotoRequest, db: Session = Depends(get_db)):
    user = get_user_by_lookup(db, payload.lookup)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    user.profile_image = payload.profile_image.strip() or None
    db.commit()

    return MessageResponse(success=True, message="Profile photo updated successfully.")


@app.post("/delete-account", response_model=MessageResponse, tags=["Profile"])
def delete_account(payload: DeleteAccountRequest, db: Session = Depends(get_db)):
    """
    Delete a user account permanently.
    Deletes the user record, their OTP records, and clears their profile image.
    Returns 404 if user not found, 401 if password is incorrect.
    """
    user = get_user_by_lookup(db, payload.lookup)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    if not user.check_password(payload.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password. Please try again.",
        )

    try:
        # Delete OTP records associated with the user's email
        db.query(OtpCode).filter(OtpCode.email == user.email).delete(synchronize_session=False)
        db.flush()
        # Clear profile image reference (removes from database storage)
        user.profile_image = None
        # Delete user record
        db.delete(user)
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[ERROR] Delete account error for {user.email}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete account: {str(e)}",
        )

    return MessageResponse(success=True, message="Account deleted successfully.")



@app.post("/verify-otp", response_model=MessageResponse, tags=["Auth"])
def verify_otp(payload: OtpVerifyRequest, db: Session = Depends(get_db)):
    """
    Verify the OTP code for the given email.
    Marks the user account as verified on success.
    """
    success, message = _verify_otp(db, str(payload.email), payload.otp)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        )

    # Activate the user account
    user = db.query(User).filter(User.email == str(payload.email)).first()
    if user:
        user.is_verified = True
        db.commit()

    return MessageResponse(success=True, message=message)


@app.post("/resend-otp", response_model=MessageResponse, tags=["Auth"])
def resend_otp(payload: ResendOtpRequest, db: Session = Depends(get_db)):
    """
    Regenerate and resend a fresh OTP to the given email.
    Returns 404 if the email has not been registered yet.
    """
    user = db.query(User).filter(User.email == str(payload.email)).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this email. Please sign up first.",
        )

    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This account is already verified.",
        )

    otp_code = generate_otp(4)
    save_otp(db, str(payload.email), otp_code)
    sent = send_otp_email(str(payload.email), otp_code, user.full_name)

    if not sent:
        print(f"[WARN] Resend OTP email failed for {payload.email}. OTP: {otp_code}")

    return MessageResponse(
        success=True,
        message="A new verification code has been sent to your email.",
    )


@app.post("/forgot-password", response_model=MessageResponse, tags=["Auth"])
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """
    Request password reset OTP by providing email and phone number.
    Validates user identity and dispatches OTP code.
    """
    email_str = str(payload.email).strip()
    phone_str = payload.phone_number.strip()

    user = db.query(User).filter(User.email == email_str).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this email address.",
        )

    # Validate phone match if registered phone exists
    if user.phone_number and user.phone_number.strip() != phone_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The phone number does not match our records for this account.",
        )

    otp_code = generate_otp(4)
    save_otp(db, email_str, otp_code)
    sent = send_otp_email(email_str, otp_code, user.full_name)

    if not sent:
        print(f"[WARN] Forgot Password OTP email failed for {email_str}. OTP: {otp_code}")

    return MessageResponse(
        success=True,
        message=f"Password reset verification code sent to {email_str} and {phone_str}.",
    )


@app.post("/reset-password", response_model=MessageResponse, tags=["Auth"])
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Reset user password after OTP verification.
    """
    email_str = str(payload.email).strip()
    success, message = _verify_otp(db, email_str, payload.otp)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        )

    user = db.query(User).filter(User.email == email_str).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    user.set_password(payload.new_password)
    user.is_verified = True  # Ensure account is active after successful password reset
    db.commit()

    return MessageResponse(
        success=True,
        message="Password has been successfully reset! You can now log in with your new password.",
    )


@app.post("/contact", response_model=MessageResponse, tags=["Support"])
def contact_support(payload: ContactRequest):
    """
    Send a support message directly to the PawStay support inbox.
    No data is stored in the database — pure email forward.
    """
    full_name = payload.full_name.strip()
    email_str = str(payload.email).strip()
    message   = payload.message.strip()

    if not full_name or not message:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Full name and message are required.",
        )

    sent = send_support_email(full_name, email_str, message)

    if not sent:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to send your message. Please try again later.",
        )

    return MessageResponse(
        success=True,
        message="Your message has been sent! Our team will get back to you shortly.",
    )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
