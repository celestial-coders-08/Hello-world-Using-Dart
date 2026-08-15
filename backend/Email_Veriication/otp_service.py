"""
OTP service for PawStay e-mail verification.
  - Generates a cryptographically secure 4-digit OTP
  - Persists OTP to database with a 10-minute expiry
  - Sends the OTP via SMTP (credentials from .env)
  - Verifies the OTP (checks code, expiry, and single-use flag)
"""

import os
import random
import string
import smtplib
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from dotenv import load_dotenv
from sqlalchemy.orm import Session

# Models are imported lazily to avoid circular imports
load_dotenv()

SMTP_HOST       = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT       = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME   = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD   = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", "")
SMTP_FROM_NAME  = os.getenv("SMTP_FROM_NAME", "PawStay")

OTP_EXPIRY_MINUTES = 10


# ---------------------------------------------------------------------------
# OTP generation
# ---------------------------------------------------------------------------

def generate_otp(length: int = 4) -> str:
    """Return a secure numeric OTP string of the requested length."""
    return "".join(random.SystemRandom().choices(string.digits, k=length))


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def save_otp(db: Session, email: str, code: str) -> None:
    """
    Store a new OTP in the database.
    Any previous unused OTPs for this email are invalidated first.
    Uses the ORM — no raw SQL, no injection risk.
    """
    from database.models import OtpCode

    email = email.strip().lower()
    code = code.strip()

    # Invalidate all previous OTPs for this email
    (
        db.query(OtpCode)
        .filter(OtpCode.email == email, OtpCode.is_used == False)  # noqa: E712
        .update({"is_used": True})
    )

    otp_record = OtpCode(
        email=email,
        code=code,
        expires_at=datetime.utcnow() + timedelta(minutes=OTP_EXPIRY_MINUTES),
        is_used=False,
    )
    db.add(otp_record)
    db.commit()


def verify_otp(db: Session, email: str, code: str) -> tuple[bool, str]:
    """
    Verify the provided OTP for a given email.
    Returns (success: bool, message: str).
    Uses the ORM — parameterized, injection-proof.
    """
    from database.models import OtpCode

    email = email.strip().lower()
    code = code.strip()

    record = (
        db.query(OtpCode)
        .filter(
            OtpCode.email   == email,
            OtpCode.is_used == False,  # noqa: E712
        )
        .order_by(OtpCode.created_at.desc())
        .first()
    )

    if record is None:
        return False, "Invalid OTP. Please check the code and try again."

    if datetime.utcnow() > record.expires_at:
        record.is_used = True
        db.commit()
        return False, "OTP has expired. Please request a new one."

    if record.code != code:
        return False, "Invalid OTP. Please check the code and try again."

    # Mark as used so it cannot be replayed
    record.is_used = True
    db.commit()

    return True, "OTP verified successfully."


# ---------------------------------------------------------------------------
# Email sending — OTP
# ---------------------------------------------------------------------------

def send_otp_email(to_email: str, otp_code: str, user_name: str = "") -> bool:
    """
    Send the OTP to the user's email address.
    Returns True on success, False on failure.
    """
    subject = "Your PawStay Verification Code"

    greeting = f"Hi {user_name}," if user_name else "Hello,"

    html_body = f"""
    <html>
    <body style="margin:0;padding:0;background:#FFF8F4;font-family:'Segoe UI',Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#FFF8F4;padding:40px 0;">
        <tr>
          <td align="center">
            <table width="480" cellpadding="0" cellspacing="0"
                   style="background:#FFFFFF;border-radius:16px;box-shadow:0 4px 20px rgba(74,68,63,.08);overflow:hidden;">
              <!-- Header -->
              <tr>
                <td style="background:#99462A;padding:28px 36px;">
                  <h1 style="margin:0;color:#FFFFFF;font-size:22px;font-weight:700;letter-spacing:-0.5px;">
                    🐾 PawStay
                  </h1>
                </td>
              </tr>
              <!-- Body -->
              <tr>
                <td style="padding:36px;">
                  <p style="margin:0 0 12px;color:#1F1B17;font-size:16px;">{greeting}</p>
                  <p style="margin:0 0 28px;color:#55433D;font-size:15px;line-height:1.6;">
                    Use the code below to verify your PawStay account.
                    It is valid for <strong>{OTP_EXPIRY_MINUTES} minutes</strong>.
                  </p>
                  <!-- OTP Box -->
                  <div style="background:#F6ECE5;border-radius:12px;padding:24px;text-align:center;margin-bottom:28px;">
                    <span style="font-size:42px;font-weight:800;letter-spacing:14px;color:#99462A;">
                      {otp_code}
                    </span>
                  </div>
                  <p style="margin:0;color:#88726C;font-size:13px;line-height:1.5;">
                    If you did not create a PawStay account, you can safely ignore this email.
                  </p>
                </td>
              </tr>
              <!-- Footer -->
              <tr>
                <td style="background:#F6ECE5;padding:20px 36px;text-align:center;">
                  <p style="margin:0;color:#88726C;font-size:12px;">
                    &copy; 2026 PawStay. All rights reserved.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = f"{SMTP_FROM_NAME} <{SMTP_FROM_EMAIL}>"
    msg["To"]      = to_email
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(SMTP_FROM_EMAIL, to_email, msg.as_string())
        return True
    except Exception as exc:  # pragma: no cover
        print(f"[OTP] Email send failed: {exc}")
        return False


# ---------------------------------------------------------------------------
# Email sending — Support contact
# ---------------------------------------------------------------------------

def send_support_email(full_name: str, from_email: str, message: str) -> bool:
    """
    Send a support request to the PawStay support inbox (SMTP_FROM_EMAIL).
    The message is emailed directly — no data is stored in the database.
    Returns True on success, False on failure.
    """
    subject = f"PawStay Support Request from {full_name}"

    html_body = f"""
    <html>
    <body style="margin:0;padding:0;background:#FFF8F4;font-family:'Segoe UI',Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#FFF8F4;padding:40px 0;">
        <tr>
          <td align="center">
            <table width="480" cellpadding="0" cellspacing="0"
                   style="background:#FFFFFF;border-radius:16px;box-shadow:0 4px 20px rgba(74,68,63,.08);overflow:hidden;">
              <!-- Header -->
              <tr>
                <td style="background:#99462A;padding:28px 36px;">
                  <h1 style="margin:0;color:#FFFFFF;font-size:22px;font-weight:700;letter-spacing:-0.5px;">
                    🐾 PawStay — Support Request
                  </h1>
                </td>
              </tr>
              <!-- Body -->
              <tr>
                <td style="padding:36px;">
                  <p style="margin:0 0 8px;color:#55433D;font-size:14px;font-weight:600;">FROM</p>
                  <p style="margin:0 0 4px;color:#1F1B17;font-size:16px;font-weight:700;">{full_name}</p>
                  <p style="margin:0 0 28px;color:#88726C;font-size:14px;">{from_email}</p>

                  <p style="margin:0 0 8px;color:#55433D;font-size:14px;font-weight:600;">MESSAGE</p>
                  <div style="background:#F6ECE5;border-radius:12px;padding:20px;margin-bottom:28px;">
                    <p style="margin:0;color:#1F1B17;font-size:15px;line-height:1.7;white-space:pre-wrap;">{message}</p>
                  </div>

                  <p style="margin:0;color:#88726C;font-size:13px;line-height:1.5;">
                    Reply directly to <a href="mailto:{from_email}" style="color:#99462A;">{from_email}</a> to respond.
                  </p>
                </td>
              </tr>
              <!-- Footer -->
              <tr>
                <td style="background:#F6ECE5;padding:20px 36px;text-align:center;">
                  <p style="margin:0;color:#88726C;font-size:12px;">
                    &copy; 2026 PawStay. All rights reserved.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = f"{SMTP_FROM_NAME} <{SMTP_FROM_EMAIL}>"
    msg["To"]      = SMTP_FROM_EMAIL   # support inbox
    msg["Reply-To"] = from_email
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(SMTP_FROM_EMAIL, SMTP_FROM_EMAIL, msg.as_string())
        return True
    except Exception as exc:  # pragma: no cover
        print(f"[SUPPORT] Email send failed: {exc}")
        return False
