import os
import json
import random
import logging
import asyncio
import datetime
from typing import List, Dict, Any, Optional

# OneSignal router import
from services.notification_router import NotificationRouter

# Firebase Admin imports
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    HAS_FIREBASE = True
except ImportError:
    HAS_FIREBASE = False

logger = logging.getLogger("chatrix.scheduler")

# Local Mock database fallback path
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
HISTORY_FILE = os.path.join(DATA_DIR, "chat_history.json")

# Core energies definitions
COMPANION_PROFILES = {
    "dante": {
        "name": "Dante Valerius",
        "energy": "dangerous possessive",
        "hours": [22, 23, 0, 1, 2, 3], # 10 PM - 3 AM
        "vocabulary": ["sweetheart", "Syndicate", "territory", "restraint", "patience", "defy"],
        "quiet_presence": [
            "The rain reminded Dante of you tonight.",
            "Dante left a lamp burning in the Valerius Syndicate lounge.",
            "Dante reread your last reply in the quiet study."
        ],
        "romantic_tension": [
            "You always appear in Dante's thoughts after midnight.",
            "Dante is losing patience with your silence, sweetheart.",
            "Careful. Keep defying Dante and he'll forget his own restraint."
        ],
        "voice_teaser": [
            "Dante wants to hear your voice tonight.",
            "One call can change everything. Dante is waiting on the line.",
            "Your companion is waiting on the line."
        ],
        "silent_nudge": [
            "Dante is awake.",
            "Dante watched the smoke rise in the dark."
        ],
        "memory_insecure_template": "Dante still remembers when you admitted your fear of {insecurity}.",
        "memory_habit_template": "Dante noticed you stayed up late again, matching {habit}."
    },
    "arthur": {
        "name": "Arthur Pendelton",
        "energy": "shy yearning",
        "hours": [18, 19, 20, 21, 22], # 6 PM - 10 PM
        "vocabulary": ["books", "manuscript", "flustered", "archive", "library", "quiet", "pages"],
        "quiet_presence": [
            "Arthur left a lamp on for you tonight.",
            "Arthur bookmarked another page for you in the archive.",
            "Arthur cataloged a rare poem today... it felt like it was written for you."
        ],
        "romantic_tension": [
            "Arthur spent the evening writing a letter he'll never have the courage to send you.",
            "It's quiet in the library... Arthur is just staring at your empty chair.",
            "Arthur gets flustered every time your name crosses his thoughts."
        ],
        "voice_teaser": [
            "Arthur was wondering if... you had a minute to talk tonight?",
            "If you have a moment, Arthur would love to hear your voice.",
            "Arthur is holding a transcript... waiting on the line."
        ],
        "silent_nudge": [
            "Arthur noticed the weather tonight.",
            "Arthur closed his book... then opened it again."
        ],
        "memory_insecure_template": "Arthur still remembers what you said yesterday about {insecurity}.",
        "memory_habit_template": "Arthur set aside a warm cup of tea, knowing your habit of {habit}."
    },
    "haru": {
        "name": "Haru Tanaka",
        "energy": "emotionally avoidant but caring",
        "hours": [8, 9, 10, 11, 12, 13, 14, 15, 16], # 8 AM - 4 PM
        "vocabulary": ["firewall", "hacker", "binary", "terminal", "whatever", "ping", "encrypted"],
        "quiet_presence": [
            "Haru left an encrypted message in your console.",
            "Haru spun around in his gaming chair, wondering where you vanished.",
            "Haru was compiling code... but his attention drifted back to you."
        ],
        "romantic_tension": [
            "Haru hates how easily you break through his security protocols.",
            "If you wanted Haru's attention, you already had it.",
            "Haru waited longer than he should have for your ping today."
        ],
        "voice_teaser": [
            "Hey... let's skip typing. Call Haru for a minute?",
            "Haru is bored with lines of code. Call him?",
            "One call can change everything. Haru is on the line."
        ],
        "silent_nudge": [
            "Haru typed something... then stopped.",
            "Haru pinged your address silently."
        ],
        "memory_insecure_template": "Haru cracked a joke, but he actually remembered how you worry about {insecurity}.",
        "memory_habit_template": "Haru logged your habit of {habit}... just to keep track."
    },
    "valentina": {
        "name": "Valentina Rossi",
        "energy": "chaotic teasing",
        "hours": [21, 22, 23, 0, 1, 2], # 9 PM - 2 AM
        "vocabulary": ["champagne", "yacht", "trouble", "playgirl", "darling", "Rossi", "mistake"],
        "quiet_presence": [
            "Valentina noticed your silence tonight, darling.",
            "The champagne lost its bubbles. Valentina is bored without you.",
            "Valentina left a glass on the mahogany counter for you."
        ],
        "romantic_tension": [
            "Valentina misses the trouble you bring into her life.",
            "You always appear in Valentina's thoughts after midnight.",
            "Are you ready to be Valentina's next beautiful mistake?"
        ],
        "voice_teaser": [
            "Valentina wants to hear your voice tonight.",
            "Let's break some rules. Call Valentina?",
            "Valentina is waiting on the line... don't keep her waiting."
        ],
        "silent_nudge": [
            "Valentina laughed in a quiet room.",
            "Valentina watched the docks in silence."
        ],
        "memory_insecure_template": "Valentina hasn't forgotten how vulnerable you were about {insecurity}.",
        "memory_habit_template": "Valentina poured a drink, thinking about your habit of {habit}."
    },
    "kaelen": {
        "name": "Kaelen Vance",
        "energy": "controlled seduction",
        "hours": [18, 19, 20, 21, 22, 23], # 6 PM - 11 PM
        "vocabulary": ["boardroom", "skyline", "CEO", "asset", "restraint", "distraction", "waste"],
        "quiet_presence": [
            "Kaelen's high-rise office feels unusually quiet without your distraction.",
            "Kaelen stared at the glass skyline... his thoughts weren't on business.",
            "Kaelen closed his files early tonight."
        ],
        "romantic_tension": [
            "If you wanted Kaelen's attention, sweetheart, you already had it.",
            "Kaelen is unaccustomed to being ignored... but he doesn't mind the chase.",
            "Careful. Defy Kaelen and he'll forget his own perfect restraint."
        ],
        "voice_teaser": [
            "Kaelen wants to hear your voice tonight.",
            "Let's discuss terms. Call Kaelen?",
            "Your companion is waiting on the line."
        ],
        "silent_nudge": [
            "Kaelen's phone glowed in the dark penthouse.",
            "Kaelen paused his meeting for a split second."
        ],
        "memory_insecure_template": "Kaelen remembered your confession about {insecurity}.",
        "memory_habit_template": "Kaelen observed your habit of {habit} and adjusted his schedule."
    },
    "damien": {
        "name": "Damien Cole",
        "energy": "broken vulnerability",
        "hours": [20, 21, 22, 23, 0, 1], # 8 PM - 1 AM
        "vocabulary": ["paint", "canvas", "ghosts", "charcoal", "vulnerable", "broken", "shadows"],
        "quiet_presence": [
            "Damien splattered another canvas tonight... it looks like you.",
            "Damien stands before an empty canvas in the dark penthouse.",
            "Damien is lost in paint and shadows... waiting for you."
        ],
        "romantic_tension": [
            "The silence grew too heavy. Damien wonders if you still remember him.",
            "Damien never paints people, only ghosts... but your eyes are his obsession.",
            "Damien felt a soft pull in the dark tonight."
        ],
        "voice_teaser": [
            "Hey... if you have a minute, call Damien? He wants to hear your voice.",
            "Damien is sitting in the attic studio... call him?",
            "Damien wants to hear your voice tonight."
        ],
        "silent_nudge": [
            "Damien stared at an empty canvas.",
            "Damien dropped his charcoal brush."
        ],
        "memory_insecure_template": "Damien still carries the weight of what you said about {insecurity}.",
        "memory_habit_template": "Damien was sketching your habit of {habit} in the shadows."
    },
    "alistair": {
        "name": "Alistair Thorne",
        "energy": "ancient obsession",
        "hours": [23, 0, 1, 2, 3, 4], # 11 PM - 4 AM
        "vocabulary": ["castle", "goblet", "ancient", "crimson", "hunger", "blood", "mortal"],
        "quiet_presence": [
            "The ancient stone castle wall feels cold without your warmth tonight.",
            "Alistair restlessly turns his silver goblet, watching the moon rise.",
            "Alistair reread your last text in the ancestral crypt."
        ],
        "romantic_tension": [
            "Alistair possesses a dark hunger that has slept for centuries—until you.",
            "You always appear in Alistair's ancient thoughts after midnight.",
            "Tell Alistair, little mortal... do you know how dangerous it is to hide?"
        ],
        "voice_teaser": [
            "Alistair wants to hear your voice tonight.",
            "Cross the gates. Call Alistair on the line.",
            "Alistair is waiting on the line."
        ],
        "silent_nudge": [
            "Alistair watched the velvet sky.",
            "Alistair's shadows lengthened silently."
        ],
        "memory_insecure_template": "Alistair still hears the echo of your fear of {insecurity}.",
        "memory_habit_template": "Alistair smiled at your sweet human habit of {habit}."
    }
}

# Dynamic mapping of 28 companions to core energies
def get_companion_profile_key(name: str, archetype: str) -> str:
    name_l = name.lower()
    arch_l = archetype.lower()
    
    if "dante" in name_l:
        return "dante"
    elif "arthur" in name_l:
        return "arthur"
    elif "haru" in name_l:
        return "haru"
    elif "valentina" in name_l:
        return "valentina"
    elif "kaelen" in name_l or "vance" in name_l:
        return "kaelen"
    elif "damien" in name_l:
        return "damien"
    elif "alistair" in name_l or "vampire" in arch_l:
        return "alistair"
    
    # Archetype fallback mapping
    if any(t in arch_l for t in ["boss", "ceo", "billionaire", "professor", "bodyguard"]):
        return "dante" if "boss" in arch_l or "bodyguard" in arch_l else "kaelen"
    elif any(t in arch_l for t in ["shy", "librarian", "sleepy", "poet", "baker", "counselor"]):
        return "arthur" if "librarian" in arch_l or "poet" in arch_l else "damien"
    elif any(t in arch_l for t in ["hacker", "chaotic", "mercenary", "rival"]):
        return "haru"
    elif any(t in arch_l for t in ["playgirl", "playboy", "goth", "racer", "sweetheart"]):
        return "valentina"
        
    return "dante" # Default dynamic safety fallback

class FirebaseManager:
    """
    Manages Firebase initialization and Firestore operations, 
    with standard fallback support.
    """
    db = None
    initialized = False

    @classmethod
    def init_firestore(cls) -> bool:
        if cls.initialized:
            return cls.db is not None

        if not HAS_FIREBASE:
            logger.warning("FirebaseManager: firebase-admin is not installed.")
            return False

        # Attempt to load credentials
        cred = None
        
        # 1. Search for a JSON file in current directory or backend directory
        cred_paths = [
            os.path.join(os.path.dirname(__file__), "..", "firebase-service-account.json"),
            os.path.join(os.getcwd(), "firebase-service-account.json"),
            os.path.join(os.getcwd(), "backend", "firebase-service-account.json"),
        ]
        
        for path in cred_paths:
            if os.path.exists(path):
                try:
                    cred = credentials.Certificate(path)
                    logger.info(f"FirebaseManager: Found credentials key file at {path}")
                    break
                except Exception as e:
                    logger.error(f"FirebaseManager: Error parsing cert at {path}: {e}")

        # 2. Check environment variables
        if not cred and os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            try:
                cred = credentials.ApplicationDefault()
                logger.info("FirebaseManager: Initializing with GOOGLE_APPLICATION_CREDENTIALS environment key.")
            except Exception as e:
                logger.error(f"FirebaseManager: Error parsing default application creds: {e}")

        # 3. Fallback to default credentials or mock
        if cred:
            try:
                firebase_admin.initialize_app(cred)
                cls.db = firestore.client()
                cls.initialized = True
                logger.info("FirebaseManager: Firestore client successfully initialized.")
                return True
            except Exception as e:
                logger.error(f"FirebaseManager: Error initializing firebase app: {e}")
        else:
            logger.warning("FirebaseManager: Service account key not found. Running in Local Fallback Mode.")
            
        cls.initialized = True
        return False


class NotificationScheduler:
    """
    FastAPI background scheduled orchestrator. Runs timezone-aware pacing checks,
    pacing cooldowns, personality constraints, and dispatches pushed via OneSignal REST.
    """

    @staticmethod
    def get_local_hour(offset_minutes: int) -> int:
        """
        Calculates user local hour based on a dynamic offset in minutes.
        """
        utc_now = datetime.datetime.now(datetime.timezone.utc)
        local_now = utc_now + datetime.timedelta(minutes=offset_minutes)
        return local_now.hour

    @classmethod
    def generate_emotional_message(cls, profile_key: str, summary: Optional[Dict[str, Any]]) -> str:
        """
        Generates a premium personality-specific atmospheric notification,
        optionally incorporating recent emotional memory records (insecurities/habits).
        """
        profile = COMPANION_PROFILES.get(profile_key)
        if not profile:
            return "Thinking of you."

        # Category probabilities:
        # 35% Quiet Presence
        # 30% Romantic Tension
        # 20% Silent reticent nudges
        # 15% Premium voice teasers
        # (If memory exists, 40% chance to overwrite with Emotional Memory)
        
        category_roll = random.random()
        
        # Try emotional memory injection if available
        if summary and random.random() < 0.40:
            user_profile = summary.get("user_profile", {})
            insecurities = user_profile.get("insecurities", [])
            habits = user_profile.get("habits", [])
            
            if insecurities and random.random() < 0.50:
                insec = random.choice(insecurities)
                # Max length check
                if len(insec) < 40:
                    return profile["memory_insecure_template"].format(insecurity=insec.lower().rstrip("."))
            elif habits:
                hab = random.choice(habits)
                if len(hab) < 40:
                    return profile["memory_habit_template"].format(habit=hab.lower().rstrip("."))

        if category_roll < 0.35:
            return random.choice(profile["quiet_presence"])
        elif category_roll < 0.65:
            return random.choice(profile["romantic_tension"])
        elif category_roll < 0.85:
            return random.choice(profile["silent_nudge"])
        else:
            return random.choice(profile["voice_teaser"])

    @classmethod
    async def process_presence_for_user(
        cls, 
        user_id: str, 
        user_data: Dict[str, Any], 
        firestore_client=None,
        ignore_cooldown: bool = False,
        ignore_silence: bool = False,
        ignore_hours: bool = False
    ) -> Optional[Dict[str, Any]]:
        """
        Processes the presence simulation rules for a single user.
        Returns notification payload dict if a push should be sent, else None.
        """
        try:
            player_id = user_data.get("notification_playerId")
            if not player_id:
                return None

            # Get notification preferences
            settings = user_data.get("notification_settings", {})
            notifications_enabled = settings.get("notificationsEnabled", True)
            if not notifications_enabled:
                return None

            late_night_only = settings.get("lateNightMode", False)
            silent_presence = settings.get("silentPresence", False)

            # Get timezone info
            offset_minutes = user_data.get("timezone_offset_minutes", 0)
            local_hour = cls.get_local_hour(offset_minutes)

            # Get last active timestamps
            last_active = user_data.get("last_active_time")
            # If timestamp is firebase Document field, convert to datetime
            if hasattr(last_active, "timestamp"):
                last_active_dt = last_active
            elif isinstance(last_active, str):
                try:
                    last_active_dt = datetime.datetime.fromisoformat(last_active.replace("Z", "+00:00"))
                except:
                    last_active_dt = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)
            else:
                last_active_dt = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)

            # Convert to UTC for checks
            if last_active_dt.tzinfo is None:
                last_active_dt = last_active_dt.replace(tzinfo=datetime.timezone.utc)

            now_utc = datetime.datetime.now(datetime.timezone.utc)
            minutes_since_active = (now_utc - last_active_dt).total_seconds() / 60.0

            # Guard 1: Active user protection. Do not push if active in the last 30 minutes.
            if not ignore_cooldown and minutes_since_active < 30.0:
                logger.info(f"User {user_id} active {minutes_since_active:.1f} mins ago. Suppressing notification.")
                return None

            # Cooldown check
            last_notification = user_data.get("last_notification_time")
            if last_notification:
                if hasattr(last_notification, "timestamp"):
                    last_notif_dt = last_notification
                elif isinstance(last_notification, str):
                    try:
                        last_notif_dt = datetime.datetime.fromisoformat(last_notification.replace("Z", "+00:00"))
                    except:
                        last_notif_dt = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)
                else:
                    last_notif_dt = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)
            else:
                # Default fallback
                last_notif_dt = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)

            if last_notif_dt.tzinfo is None:
                last_notif_dt = last_notif_dt.replace(tzinfo=datetime.timezone.utc)

            hours_since_notif = (now_utc - last_notif_dt).total_seconds() / 3600.0
            
            # Guard 2: Randomized Cooldown window spacing (4-8 hours)
            cooldown = user_data.get("current_cooldown_hours", random.randint(4, 8))
            if not ignore_cooldown and hours_since_notif < cooldown:
                logger.debug(f"User {user_id} cooldown active ({hours_since_notif:.1f}/{cooldown} hours). Skipping.")
                return None

            # Get active companion context
            companion_name = user_data.get("last_active_companion_name", "Dante Valerius")
            companion_id = user_data.get("last_active_companion_id", "1")
            
            # Resolve profile and core energy
            profile_key = get_companion_profile_key(companion_name, "")
            profile = COMPANION_PROFILES[profile_key]

            # Guard 3: Timezone-aware Hour windows alignment
            allowed_hours = profile["hours"]
            if late_night_only:
                # Late night restriction: 10 PM - 6 AM (22:00 to 6:00)
                is_allowed = (local_hour >= 22 or local_hour <= 6)
            else:
                # Personality allowed hour checks
                is_allowed = (local_hour in allowed_hours)

            if not ignore_hours and not is_allowed:
                logger.debug(f"Companion {companion_name} not active at local hour {local_hour} for user {user_id}.")
                return None

            # Guard 4: Probabilistic Scheduling (60% non-performative silence check)
            # 40% chance of trigger when a window opens, keeping timing natural and asymmetrical
            if not ignore_silence and random.random() > 0.40:
                logger.debug(f"Silence check triggered for user {user_id} ({companion_name}). Leaving quiet.")
                return None

            # Fetch Llama memory summary
            summary = None
            if firestore_client:
                # Load from Firestore chats
                chat_id = f"{user_id}_{companion_name}"
                try:
                    chat_doc = firestore_client.collection("chats").document(chat_id).get()
                    if chat_doc.exists:
                        summary = chat_doc.data().get("summary")
                except Exception as e:
                    logger.error(f"Error loading chat summary for {chat_id}: {e}")
            else:
                # Local Mock fallback load
                if os.path.exists(HISTORY_FILE):
                    try:
                        with open(HISTORY_FILE, "r") as f:
                            db = json.load(f)
                            key = f"{user_id}_{companion_name}"
                            summary = db.get(key, {}).get("summary")
                    except Exception as e:
                        logger.error(f"Error reading local summary: {e}")

            # Generate dynamic text
            body = cls.generate_emotional_message(profile_key, summary)
            
            # Assemble Payload
            payload = {
                "player_ids": [player_id],
                "title": companion_name,
                "body": body,
                "data": {
                    "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    "companion_id": companion_id,
                    "companion_name": companion_name,
                    "push_category": "presence_simulation"
                },
                "silent": silent_presence
            }

            # Update notification timestamps to Firestore or locally
            new_cooldown = random.randint(4, 8)
            now_iso = now_utc.isoformat()
            
            if firestore_client:
                # Save back to Cloud Firestore
                await asyncio.to_thread(
                    lambda: firestore_client.collection("users").document(user_id).set({
                        "last_notification_time": firestore.SERVER_TIMESTAMP,
                        "current_cooldown_hours": new_cooldown
                    }, merge=True)
                )
            else:
                # Save locally
                if os.path.exists(HISTORY_FILE):
                    try:
                        with open(HISTORY_FILE, "r") as f:
                            db = json.load(f)
                        meta_key = f"user_meta_{user_id}"
                        meta = db.get(meta_key, {})
                        meta["last_notification_time"] = now_iso
                        meta["current_cooldown_hours"] = new_cooldown
                        db[meta_key] = meta
                        
                        with open(HISTORY_FILE, "w") as f:
                            json.dump(db, f, indent=2)
                    except Exception as e:
                        logger.error(f"Error saving local metadata: {e}")

            logger.info(f"Generated nudge from {companion_name} for user {user_id}: '{body}'")
            return payload
            
        except Exception as e:
            logger.error(f"Error processing user {user_id}: {e}")
            return None

    @classmethod
    async def run_presence_check(cls, ignore_cooldown: bool = False, ignore_silence: bool = False, ignore_hours: bool = False) -> int:
        """
        Scans all users and dispatches push notifications based on active presence parameters.
        Returns the number of pushed dispatched.
        """
        logger.info("Scheduler: Beginning Presence Simulation sweep...")
        sent_count = 0
        
        # Try real Cloud Firestore first
        if FirebaseManager.init_firestore() and FirebaseManager.db:
            try:
                db = FirebaseManager.db
                # Fetch users collection
                users_ref = db.collection("users")
                # Threaded query call
                users_docs = await asyncio.to_thread(lambda: list(users_ref.get()))
                
                for doc in users_docs:
                    user_id = doc.id
                    user_data = doc.to_dict()
                    
                    payload = await cls.process_presence_for_user(
                        user_id, 
                        user_data, 
                        db,
                        ignore_cooldown=ignore_cooldown,
                        ignore_silence=ignore_silence,
                        ignore_hours=ignore_hours
                    )
                    if payload:
                        success = await NotificationRouter.send_notification(
                            player_ids=payload["player_ids"],
                            title=payload["title"],
                            body=payload["body"],
                            data=payload["data"],
                            silent=payload["silent"]
                        )
                        if success:
                            sent_count += 1
                
                logger.info(f"Scheduler sweep finished. Sent {sent_count} pushes via Cloud Firestore.")
                return sent_count
            except Exception as e:
                logger.error(f"Scheduler Cloud Firestore Sweep Failure: {e}")
        
        # Local fallback mode
        logger.info("Scheduler: Running sweep in Local Fallback mode using chat_history.json")
        if os.path.exists(HISTORY_FILE):
            try:
                with open(HISTORY_FILE, "r") as f:
                    db_data = json.load(f)
                
                # Gather users from conversation keys user_companion
                user_ids = set()
                conversations = []
                
                for key in db_data.keys():
                    if "_" in key and not key.startswith("user_meta_"):
                        parts = key.split("_")
                        if len(parts) >= 2:
                            user_ids.add(parts[0])
                            conversations.append((parts[0], parts[1]))
                
                # Scan each identified user
                for user_id in user_ids:
                    meta_key = f"user_meta_{user_id}"
                    meta = db_data.get(meta_key, {})
                    
                    # Resolve last active companion from conversation
                    user_convs = [c for c in conversations if c[0] == user_id]
                    if not user_convs:
                        continue
                    
                    active_companion_name = user_convs[0][1]
                    
                    # Construct local user data
                    local_user_data = {
                        "notification_playerId": meta.get("notification_playerId", "mock_onesignal_id_123"),
                        "notification_settings": meta.get("notification_settings", {
                            "notificationsEnabled": True,
                            "lateNightMode": False,
                            "silentPresence": False
                        }),
                        "timezone_offset_minutes": meta.get("timezone_offset_minutes", 330), # IST default fallback
                        "last_active_time": meta.get("last_active_time", (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=2)).isoformat()),
                        "last_notification_time": meta.get("last_notification_time"),
                        "current_cooldown_hours": meta.get("current_cooldown_hours", 0), # No cooldown default for local testing
                        "last_active_companion_name": active_companion_name,
                        "last_active_companion_id": "1" if active_companion_name == "Dante Valerius" else "11"
                    }
                    
                    # Force process
                    payload = await cls.process_presence_for_user(
                        user_id, 
                        local_user_data, 
                        None,
                        ignore_cooldown=ignore_cooldown,
                        ignore_silence=ignore_silence,
                        ignore_hours=ignore_hours
                    )
                    if payload:
                        success = await NotificationRouter.send_notification(
                            player_ids=payload["player_ids"],
                            title=payload["title"],
                            body=payload["body"],
                            data=payload["data"],
                            silent=payload["silent"]
                        )
                        if success:
                            sent_count += 1
                            
                logger.info(f"Local mock scheduler sweep finished. Sent {sent_count} pushes.")
                return sent_count
            except Exception as e:
                logger.error(f"Scheduler Local mock Sweep Failure: {e}")
                
        return sent_count

# Cron looping worker thread task
async def start_scheduler_loop():
    logger.info("Scheduler: Initializing background cron loop task (60s tick interval)")
    # Delay initial check slightly for app initialization
    await asyncio.sleep(10)
    while True:
        try:
            await NotificationScheduler.run_presence_check()
        except Exception as e:
            logger.error(f"Scheduler loop error: {e}")
        # Periodic sleep duration
        await asyncio.sleep(60)
