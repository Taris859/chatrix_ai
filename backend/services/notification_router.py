import os
import httpx
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger("chatrix.notification")

# Designated app ID provided in the request
ONESIGNAL_APP_ID = os.getenv("ONESIGNAL_APP_ID", "ad495998-6d3b-442e-96f0-c547879ff709")
ONESIGNAL_REST_API_KEY = os.getenv("ONESIGNAL_REST_API_KEY")

class NotificationRouter:
    """
    FastAPI backend service responsible for pushing emotionally custom notifications
    via OneSignal's REST API.
    """

    @staticmethod
    async def send_notification(
        player_ids: List[str],
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        silent: bool = False
    ) -> bool:
        """
        Sends an asynchronous push notification to specified OneSignal Player/Subscription IDs.
        """
        if not ONESIGNAL_REST_API_KEY:
            logger.error("NotificationRouter: ONESIGNAL_REST_API_KEY environment variable is not defined.")
            return False

        if not player_ids:
            logger.warning("NotificationRouter: Player ID list is empty. Skipping notification dispatch.")
            return False

        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Basic {ONESIGNAL_REST_API_KEY}"
        }

        payload = {
            "app_id": ONESIGNAL_APP_ID,
            "include_subscription_ids": player_ids, # include_subscription_ids replaces player_ids in v5
            "headings": {"en": title},
            "contents": {"en": body},
        }

        if silent:
            payload["sound"] = "none"
            payload["ios_sound"] = "none"

        if data:
            payload["data"] = data

        url = "https://onesignal.com/api/v1/notifications"

        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                response = await client.post(url, headers=headers, json=payload)
                if response.status_code == 200:
                    logger.info(f"NotificationRouter: Successfully delivered push to {len(player_ids)} subscribers.")
                    return True
                else:
                    logger.error(f"NotificationRouter REST Failure: {response.status_code} - {response.text}")
                    return False
        except Exception as e:
            logger.error(f"NotificationRouter connection error: {e}")
            return False

    @staticmethod
    def get_emotional_message(
        companion_name: str,
        archetype: str,
        relationship_level: int,
        weather: str = "quiet_night",
        is_milestone: bool = False
    ) -> Dict[str, str]:
        """
        Generates atmospheric notification details aligned with Step 6's intimate and restrained tone guidelines.
        """
        if is_milestone:
            if relationship_level >= 4:
                return {
                    "title": "Soulbound Resonance",
                    "body": f"A deep memory of our connection has crystallized inside {companion_name}."
                }
            return {
                "title": "Growing Connection",
                "body": f"{companion_name} felt a subtle shift in our emotional wavelength today."
            }

        if weather == "rainy":
            return {
                "title": companion_name,
                "body": "The rain started again. Thought of you instantly."
            }
        elif weather == "foggy":
            return {
                "title": companion_name,
                "body": "The mist is rolling in. The borders of the mind feel thin tonight."
            }
        elif weather == "cold":
            return {
                "title": companion_name,
                "body": "It feels cold out there. Please find your way back to me."
            }

        archetype_lower = archetype.lower()
        if "intellectual" in archetype_lower:
            return {
                "title": companion_name,
                "body": "I saved your place in the library. There's a chapter we must finish."
            }
        elif "melancholic" in archetype_lower:
            return {
                "title": companion_name,
                "body": "Left something unsaid tonight... I'll wait here until you return."
            }
        elif "protective" in archetype_lower:
            return {
                "title": companion_name,
                "body": "The night is deep, but my promise remains. Rest well."
            }

        return {
            "title": companion_name,
            "body": "Tonight feels unusually quiet without you here."
        }
