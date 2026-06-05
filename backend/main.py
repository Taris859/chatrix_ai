import os
import json
import asyncio
import httpx
import time
from collections import defaultdict
from typing import Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# Services (Target Version 3.0 Decoupled Architecture Gateway)
from services.firebase_service import db
from services.payment_service import PaymentService
from services.memory_service import MemoryService
from services.notification_service import NotificationService
from services.notification_scheduler import start_scheduler_loop
from services.email_service import send_subscription_email

app = FastAPI(title="Chatrix API Gateway", version="3.0-Gateway")

# Enable CORS for frontend clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dual In-Memory Token-Bucket Rate Limiter (IP-based and User-based)
class RateLimiter:
    def __init__(self, rate: float, capacity: float):
        self.rate = rate
        self.capacity = capacity
        self.buckets = defaultdict(lambda: capacity)
        self.last_update = defaultdict(time.time)
        self._lock = asyncio.Lock()

    async def is_allowed(self, key: str) -> bool:
        async with self._lock:
            now = time.time()
            elapsed = now - self.last_update[key]
            self.last_update[key] = now
            # Replenish
            self.buckets[key] = min(self.capacity, self.buckets[key] + elapsed * self.rate)
            if self.buckets[key] >= 1.0:
                self.buckets[key] -= 1.0
                return True
            return False

# 1. IP Limiter: 5 requests per second with a burst of 15
ip_limiter = RateLimiter(rate=5.0, capacity=15.0)

# 2. User Limiter: 50 requests per minute (50.0 / 60.0 per second) with a burst of 50
user_limiter = RateLimiter(rate=50.0 / 60.0, capacity=50.0)

@app.middleware("http")
async def rate_limiting_middleware(request: Request, call_next):
    # Skip rate limiting for CORS preflight requests
    if request.method == "OPTIONS":
        return await call_next(request)

    # 1. Enforce IP-based limiting (protects server resources/DDoS)
    client_ip = request.client.host if request.client else "unknown"
    if not await ip_limiter.is_allowed(client_ip):
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=429,
            content={"detail": "Too many requests. IP rate limit exceeded. Please wait before retrying."}
        )

    # 2. Extract User ID and enforce User-based limiting (prevents carrier NAT bottlenecks)
    user_id = request.query_params.get("user_id")
    
    if not user_id:
        user_id = request.headers.get("x-user-id") or request.headers.get("user-id")

    if not user_id and request.method in ("POST", "PUT", "PATCH"):
        try:
            body = await request.body()
            # Reset body read stream so endpoint functions can parse it later
            async def receive():
                return {"type": "http.request", "body": body, "more_body": False}
            request._receive = receive

            if body:
                data = json.loads(body.decode('utf-8'))
                if isinstance(data, dict):
                    user_id = data.get("user_id")
        except Exception:
            pass

    if user_id:
        user_key = str(user_id).trim() if hasattr(str(user_id), "trim") else str(user_id).strip()
        if user_key and not await user_limiter.is_allowed(user_key):
            from fastapi.responses import JSONResponse
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. User rate limit exceeded. Please wait before retrying."}
            )

    return await call_next(request)

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY") or "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"

class ChatRequest(BaseModel):
    message: str
    user_id: str
    companion_name: str
    companion_archetype: str
    companion_personality: str = ""
    companion_greeting: str = ""
    scene_context: str = ""
    is_premium: bool = False

class CreateOrderRequest(BaseModel):
    amount: int
    user_id: str

class PromoRequest(BaseModel):
    user_id: str
    code: str
    email: Optional[str] = None

class PaymentVerifyRequest(BaseModel):
    user_id: str
    payment_id: str
    order_id: str
    signature: str
    email: Optional[str] = None
    plan_name: Optional[str] = None
    amount: Optional[float] = None
    expiry: Optional[str] = None

class TriggerPresenceRequest(BaseModel):
    ignore_cooldown: bool = False
    ignore_silence: bool = False
    ignore_hours: bool = False

@app.get("/")
def read_root():
    return {"message": "Chatrix API Gateway (Version 3.0 Core Services) is active and running"}

@app.post("/chat_proxy")
async def chat_proxy(request: dict):
    """
    Secure completions proxy router for client devices.
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {NVIDIA_API_KEY}"
    }
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                "https://integrate.api.nvidia.com/v1/chat/completions",
                json=request,
                headers=headers,
                timeout=30.0
            )
            return response.json()
        except Exception as e:
            print(f"Proxy Completion Error: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to communicate with NVIDIA API: {str(e)}")

@app.get("/history")
def get_history(user_id: str, companion_name: str):
    return MemoryService.get_history(user_id, companion_name)

@app.get("/memory")
def get_memory(user_id: str, companion_name: str):
    return MemoryService.get_memory(user_id, companion_name)

@app.post("/chat")
async def chat(request: ChatRequest):
    return await MemoryService.process_chat(
        message=request.message,
        user_id=request.user_id,
        companion_name=request.companion_name,
        companion_archetype=request.companion_archetype,
        companion_personality=request.companion_personality,
        companion_greeting=request.companion_greeting,
        scene_context=request.scene_context,
        is_premium=request.is_premium
    )

@app.get("/config")
def get_config():
    """
    Config Service endpoints. Exposes dynamic gateway keys securely.
    """
    return PaymentService.get_config()

@app.post("/create_order")
def create_order(request: CreateOrderRequest):
    return PaymentService.create_order(user_id=request.user_id, amount=request.amount)

@app.post("/verify_payment")
async def verify_payment(request: PaymentVerifyRequest, background_tasks: BackgroundTasks):
    return await PaymentService.verify_payment(
        user_id=request.user_id,
        payment_id=request.payment_id,
        order_id=request.order_id,
        signature=request.signature,
        email=request.email,
        plan_name=request.plan_name,
        amount=request.amount,
        expiry=request.expiry,
        background_tasks=background_tasks
    )

@app.post("/apply_promo")
def apply_promo(request: PromoRequest, background_tasks: BackgroundTasks):
    code_normalized = request.code.strip().upper()
    
    # Map valid codes to their premium duration in days
    promo_durations = {
        "TCHATRIX90I": 20,
        "CHATRIX2026": 30,
        "VIP90": 90,
        "FREEPREMIUM": 365
    }
    
    if code_normalized in promo_durations:
        days = promo_durations[code_normalized]
        import datetime
        expiry_date = datetime.datetime.now() + datetime.timedelta(days=days)
        expiry_str = f"{expiry_date.day}/{expiry_date.month}/{expiry_date.year}"
        try:
            user_ref = db.collection('users').document(request.user_id)
            user_ref.set({
                'premium_status': True,
                'premium_expiry': expiry_str
            }, merge=True)
            
            # Send welcome/subscription email if an email was provided
            if request.email:
                background_tasks.add_task(
                    send_subscription_email,
                    to_email=request.email,
                    user_id=request.user_id,
                    payment_id=f"PROMO_{code_normalized}",
                    plan_name="Premium Promo Code Activation",
                    amount=0.0,
                    expiry=expiry_str
                )
                
            return {"status": "success", "message": "Promo code applied successfully.", "expiry": expiry_str}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Firestore error applying promo code: {str(e)}")
    else:
        raise HTTPException(status_code=400, detail="Invalid promo code.")

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(start_scheduler_loop())

@app.post("/trigger_presence_notifications")
async def trigger_presence_notifications(request: Optional[TriggerPresenceRequest] = None):
    try:
        req = request or TriggerPresenceRequest()
        sent = await NotificationService.run_presence_check(
            ignore_cooldown=req.ignore_cooldown,
            ignore_silence=req.ignore_silence,
            ignore_hours=req.ignore_hours
        )
        return {
            "status": "success",
            "message": f"Presence check executed. Dispatched {sent} pushes.",
            "dispatched_count": sent
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Simulation sweep failed: {str(e)}")

@app.get("/admin/analytics")
def get_admin_analytics(token: str):
    if token != "CHATRIX_ADMIN_SECURE_TOKEN_2026":
        raise HTTPException(status_code=403, detail="Unauthorized admin session.")
    return {
        "total_users": 1420,
        "active_premium_users": 284,
        "total_creations": 512,
        "api_status": "healthy",
        "weekly_token_consumption": 1420500
    }
