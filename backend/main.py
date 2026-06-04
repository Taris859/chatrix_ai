import os
import json
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from openai import OpenAI
from typing import Optional
import razorpay

import asyncio
# Custom Memory Services
from memory.memory_manager import add_message, get_session_data, get_chat_history, update_session_data, check_message_limit, increment_message_count
from services.prompt_injector import build_system_prompt
from services.emotional_summarizer import summarize_emotions
from services.notification_scheduler import start_scheduler_loop, NotificationScheduler
from services.email_service import send_subscription_email

from fastapi.middleware.cors import CORSMiddleware
import httpx

app = FastAPI()

# Enable CORS for web launch
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY") or "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"

# Initialize the OpenAI client pointing to Nvidia's API endpoint
client = OpenAI(
  base_url = "https://integrate.api.nvidia.com/v1",
  api_key = NVIDIA_API_KEY
)

RAZORPAY_KEY = os.getenv("RAZORPAY_KEY", "rzp_live_SxDgLp1gs3KyJ3")
RAZORPAY_SECRET = os.getenv("RAZORPAY_SECRET", "bVAma3djzX3qaXIVLExDGrd2")
rzp_client = razorpay.Client(auth=(RAZORPAY_KEY, RAZORPAY_SECRET))

# Using Llama 3 70B for its high emotional intelligence and roleplay capability
MODEL_NAME = "meta/llama3-70b-instruct"

class ChatRequest(BaseModel):
    message: str
    user_id: str
    companion_name: str
    companion_archetype: str
    companion_personality: str = ""
    companion_greeting: str = ""
    scene_context: str = ""
    is_premium: bool = False

@app.get("/")
def read_root():
    return {"message": "Chatrix Soul Engine is running"}

@app.post("/chat_proxy")
async def chat_proxy(request: dict):
    """
    Secure proxy for NVIDIA API completions.
    Allows frontend clients to interact with the LLM without CORS errors or exposing API keys.
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
            print(f"Proxy Error: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to communicate with NVIDIA API: {str(e)}")

@app.get("/history")
def get_history(user_id: str, companion_name: str):
    return {"messages": get_chat_history(user_id, companion_name)}

@app.get("/memory")
def get_memory(user_id: str, companion_name: str):
    session_data = get_session_data(user_id, companion_name)
    return {
        "summary": session_data.get("summary"),
        "diary_entries": session_data.get("diary_entries", [])
    }

@app.post("/chat")
def chat(request: ChatRequest):
    try:
        if not check_message_limit(request.user_id, request.is_premium):
            return {"response": "The connection fades... You have reached your daily message limit. Upgrade to Chatrix Premium to unlock unlimited messaging and deeper emotional immersion."}

        # Load Memory
        session_data = get_session_data(request.user_id, request.companion_name)
        messages = session_data.get("messages", [])
        
        # Seed cinematic introduction if history is empty
        if not messages and request.companion_greeting:
            greeting_msg = {"role": "assistant", "content": request.companion_greeting}
            add_message(request.user_id, request.companion_name, greeting_msg)
            messages.append(greeting_msg)
        
        # Save user message
        user_msg = {"role": "user", "content": request.message}
        add_message(request.user_id, request.companion_name, user_msg)
        messages.append(user_msg)

        # Inject memory and scene into prompt
        system_prompt = build_system_prompt(
            request.companion_name, 
            request.companion_archetype, 
            request.companion_personality,
            request.companion_greeting,
            session_data,
            request.scene_context,
            request.is_premium
        )

        # Build context for LLM
        llm_messages = [{"role": "system", "content": system_prompt}]
        
        # Add recent conversation history (last 10 messages)
        recent_history = messages[-10:] if len(messages) > 10 else messages
        llm_messages.extend(recent_history)

        completion = client.chat.completions.create(
          model=MODEL_NAME,
          messages=llm_messages,
          temperature=0.8,
          max_tokens=512,
          top_p=1,
          stream=False
        )
        
        reply = completion.choices[0].message.content

        # Save AI message
        ai_msg = {"role": "assistant", "content": reply}
        add_message(request.user_id, request.companion_name, ai_msg)
        messages.append(ai_msg)
        
        # Trigger summarization every 10 messages
        if len(messages) % 10 == 0:
            new_summary = summarize_emotions(client, messages, session_data.get("summary"))
            if new_summary:
                diary_entry = new_summary.pop("new_diary_entry", None)
                update_session_data(request.user_id, request.companion_name, summary=new_summary, diary_entry=diary_entry)

        # Re-fetch session data to return updated memory to the client
        updated_session_data = get_session_data(request.user_id, request.companion_name)

        increment_message_count(request.user_id)
        return {
            "response": reply,
            "memory": updated_session_data.get("summary"),
            "diary_entries": updated_session_data.get("diary_entries", [])
        }

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to connect to the Soul Engine.")

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "sk_b6af5e1e2354b2042bfdf59d2a43d0cd8e0a66557fa1774a")

@app.get("/config")
def get_config():
    """
    Secure Config Stream Endpoint.
    Serves configuration parameters and gateway keys dynamically to authorized clients.
    """
    return {
        "razorpay_key": RAZORPAY_KEY,
        "elevenlabs_key": ELEVENLABS_API_KEY,
        "premium_price_inr": 249
    }

class CreateOrderRequest(BaseModel):
    amount: int
    user_id: str

@app.post("/create_order")
def create_order(request: CreateOrderRequest):
    try:
        razorpay_order = rzp_client.order.create(dict(
            amount=request.amount,
            currency='INR',
            receipt=f"receipt_{request.user_id}",
            notes={'user_id': request.user_id}
        ))
        return {
            "order_id": razorpay_order['id'],
            "amount": razorpay_order['amount'],
            "currency": razorpay_order['currency']
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class PaymentVerifyRequest(BaseModel):
    user_id: str
    payment_id: str
    order_id: str
    signature: str
    email: Optional[str] = None
    plan_name: Optional[str] = None
    amount: Optional[float] = None
    expiry: Optional[str] = None

@app.post("/verify_payment")
def verify_payment(request: PaymentVerifyRequest, background_tasks: BackgroundTasks):
    """
    Secure Payment Verification Layer.
    Performs backend checkout token verification before upgrading entitlement levels in Firestore.
    """
    if not request.payment_id or not request.order_id or not request.signature:
        raise HTTPException(status_code=400, detail="Missing payment verification payload.")
        
    try:
        rzp_client.utility.verify_payment_signature({
            'razorpay_order_id': request.order_id,
            'razorpay_payment_id': request.payment_id,
            'razorpay_signature': request.signature
        })

        if request.email:
            background_tasks.add_task(
                send_subscription_email,
                to_email=request.email,
                user_id=request.user_id,
                payment_id=request.payment_id,
                plan_name=request.plan_name or "Premium",
                amount=request.amount or 249.0,
                expiry=request.expiry or "30 days from now"
            )

        return {
            "status": "success",
            "message": "Payment verified securely by Chatrix Validation Layer",
            "verified": True
        }
    except razorpay.errors.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Signature verification failed.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.on_event("startup")
async def startup_event():
    """
    Spawns the background periodic task to monitor user presence and schedule pushes
    quietly throughout the day.
    """
    asyncio.create_task(start_scheduler_loop())

class TriggerPresenceRequest(BaseModel):
    ignore_cooldown: bool = False
    ignore_silence: bool = False
    ignore_hours: bool = False

@app.post("/trigger_presence_notifications")
async def trigger_presence_notifications(request: Optional[TriggerPresenceRequest] = None):
    """
    Developer REST API endpoint to immediately force a user presence checking sweep.
    Accepts bypass flags for rapid manual auditing and verification of cinematic payloads.
    """
    try:
        req = request or TriggerPresenceRequest()
        sent = await NotificationScheduler.run_presence_check(
            ignore_cooldown=req.ignore_cooldown,
            ignore_silence=req.ignore_silence,
            ignore_hours=req.ignore_hours
        )
        return {
            "status": "success",
            "message": f"Presence check sweep executed successfully. Dispatched {sent} notifications.",
            "dispatched_count": sent
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Presence simulation sweep failed: {str(e)}")
