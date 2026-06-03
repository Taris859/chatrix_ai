import json
import os
import datetime
import threading

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
HISTORY_FILE = os.path.join(DATA_DIR, "chat_history.json")

_db_lock = threading.Lock()

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

def _save_db(db):
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)

def check_message_limit(user_id: str, is_premium: bool) -> bool:
    if is_premium:
        return True
    with _db_lock:
        db = _load_db()
        today = datetime.date.today().isoformat()
        meta_key = f"user_meta_{user_id}"
        user_data = db.get(meta_key, {"date": today, "count": 0})
        if user_data.get("date") != today:
            user_data["date"] = today
            user_data["count"] = 0
        return user_data["count"] < 100

def increment_message_count(user_id: str):
    with _db_lock:
        db = _load_db()
        today = datetime.date.today().isoformat()
        meta_key = f"user_meta_{user_id}"
        user_data = db.get(meta_key, {"date": today, "count": 0})
        if user_data.get("date") != today:
            user_data["date"] = today
            user_data["count"] = 0
        user_data["count"] += 1
        db[meta_key] = user_data
        _save_db(db)

def get_chat_history(user_id: str, companion_name: str) -> list:
    with _db_lock:
        db = _load_db()
        key = f"{user_id}_{companion_name}"
        return db.get(key, {}).get("messages", [])

def add_message(user_id: str, companion_name: str, message: dict):
    with _db_lock:
        db = _load_db()
        key = f"{user_id}_{companion_name}"
        if key not in db:
            db[key] = {"messages": [], "summary": None, "diary_entries": []}
        db[key]["messages"].append(message)
        _save_db(db)

def get_session_data(user_id: str, companion_name: str) -> dict:
    with _db_lock:
        db = _load_db()
        key = f"{user_id}_{companion_name}"
        data = db.get(key, {"messages": [], "summary": None, "diary_entries": []})
        if "diary_entries" not in data:
            data["diary_entries"] = []
        return data

def update_session_data(user_id: str, companion_name: str, summary: dict = None, diary_entry: dict = None):
    with _db_lock:
        db = _load_db()
        key = f"{user_id}_{companion_name}"
        if key not in db:
            db[key] = {"messages": [], "summary": None, "diary_entries": []}
        if "diary_entries" not in db[key]:
            db[key]["diary_entries"] = []
            
        if summary is not None:
            db[key]["summary"] = summary
        if diary_entry is not None:
            db[key]["diary_entries"].append(diary_entry)
        _save_db(db)
