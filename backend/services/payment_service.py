import os
import razorpay
from fastapi import HTTPException
from services.firebase_service import db
from services.email_service import send_subscription_email

RAZORPAY_KEY = os.getenv("RAZORPAY_KEY", "rzp_live_SxDgLp1gs3KyJ3")
RAZORPAY_SECRET = os.getenv("RAZORPAY_SECRET", "bVAma3djzX3qaXIVLExDGrd2")

try:
    rzp_client = razorpay.Client(auth=(RAZORPAY_KEY, RAZORPAY_SECRET))
except Exception as e:
    print(f"Error initializing Razorpay Client: {e}")
    rzp_client = None

class PaymentService:
    @staticmethod
    def get_config():
        return {
            "razorpay_key": RAZORPAY_KEY,
            "elevenlabs_key": os.getenv("ELEVENLABS_API_KEY", "sk_b6af5e1e2354b2042bfdf59d2a43d0cd8e0a66557fa1774a"),
            "premium_price_inr": 249
        }

    @staticmethod
    def create_order(user_id: str, amount: int):
        if not rzp_client:
            raise HTTPException(status_code=500, detail="Razorpay client is uninitialized.")
        try:
            razorpay_order = rzp_client.order.create(dict(
                amount=amount,
                currency='INR',
                receipt=f"receipt_{user_id}",
                notes={'user_id': user_id}
            ))
            return {
                "order_id": razorpay_order['id'],
                "amount": razorpay_order['amount'],
                "currency": razorpay_order['currency']
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @staticmethod
    async def verify_payment(user_id: str, payment_id: str, order_id: str, signature: str, email: str = None, plan_name: str = None, amount: float = None, expiry: str = None, background_tasks = None):
        if not rzp_client:
            raise HTTPException(status_code=500, detail="Razorpay client is uninitialized.")
        try:
            # 1. Verify payment signature securely
            rzp_client.utility.verify_payment_signature({
                'razorpay_order_id': order_id,
                'razorpay_payment_id': payment_id,
                'razorpay_signature': signature
            })

            # 2. Securely update Firestore entitlement from backend to prevent client-side bypasses
            try:
                if db is not None:
                    user_ref = db.collection('users').document(user_id)
                    user_ref.set({
                        'premium_status': True,
                        'premium_expiry': expiry
                    }, merge=True)
                    print(f"Backend security layer: Successfully upgraded user {user_id} to Premium.")
                else:
                    print("Backend security layer: Firestore client is uninitialized, skipping backend database update.")
            except Exception as fe:
                print(f"Firestore verification write failed: {fe}")

            # 3. Send subscription receipt email
            if email and background_tasks:
                background_tasks.add_task(
                    send_subscription_email,
                    to_email=email,
                    user_id=user_id,
                    payment_id=payment_id,
                    plan_name=plan_name or "Premium",
                    amount=amount or 249.0,
                    expiry=expiry or "30 days from now"
                )

            return {
                "status": "success",
                "message": "Payment verified securely by backend.",
                "verified": True
            }
        except razorpay.errors.SignatureVerificationError:
            raise HTTPException(status_code=400, detail="Signature verification failed.")
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
