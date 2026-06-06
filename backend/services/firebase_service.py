import os
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin securely
if not firebase_admin._apps:
    cred = None
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    cred_json_str = os.getenv("FIREBASE_CREDENTIALS_JSON")
    
    # 1. Check direct path from environment
    if cred_path and os.path.exists(cred_path):
        try:
            cred = credentials.Certificate(cred_path)
        except Exception as e:
            print(f"Error loading FIREBASE_CREDENTIALS_PATH: {e}")
            
    # 2. Check JSON string from environment
    elif cred_json_str:
        try:
            import json
            cred_dict = json.loads(cred_json_str)
            cred = credentials.Certificate(cred_dict)
        except Exception as e:
            print(f"Error loading FIREBASE_CREDENTIALS_JSON: {e}")

    # 3. Search for firebase-service-account.json in common paths
    if not cred:
        cred_paths = [
            os.path.join(os.path.dirname(__file__), "..", "firebase-service-account.json"),
            os.path.join(os.getcwd(), "firebase-service-account.json"),
            os.path.join(os.getcwd(), "backend", "firebase-service-account.json"),
        ]
        for path in cred_paths:
            if os.path.exists(path):
                try:
                    cred = credentials.Certificate(path)
                    print(f"Firebase Service: Found credentials key file at {path}")
                    break
                except Exception as e:
                    print(f"Firebase Service: Error parsing cert at {path}: {e}")

    # 4. Initialize with resolved credentials or fallback
    if cred:
        try:
            firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"Firebase Service: Error initializing with credentials: {e}")
    else:
        try:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        except Exception:
            try:
                # Fallback when running inside Google Cloud environment
                firebase_admin.initialize_app()
            except Exception as e:
                print(f"Firebase Service: Uncredentialed initialization fallback failed: {e}")

# Initialize firestore client safely
db = None
try:
    db = firestore.client()
except Exception as e:
    print(f"Firebase Service: Failed to initialize Firestore client (running in fallback mode): {e}")

