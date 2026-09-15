from service_provider.provider_db import delete_profile
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

import uuid
import uvicorn
from fastapi import FastAPI, Depends, HTTPException, status, BackgroundTasks, Request, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import func, inspect, text
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from datetime import datetime, timedelta

from database.db import get_db, engine
from database.models import Base, User, OtpCode, Pet, PasswordResetToken, Review
from Email_Veriication.otp_service import (
    generate_otp,
    save_otp,
    verify_otp as _verify_otp,
    send_otp_email,
    send_support_email,
    send_password_reset_email,
)
from service_provider.provider_db import get_profile as get_provider_db_profile

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
        if "walking_charge" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN walking_charge INTEGER"))
        if "daycare_charge" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN daycare_charge INTEGER"))
        if "daycare_food_charge" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN daycare_food_charge INTEGER"))
        if "provider_description" not in existing_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN provider_description TEXT"))

    # Create password_reset_tokens table if it doesn't exist yet
    # (SQLAlchemy Base.metadata.create_all handles new tables; this is a safety belt)
    Base.metadata.create_all(bind=engine)


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
    full_name:    str
    username:     str
    email:        EmailStr
    phone_number: str | None = None
    password:     str = "Password123"
    state:        str
    city:         str
    postal_code:  str
    role:         str = "User"

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
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str
    confirm_password: str


class ProfileResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: str
    role: str
    is_verified: bool
    profile_image: str | None = None


class ChatCandidateResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: str
    role: str
    city: str
    is_verified: bool
    profile_image: str | None = None


class PetWalkingProviderResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: str
    role: str
    city: str
    is_verified: bool
    profile_image: str | None = None
    distance: str = "Nearby"
    service: str = "Pet Walker"
    walking_charge: int | None = None
    daycare_charge: int | None = None
    daycare_food_charge: int | None = None
    provider_description: str | None = None
    is_online: bool = True
    average_rating: float = 0
    review_count: int = 0


class ReviewRequest(BaseModel):
    provider_lookup: str
    user_lookup: str
    rating: int
    description: str

    @field_validator("provider_lookup", "user_lookup", "description")
    @classmethod
    def required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be empty.")
        return value

    @field_validator("rating")
    @classmethod
    def valid_rating(cls, value: int) -> int:
        if value < 1 or value > 5:
            raise ValueError("Rating must be between 1 and 5.")
        return value


class UpdateProfilePhotoRequest(BaseModel):
    lookup: str
    profile_image: str


class ProviderProfileRequest(BaseModel):
    lookup: str
    walking_charge: int
    daycare_charge: int
    daycare_food_charge: int
    provider_description: str

    @field_validator("walking_charge", "daycare_charge", "daycare_food_charge")
    @classmethod
    def charges_must_be_positive(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("Charges must be greater than zero.")
        return value

    @field_validator("provider_description")
    @classmethod
    def description_must_not_be_empty(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Description cannot be empty.")
        return value


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


class PetCreateRequest(BaseModel):
    user_id: str
    name: str
    type: str
    age: int = 1
    dietary_preferences: str = ""
    health_status: str = ""
    profile_image: str | None = None


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
        phone_number=payload.phone_number,
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


@app.get("/provider/profile", tags=["Provider"])
def get_provider_profile(lookup: str, db: Session = Depends(get_db)):
    user = get_user_by_lookup(db, lookup)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Provider profile not found.",
        )

    average_rating, review_count = db.query(
        func.coalesce(func.avg(Review.rating), 0), func.count(Review.id)
    ).filter(Review.provider_lookup == user.username).first()

    return {
        "id": user.id,
        "full_name": user.full_name,
        "username": user.username,
        "email": user.email,
        "walking_charge": user.walking_charge,
        "daycare_charge": user.daycare_charge,
        "daycare_food_charge": user.daycare_food_charge,
        "provider_description": user.provider_description,
        "average_rating": round(float(average_rating or 0), 1),
        "review_count": int(review_count or 0),
        "is_complete": all(
            value is not None
            for value in (
                user.walking_charge,
                user.daycare_charge,
                user.daycare_food_charge,
                user.provider_description,
            )
        ),
    }


@app.put("/provider/profile", tags=["Provider"])
def update_provider_profile(
    payload: ProviderProfileRequest,
    db: Session = Depends(get_db),
):
    user = get_user_by_lookup(db, payload.lookup)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Provider profile not found.",
        )

    user.walking_charge = payload.walking_charge
    user.daycare_charge = payload.daycare_charge
    user.daycare_food_charge = payload.daycare_food_charge
    user.provider_description = payload.provider_description
    db.commit()

    return {"success": True, "message": "Provider profile saved successfully."}


@app.post("/reviews", tags=["Reviews"])
def submit_review(payload: ReviewRequest, db: Session = Depends(get_db)):
    provider = get_user_by_lookup(db, payload.provider_lookup)
    user = get_user_by_lookup(db, payload.user_lookup)
    if not provider or not user:
        raise HTTPException(status_code=404, detail="User or provider not found.")
    review = Review(
        provider_lookup=provider.username,
        user_lookup=user.username,
        rating=payload.rating,
        description=payload.description,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return {"success": True, "id": review.id}


@app.get("/reviews", tags=["Reviews"])
def get_provider_reviews(provider_lookup: str, db: Session = Depends(get_db)):
    provider = get_user_by_lookup(db, provider_lookup)
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found.")
    reviews = db.query(Review).filter(
        Review.provider_lookup == provider.username
    ).order_by(Review.created_at.desc()).all()
    response = []
    for review in reviews:
        reviewer = get_user_by_lookup(db, review.user_lookup)
        response.append(
            {
                "id": review.id,
                "rating": review.rating,
                "description": review.description,
                "user_lookup": review.user_lookup,
                "user_name": (
                    reviewer.full_name
                    if reviewer and reviewer.full_name
                    else review.user_lookup
                ),
                "created_at": review.created_at.isoformat(),
            }
        )
    return response


@app.get("/users/search", response_model=list[ProfileResponse], tags=["Profile"])
def search_users(q: str = "", db: Session = Depends(get_db)):
    """
    Search users globally by name or username. 
    Only returns users who have the role: Seller, Service provider, or Doctor.
    """
    q_str = q.strip()
    allowed_roles = ["Seller", "Service provider", "Doctor"]
    
    query = db.query(User).filter(User.role.in_(allowed_roles))
    if q_str:
        query = query.filter(
            (User.full_name.ilike(f"%{q_str}%")) | 
            (User.username.ilike(f"%{q_str}%"))
        )
        
    users = query.all()
    return [
        ProfileResponse(
            id=u.id,
            full_name=u.full_name,
            username=u.username,
            email=u.email,
            role=u.role,
            is_verified=u.is_verified,
            profile_image=u.profile_image
        ) for u in users
    ]


@app.get("/users/chat-candidates", response_model=list[ChatCandidateResponse], tags=["Profile"])
def get_chat_candidates(user_id: str = "", db: Session = Depends(get_db)):
    """
    Get service providers and sellers,
    filtered based on the user's city only.
    """
    user_id_str = user_id.strip()
    current_user = get_user_by_lookup(db, user_id_str) if user_id_str else None
    
    allowed_roles = ["Service provider", "Pet Service", "Seller"]
    
    query = db.query(User).filter(User.role.in_(allowed_roles))
    
    if current_user and current_user.city:
        query = query.filter(User.city.ilike(current_user.city.strip()))
        query = query.filter(User.id != current_user.id)
    elif current_user:
        query = query.filter(User.id != current_user.id)
        
    candidates = query.all()
    
    if not candidates and current_user:
        candidates = db.query(User).filter(User.role.in_(allowed_roles), User.id != current_user.id).all()
    elif not candidates and not current_user:
        candidates = db.query(User).filter(User.role.in_(allowed_roles)).all()
        
    return [
        ChatCandidateResponse(
            id=u.id,
            full_name=u.full_name,
            username=u.username,
            email=u.email,
            role=u.role,
            city=u.city or "",
            is_verified=u.is_verified,
            profile_image=u.profile_image
        ) for u in candidates
    ]


@app.get(
    "/service-providers/pet-walking",
    response_model=list[PetWalkingProviderResponse],
    tags=["Services"],
)
def get_pet_walking_providers(user_id: str = "", db: Session = Depends(get_db)):
    """Return pet-service providers available for pet walking from the database."""
    current_user = get_user_by_lookup(db, user_id) if user_id.strip() else None
    
    # Query users whose role matches service provider roles
    provider_roles = ["Pet Service", "Service provider", "Walker"]

    query = db.query(User).filter(
        User.role.in_(provider_roles)
    )

    if current_user:
        query = query.filter(User.id != current_user.id)

    providers = query.order_by(User.full_name.asc()).all()

    # Fallback to all users with role 'Service provider' if query is empty
    if not providers:
        providers = db.query(User).filter(
            (User.role.ilike("%Service%")) | (User.role.ilike("%Walker%"))
        ).all()

    default_services = ["Active Walk", "Professional Sitter", "Weekend Walker", "Active Walk", "Pet Care & Walking"]
    default_distances = ["2 miles away", "5 miles away", "1.5 miles away", "3 miles away", "4 miles away"]

    result = []
    for idx, provider in enumerate(providers):
        provider_profile = get_provider_db_profile(provider.username)
        average_rating, review_count = db.query(
            func.coalesce(func.avg(Review.rating), 0), func.count(Review.id)
        ).filter(Review.provider_lookup == provider.username).first()
        if (
            provider_profile["walking_charge"] is None
            and provider.email
            and provider.email != provider.username
        ):
            email_profile = get_provider_db_profile(provider.email)
            if email_profile["walking_charge"] is not None:
                provider_profile = email_profile
        if not provider_profile["is_online"]:
            continue

        service_title = default_services[idx % len(default_services)]
        distance_str = default_distances[idx % len(default_distances)]
        
        result.append(
            PetWalkingProviderResponse(
                id=provider.id,
                full_name=provider.full_name,
                username=provider.username,
                email=provider.email,
                role=provider.role,
                city=provider.city or "",
                is_verified=provider.is_verified,
                profile_image=provider.profile_image,
                distance=distance_str,
                service=service_title,
                walking_charge=provider_profile["walking_charge"],
                daycare_charge=provider_profile["daycare_charge"],
                daycare_food_charge=provider_profile["daycare_food_charge"],
                provider_description=provider_profile["provider_description"],
                is_online=bool(provider_profile["is_online"]),
                average_rating=round(float(average_rating or 0), 1),
                review_count=int(review_count or 0),
            )
        )

    return result



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
        delete_profile(payload.lookup)
        delete_profile(user.username)
        delete_profile(user.email)
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
def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    Send a 4-digit OTP code to the user's email for password reset.
    """
    email_str = str(payload.email).strip().lower()
    user = db.query(User).filter(User.email == email_str).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this email address.",
        )

    otp_code = generate_otp(4)
    save_otp(db, email_str, otp_code)
    background_tasks.add_task(send_otp_email, email_str, otp_code, user.full_name)

    return MessageResponse(
        success=True,
        message=f"An OTP verification code has been sent to {email_str}.",
    )


@app.post("/reset-password", response_model=MessageResponse, tags=["Auth"])
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Reset user password after OTP verification.
    """
    email_str = str(payload.email).strip().lower()
    new_pwd = payload.new_password.strip()
    confirm_pwd = payload.confirm_password.strip()

    if len(new_pwd) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 6 characters long.",
        )

    if new_pwd != confirm_pwd:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passwords do not match.",
        )

    user = db.query(User).filter(User.email == email_str).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found.",
        )

    user.set_password(new_pwd)
    user.is_verified = True
    db.commit()

    return MessageResponse(
        success=True,
        message="Your password has been successfully reset! You can now log in.",
    )


_RESET_PAGE_STYLE = """
  body{margin:0;padding:0;background:#FFF8F4;font-family:'Segoe UI',Arial,sans-serif;}
  .card{max-width:460px;margin:60px auto;background:#fff;border-radius:16px;
        box-shadow:0 4px 24px rgba(74,68,63,.10);overflow:hidden;}
  .header{background:#99462A;padding:24px 32px;}
  .header h1{margin:0;color:#fff;font-size:20px;font-weight:700;}  
  .body{padding:32px;}
  label{display:block;color:#55433D;font-size:14px;font-weight:600;margin-bottom:6px;}
  input[type=password]{width:100%;box-sizing:border-box;border:1.5px solid #E0D5CF;
    border-radius:10px;padding:12px 14px;font-size:15px;color:#1F1B17;
    background:#FDFAF8;outline:none;margin-bottom:18px;}
  input[type=password]:focus{border-color:#99462A;}
  button{width:100%;background:#99462A;color:#fff;border:none;border-radius:10px;
    padding:14px;font-size:16px;font-weight:700;cursor:pointer;letter-spacing:0.3px;}
  button:hover{background:#7A3520;}
  .msg-ok{background:#E6F9EE;color:#1A7A42;border-radius:10px;padding:16px 20px;
    font-size:15px;font-weight:600;text-align:center;margin-top:8px;}
  .msg-err{background:#FDE8E8;color:#C0392B;border-radius:10px;padding:16px 20px;
    font-size:15px;font-weight:600;text-align:center;margin-top:8px;}
  .footer{background:#F6ECE5;padding:14px 32px;text-align:center;
    color:#88726C;font-size:12px;}
"""


@app.get("/reset-password-page", tags=["Auth"], response_class=None)
def reset_password_page(token: str = "", db: Session = Depends(get_db)):
    """
    Serve an HTML form for the user to enter their new password.
    Token validity is pre-checked here to show an error early.
    """

    if not token:
        html = f"""<html><head><style>{_RESET_PAGE_STYLE}</style></head>
        <body><div class='card'><div class='header'><h1>🐾 PawStay</h1></div>
        <div class='body'><div class='msg-err'>Invalid or missing reset link. Please request a new one from the app.</div></div>
        <div class='footer'>&copy; 2026 PawStay</div></div></body></html>"""
        return HTMLResponse(content=html, status_code=400)

    record = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == token,
        PasswordResetToken.is_used == False,  # noqa: E712
    ).first()

    if not record or datetime.utcnow() > record.expires_at:
        html = f"""<html><head><style>{_RESET_PAGE_STYLE}</style></head>
        <body><div class='card'><div class='header'><h1>🐾 PawStay</h1></div>
        <div class='body'><div class='msg-err'>This reset link has expired or already been used.<br>Please request a new one from the app.</div></div>
        <div class='footer'>&copy; 2026 PawStay</div></div></body></html>"""
        return HTMLResponse(content=html, status_code=400)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Reset Password — PawStay</title>
  <style>{_RESET_PAGE_STYLE}</style>
</head>
<body>
  <div class="card">
    <div class="header"><h1>🐾 PawStay &mdash; Reset Password</h1></div>
    <div class="body">
      <p style="color:#55433D;font-size:15px;margin:0 0 24px;line-height:1.6;">
        Enter your new password below. It must be at least 6 characters.
      </p>
      <form id="resetForm">
        <label for="np">New Password</label>
        <input type="password" id="np" name="new_password" placeholder="&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;" minlength="6" required>
        <label for="cp">Confirm Password</label>
        <input type="password" id="cp" name="confirm_password" placeholder="&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;" minlength="6" required>
        <button type="submit">Reset Password &rarr;</button>
      </form>
      <div id="msg"></div>
    </div>
    <div class="footer">&copy; 2026 PawStay. All rights reserved.</div>
  </div>
  <script>
    document.getElementById('resetForm').addEventListener('submit', async function(e) {{
      e.preventDefault();
      const np = document.getElementById('np').value;
      const cp = document.getElementById('cp').value;
      const msgEl = document.getElementById('msg');
      if (np.length < 6) {{ msgEl.innerHTML = "<div class='msg-err'>Password must be at least 6 characters.</div>"; return; }}
      if (np !== cp)     {{ msgEl.innerHTML = "<div class='msg-err'>Passwords do not match.</div>"; return; }}
      try {{
        const res = await fetch('/reset-password-web', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          body: JSON.stringify({{token: '{token}', new_password: np, confirm_password: cp}})
        }});
        const data = await res.json();
        if (res.ok) {{
          document.getElementById('resetForm').style.display = 'none';
          msgEl.innerHTML = "<div class='msg-ok'>✅ Password reset successfully!<br>You can now log in to the PawStay app with your new password.</div>";
        }} else {{
          msgEl.innerHTML = "<div class='msg-err'>" + (data.detail || 'Something went wrong.') + "</div>";
        }}
      }} catch(err) {{
        msgEl.innerHTML = "<div class='msg-err'>Connection error. Please try again.</div>";
      }}
    }});
  </script>
</body>
</html>"""
    return HTMLResponse(content=html)


@app.post("/reset-password-web", tags=["Auth"])
async def reset_password_web(
    request: Request,
    token: str = Form(None),
    new_password: str = Form(None),
    confirm_password: str = Form(None),
    db: Session = Depends(get_db),
):
    """
    Validate the reset token and update the password.
    Supports both HTML form submissions (from email form) and JSON POST requests.
    """
    content_type = request.headers.get("content-type", "")
    is_json = "application/json" in content_type

    if is_json:
        try:
            payload = await request.json()
        except Exception:
            payload = {}
        token = (payload.get("token") or "").strip()
        new_password = (payload.get("new_password") or "").strip()
        confirm_pwd = (payload.get("confirm_password") or "").strip()
    else:
        token = (token or "").strip()
        new_password = (new_password or "").strip()
        confirm_pwd = (confirm_password or "").strip()

    def respond_error(msg: str, status_code: int = 400):
        if is_json:
            raise HTTPException(status_code=status_code, detail=msg)
        html = f"""<!DOCTYPE html>
<html><head><title>Reset Password — PawStay</title><style>{_RESET_PAGE_STYLE}</style></head>
<body><div class='card'><div class='header'><h1>🐾 PawStay &mdash; Reset Password</h1></div>
<div class='body'><div class='msg-err'>{msg}</div></div>
<div class='footer'>&copy; 2026 PawStay. All rights reserved.</div></div></body></html>"""
        return HTMLResponse(content=html, status_code=status_code)

    if not token:
        return respond_error("Missing password reset token.", 400)
    if len(new_password) < 6:
        return respond_error("Password must be at least 6 characters.", 400)
    if new_password != confirm_pwd:
        return respond_error("Passwords do not match.", 400)

    record = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == token,
        PasswordResetToken.is_used == False,  # noqa: E712
    ).first()

    if not record:
        return respond_error("Invalid or already-used reset link/token.", 400)

    if datetime.utcnow() > record.expires_at:
        record.is_used = True
        db.commit()
        return respond_error("This password reset request has expired. Please request a new reset email from the app.", 400)

    user = db.query(User).filter(User.email == record.email).first()
    if not user:
        return respond_error("User account not found.", 404)

    user.set_password(new_password)
    user.is_verified = True  # Ensure account is active
    record.is_used = True
    db.commit()

    if is_json:
        return MessageResponse(
            success=True,
            message="Password has been successfully reset! You can now log in with your new password.",
        )

    success_html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Reset Password — PawStay</title>
  <style>{_RESET_PAGE_STYLE}</style>
</head>
<body>
  <div class="card">
    <div class="header"><h1>🐾 PawStay &mdash; Password Reset Success</h1></div>
    <div class="body">
      <div class="msg-ok">
        <div style="font-size:36px;margin-bottom:12px;">✅</div>
        <strong>Password Reset Successfully!</strong><br><br>
        Your password has been updated. You can now open the <strong>PawStay</strong> mobile app and log in with your new password.
      </div>
    </div>
    <div class="footer">&copy; 2026 PawStay. All rights reserved.</div>
  </div>
</body>
</html>"""
    return HTMLResponse(content=success_html)


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


@app.post("/pets", response_model=MessageResponse, status_code=status.HTTP_201_CREATED, tags=["Pets"])
def create_pet(payload: PetCreateRequest, db: Session = Depends(get_db)):
    """
    Save a new pet profile or update if one exists for this user_id.
    """
    existing = db.query(Pet).filter(Pet.user_id == payload.user_id).first()
    
    if existing:
        existing.name = payload.name
        existing.type = payload.type
        existing.age = payload.age
        existing.dietary_preferences = payload.dietary_preferences
        existing.health_status = payload.health_status
        if payload.profile_image is not None:
            existing.profile_image = payload.profile_image
        db.commit()
        return MessageResponse(success=True, message="Pet profile updated successfully.")
        
    new_pet = Pet(
        user_id=payload.user_id,
        name=payload.name,
        type=payload.type,
        age=payload.age,
        dietary_preferences=payload.dietary_preferences,
        health_status=payload.health_status,
        profile_image=payload.profile_image,
    )
    db.add(new_pet)
    db.commit()
    
    return MessageResponse(
        success=True,
        message="Pet profile saved successfully."
    )


@app.get("/pets", tags=["Pets"])
def get_pets(user_id: str, db: Session = Depends(get_db)):
    """
    Get all pets for a specific user_id.
    """
    if not user_id.strip():
        return []
    pets = db.query(Pet).filter(Pet.user_id == user_id.strip()).all()
    result = []
    for p in pets:
        result.append({
            "id": p.id,
            "user_id": p.user_id,
            "name": p.name,
            "type": p.type,
            "age": p.age,
            "dietary_preferences": p.dietary_preferences or "",
            "health_status": p.health_status or "",
            "profile_image": p.profile_image or "",
        })
    return result


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
