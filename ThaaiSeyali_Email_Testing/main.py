
import os
import time
import hmac
import hashlib
import secrets
import logging
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field
from email_service import send_otp_email

load_dotenv()
logging.basicConfig(level=logging.INFO)
app = FastAPI(title="Thaai Seyali Email OTP API", version="1.0.0")

OTP_EXPIRY = 300
OTP_COOLDOWN = 30
MAX_ATTEMPTS = 5
otp_store = {}

class OTPRequest(BaseModel):
    email: EmailStr

class OTPVerification(BaseModel):
    email: EmailStr
    otp: str = Field(pattern=r"^[0-9]{6}$")

def hash_otp(email: str, otp: str):
    return hashlib.sha256(f"{email}:{otp}".encode()).hexdigest()

@app.get("/")
def home():
    return {"message": "Thaai Seyali Email OTP API is running"}

@app.post("/api/v1/auth/request-email-otp")
def request_email_otp(request: OTPRequest):
    email = str(request.email).lower()
    current_time = time.time()
    existing = otp_store.get(email)
    if existing and current_time - existing["created_at"] < OTP_COOLDOWN:
        remaining = int(OTP_COOLDOWN - (current_time - existing["created_at"]))
        raise HTTPException(status_code=429, detail=f"Please wait {remaining} seconds before requesting another OTP.")
    otp = str(secrets.randbelow(900000) + 100000)
    try:
        send_otp_email(email, otp)
    except Exception:
        logging.exception("OTP email sending failed")
        raise HTTPException(status_code=502, detail="Unable to send OTP email. Please try again.")
    otp_store[email] = {
        "otp_hash": hash_otp(email, otp),
        "created_at": current_time,
        "expires_at": current_time + OTP_EXPIRY,
        "attempts": 0
    }
    return {"success": True, "message": "OTP sent successfully. It is valid for 5 minutes."}

@app.post("/api/v1/auth/verify-email-otp")
def verify_email_otp(request: OTPVerification):
    email = str(request.email).lower()
    record = otp_store.get(email)
    if not record:
        raise HTTPException(status_code=400, detail="No active OTP found. Please request a new OTP.")
    if time.time() > record["expires_at"]:
        otp_store.pop(email, None)
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new OTP.")
    if record["attempts"] >= MAX_ATTEMPTS:
        otp_store.pop(email, None)
        raise HTTPException(status_code=429, detail="Maximum verification attempts reached. Please request a new OTP.")
    record["attempts"] += 1
    submitted_hash = hash_otp(email, request.otp)
    if not hmac.compare_digest(record["otp_hash"], submitted_hash):
        if record["attempts"] >= MAX_ATTEMPTS:
            otp_store.pop(email, None)
            raise HTTPException(status_code=429, detail="Maximum verification attempts reached. Please request a new OTP.")
        raise HTTPException(status_code=400, detail="Incorrect OTP. Please try again.")
    otp_store.pop(email, None)
    return {"success": True, "verified": True, "message": "Email verified successfully."}
