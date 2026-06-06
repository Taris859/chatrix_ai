from services.notification_scheduler import NotificationScheduler

class NotificationService:
    @staticmethod
    async def run_presence_check(ignore_cooldown: bool = False, ignore_silence: bool = False, ignore_hours: bool = False):
        return await NotificationScheduler.run_presence_check(
            ignore_cooldown=ignore_cooldown,
            ignore_silence=ignore_silence,
            ignore_hours=ignore_hours
        )
