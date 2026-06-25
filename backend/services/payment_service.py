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

    @staticmethod
    async def verify_paypal(user_id: str, transaction_id: str, plan_id: str, amount_usd: float, email: str = None, background_tasks = None):
        import httpx
        from datetime import datetime, timedelta

        PAYPAL_CLIENT_ID = os.environ.get("PAYPAL_CLIENT_ID", "")
        PAYPAL_CLIENT_SECRET = os.environ.get("PAYPAL_CLIENT_SECRET", "")

        if not PAYPAL_CLIENT_ID or not PAYPAL_CLIENT_SECRET:
            print("PayPal credentials are not set in environment variables.")
            return {"verified": False, "reason": "Credentials not configured"}

        # Dynamic detection of Sandbox vs Production credentials
        async def get_paypal_access_token() -> tuple[str, str]:
            # Try production endpoint first
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        "https://api-m.paypal.com/v1/oauth2/token",
                        auth=(PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET),
                        data={"grant_type": "client_credentials"},
                    )
                    if response.status_code == 200:
                        return response.json()["access_token"], "https://api-m.paypal.com"
            except Exception as e:
                print(f"PayPal Production OAuth attempt failed: {e}")

            # Fall back to sandbox endpoint
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        "https://api-m.sandbox.paypal.com/v1/oauth2/token",
                        auth=(PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET),
                        data={"grant_type": "client_credentials"},
                    )
                    response.raise_for_status()
                    return response.json()["access_token"], "https://api-m.sandbox.paypal.com"
            except Exception as e:
                print(f"PayPal Sandbox OAuth attempt failed: {e}")
                raise e

        try:
            access_token, paypal_api_base = await get_paypal_access_token()
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{paypal_api_base}/v1/reporting/transactions",
                    headers={"Authorization": f"Bearer {access_token}"},
                    params={
                        "transaction_id": transaction_id,
                        "fields": "all",
                        "start_date": (datetime.utcnow() - timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ"),
                        "end_date": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                    },
                )

            if response.status_code != 200:
                print(f"PayPal transactions reporting endpoint error status: {response.status_code}")
                return {"verified": False, "reason": "PayPal API reporting error"}

            transactions = response.json().get("transaction_details", [])
            if not transactions:
                return {"verified": False, "reason": "Transaction not found"}

            txn_info = transactions[0].get("transaction_info", {})
            status = txn_info.get("transaction_status", "")
            if status != "S":
                return {"verified": False, "reason": f"Status is '{status}', not completed"}

            txn_amount = float(txn_info.get("transaction_amount", {}).get("value", 0))
            if abs(txn_amount - amount_usd) > 0.15:
                return {"verified": False, "reason": "Amount mismatch"}

            # Update premium status in Firestore
            try:
                if db is not None:
                    expiry_date = datetime.now() + timedelta(days=30)
                    expiry_str = f"{expiry_date.day}/{expiry_date.month}/{expiry_date.year}"
                    
                    user_ref = db.collection('users').document(user_id)
                    user_ref.set({
                        'premium_status': True,
                        'premium_expiry': expiry_str
                    }, merge=True)
                    print(f"✅ PayPal verified: Upgraded user {user_id} to Premium via backend.")
                else:
                    print("Firestore client is uninitialized, skipping backend database update.")
            except Exception as fe:
                print(f"Firestore verification write failed: {fe}")

            # Send welcome/subscription email if email is provided
            if email and background_tasks:
                background_tasks.add_task(
                    send_subscription_email,
                    to_email=email,
                    user_id=user_id,
                    payment_id=transaction_id,
                    plan_name="Premium PayPal Upgrade",
                    amount=amount_usd,
                    expiry="30 days from now"
                )

            return {"verified": True}

        except Exception as e:
            print(f"PayPal verify error: {e}")
            return {"verified": False, "reason": str(e)}
