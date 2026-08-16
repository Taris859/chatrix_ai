import json
import os
import datetime
import threading
from firebase_admin import firestore
from services.firebase_service import db

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
HISTORY_FILE = os.path.join(DATA_DIR, "chat_history.json")

_db_lock = threading.Lock()

# --- Fallback Local DB Methods ---
def _load_db():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)
    if not os.path.exists(HISTORY_FILE):
        return {}
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except:
            return {}

def _save_db(db_data):
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(db_data, f, indent=2)


# --- Public API with Firestore and Local Fallback ---

def check_message_limit(user_id: str, is_premium: bool) -> bool:
    if is_premium:
        return True

    today = datetime.date.today().isoformat()

    if db is not None:
        try:
            doc_ref = db.collection("users").document(user_id).collection("limits").document(today)
            doc = doc_ref.get()
            if doc.exists:
                count = doc.to_dict().get("count", 0)
                return count < 100
            return True
        except Exception as e:
            print(f"[Memory Manager] Firestore check_message_limit error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        meta_key = f"user_meta_{user_id}"
        user_data = db_local.get(meta_key, {"date": today, "count": 0})
        if user_data.get("date") != today:
            user_data["date"] = today
            user_data["count"] = 0
        return user_data["count"] < 100


def increment_message_count(user_id: str):
    today = datetime.date.today().isoformat()

    if db is not None:
        try:
            doc_ref = db.collection("users").document(user_id).collection("limits").document(today)
            doc_ref.set({"count": firestore.Increment(1)}, merge=True)
            return
        except Exception as e:
            print(f"[Memory Manager] Firestore increment_message_count error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        meta_key = f"user_meta_{user_id}"
        user_data = db_local.get(meta_key, {"date": today, "count": 0})
        if user_data.get("date") != today:
            user_data["date"] = today
            user_data["count"] = 0
        user_data["count"] += 1
        db_local[meta_key] = user_data
        _save_db(db_local)


def get_chat_history(user_id: str, companion_name: str) -> list:
    if db is not None:
        try:
            # Query last 100 messages ordered by timestamp ascending
            messages_ref = (
                db.collection("chats")
                .document(f"{user_id}_{companion_name}")
                .collection("messages")
                .order_by("timestamp", direction=firestore.Query.ASCENDING)
                .limit(100)
            )
            docs = messages_ref.stream()
            history = []
            for doc in docs:
                data = doc.to_dict()
                history.append({
                    "role": data.get("role"),
                    "content": data.get("content")
                })
            return history
        except Exception as e:
            print(f"[Memory Manager] Firestore get_chat_history error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        key = f"{user_id}_{companion_name}"
        return db_local.get(key, {}).get("messages", [])


def add_message(user_id: str, companion_name: str, message: dict):
    if db is not None:
        try:
            # Add message to the messages subcollection with server timestamp
            msg_ref = (
                db.collection("chats")
                .document(f"{user_id}_{companion_name}")
                .collection("messages")
                .document()
            )
            msg_ref.set({
                "role": message["role"],
                "content": message["content"],
                "timestamp": firestore.SERVER_TIMESTAMP
            })
            return
        except Exception as e:
            print(f"[Memory Manager] Firestore add_message error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        key = f"{user_id}_{companion_name}"
        if key not in db_local:
            db_local[key] = {"messages": [], "summary": None, "diary_entries": []}
        db_local[key]["messages"].append(message)
        _save_db(db_local)


def get_session_data(user_id: str, companion_name: str) -> dict:
    if db is not None:
        try:
            # Get main session data
            doc_ref = db.collection("chats").document(f"{user_id}_{companion_name}")
            doc = doc_ref.get()
            summary = None
            diary_entries = []
            if doc.exists:
                data = doc.to_dict()
                summary = data.get("summary")
                diary_entries = data.get("diary_entries", [])

            # Fetch history
            messages = get_chat_history(user_id, companion_name)
            return {
                "messages": messages,
                "summary": summary,
                "diary_entries": diary_entries
            }
        except Exception as e:
            print(f"[Memory Manager] Firestore get_session_data error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        key = f"{user_id}_{companion_name}"
        data = db_local.get(key, {"messages": [], "summary": None, "diary_entries": []})
        if "diary_entries" not in data:
            data["diary_entries"] = []
        return data


def update_session_data(user_id: str, companion_name: str, summary: dict = None, diary_entry: dict = None):
    if db is not None:
        try:
            doc_ref = db.collection("chats").document(f"{user_id}_{companion_name}")
            updates = {}
            if summary is not None:
                updates["summary"] = summary
            if diary_entry is not None:
                updates["diary_entries"] = firestore.ArrayUnion([diary_entry])
            
            if updates:
                doc_ref.set(updates, merge=True)
            return
        except Exception as e:
            print(f"[Memory Manager] Firestore update_session_data error: {e}. Falling back...")

    # Fallback to local JSON
    with _db_lock:
        db_local = _load_db()
        key = f"{user_id}_{companion_name}"
        if key not in db_local:
            db_local[key] = {"messages": [], "summary": None, "diary_entries": []}
        if "diary_entries" not in db_local[key]:
            db_local[key]["diary_entries"] = []
            
        if summary is not None:
            db_local[key]["summary"] = summary
        if diary_entry is not None:
            db_local[key]["diary_entries"].append(diary_entry)
        _save_db(db_local)
