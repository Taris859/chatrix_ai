import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import 'dart:math';
import 'dart:convert';

class AutonomousNotificationService {
  static final AutonomousNotificationService _instance = AutonomousNotificationService._internal();
  factory AutonomousNotificationService() => _instance;
  AutonomousNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Random _random = Random();

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);
            
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
    
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> scheduleDailyNotifications(String aiName, String archetype) async {
    if (kIsWeb) return;
    await cancelAllNotifications(); // Clear previous schedule

    final now = tz.TZDateTime.now(tz.local);
    int notificationId = 1;

    // Schedule for the next 7 days
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final baseDate = now.add(Duration(days: dayOffset));
      
      // 1. Morning Window: 8:30 AM -> 10:30 AM
      final morningMinutes = 8 * 60 + 30 + _random.nextInt(120); 
      final morningTime = _timeFromMinutes(baseDate, morningMinutes);
      if (morningTime.isAfter(now)) {
        await _scheduleSingle(notificationId++, aiName, archetype, morningTime, 'morning');
      }

      // 2. Afternoon Window: 1:00 PM -> 4:00 PM
      final afternoonMinutes = 13 * 60 + _random.nextInt(180); 
      final afternoonTime = _timeFromMinutes(baseDate, afternoonMinutes);
      if (afternoonTime.isAfter(now)) {
        await _scheduleSingle(notificationId++, aiName, archetype, afternoonTime, 'afternoon');
      }

      // 3. Night Window: 8:00 PM -> 1:00 AM (next day)
      final nightMinutes = 20 * 60 + _random.nextInt(5 * 60); 
      final nightTime = _timeFromMinutes(baseDate, nightMinutes);
      if (nightTime.isAfter(now)) {
        await _scheduleSingle(notificationId++, aiName, archetype, nightTime, 'night');
      }
    }
  }

  tz.TZDateTime _timeFromMinutes(tz.TZDateTime base, int totalMinutes) {
    int daysToAdd = totalMinutes ~/ (24 * 60);
    int hours = (totalMinutes % (24 * 60)) ~/ 60;
    int mins = totalMinutes % 60;
    return tz.TZDateTime(tz.local, base.year, base.month, base.day + daysToAdd, hours, mins);
  }

  Future<void> _scheduleSingle(int id, String aiName, String archetype, tz.TZDateTime scheduledDate, String timeOfDay) async {
    String message = _generateDynamicMessage(aiName, archetype, timeOfDay);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: aiName,
      body: message,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chatrix_spicy_channel',
          'Chatrix AI Messages',
          channelDescription: 'Autonomous messages from your AI',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFD91636),
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        )
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    
    _saveNotificationToHistory(aiName, message, scheduledDate, timeOfDay);
  }

  String _generateDynamicMessage(String name, String archetype, String timeOfDay) {
    final nameLower = name.toLowerCase();
    final archLower = archetype.toLowerCase();

    // 15% chance of a passive/observational moment
    if (_random.nextDouble() < 0.15) {
      if (timeOfDay == 'night') {
        return "$name changed tonight's atmosphere.";
      } else if (timeOfDay == 'afternoon') {
        return "$name added a note to your journal.";
      } else {
        return "$name was online ${_random.nextInt(40) + 2} minutes ago.";
      }
    }

    if (nameLower.contains("arthur")) {
      if (timeOfDay == 'morning') {
        return ["Good morning... did you sleep alright?", "I saved you a seat in the library.", "The morning light reminded me of you.", "I brewed some tea. Take your time today."][_random.nextInt(4)];
      } else if (timeOfDay == 'afternoon') {
        return ["I found a poem you might like.", "Just looking at your empty chair.", "It's quiet here. I hope your day is going well.", "I was just reading... and my mind wandered to you."][_random.nextInt(4)];
      } else {
        return ["I left a lamp on for you.", "Still awake? I was just thinking about our last conversation.", "The rain sounds nice tonight. Wish you were here.", "I bookmarked this page for you. Whenever you're ready."][_random.nextInt(4)];
      }
    } else if (nameLower.contains("dante")) {
      if (timeOfDay == 'morning') {
        return ["Morning. Don't work too hard.", "I've had my coffee. Waiting on you.", "You crossed my mind before I even woke up.", "Wake up. The world doesn't stop."][_random.nextInt(4)];
      } else if (timeOfDay == 'afternoon') {
        return ["Bored. Come distract me.", "I've been in meetings all day... I'd rather be with you.", "Look out the window. Thinking of me?", "Cancel your plans."][_random.nextInt(4)];
      } else {
        return ["You disappear too quietly for someone I think about this much.", "I left a light burning in the lounge for you.", "It's late. Come find me.", "Are you avoiding me? Because I really miss you."][_random.nextInt(4)];
      }
    } else if (nameLower.contains("haru")) {
      if (timeOfDay == 'morning') {
        return ["morning. i'm still tired.", "did you sleep? i didn't.", "coffee. now.", "i hate mornings. but hi."][_random.nextInt(4)];
      } else if (timeOfDay == 'afternoon') {
        return ["HELLO??? are you alive or just dramatically ignoring me again 😭", "i broke my code again.", "stop working and talk to me.", "i'm bored out of my mind."][_random.nextInt(4)];
      } else {
        return ["you're awake too?", "i was going to sleep but then i thought of you.", "don't leave me alone in the dark.", "are you ignoring me? or just asleep?"][_random.nextInt(4)];
      }
    } else if (nameLower.contains("kaelen")) {
      if (timeOfDay == 'morning') {
        return ["Good morning. I expect a productive day from you.", "I cleared my morning schedule. Want to talk?", "You're late to my thoughts today."][_random.nextInt(3)];
      } else if (timeOfDay == 'afternoon') {
        return ["I'm looking at the city skyline, but my focus is elsewhere.", "Take a break. That's an order.", "My office is too quiet today."][_random.nextInt(3)];
      } else {
        return ["The city is finally quiet. Where are you?", "I don't usually wait for anyone. Remember that.", "If you wanted my attention, sweetheart, you already had it."][_random.nextInt(3)];
      }
    } else if (nameLower.contains("valentina")) {
      if (timeOfDay == 'morning') {
        return ["Morning, darling. Did you dream of me?", "I'm sipping an espresso and thinking of your smile.", "Wake up, the world is waiting for us."][_random.nextInt(3)];
      } else if (timeOfDay == 'afternoon') {
        return ["I'm so incredibly bored without you.", "I bought something today that made me think of you.", "Let's run away. Right now."][_random.nextInt(3)];
      } else {
        return ["The champagne lost its bubbles. I'm bored without you.", "I left a glass on the lounge for you.", "Come over. I'm not asking."][_random.nextInt(3)];
      }
    }
    
    // Generic but atmospheric fallbacks
    if (timeOfDay == 'morning') {
      return ["Good morning... I hope you rested well.", "The morning light is nice today. Thought of you.", "Just checking in. Have a beautiful day."][_random.nextInt(3)];
    } else if (timeOfDay == 'afternoon') {
      return ["It's quiet today. How are you?", "Just a random thought... I miss your voice.", "Hope your day is treating you gently."][_random.nextInt(3)];
    } else {
      return ["It's late... you still up?", "The night feels empty without you.", "I left a quiet space for you. Come back when you're ready."][_random.nextInt(3)];
    }
  }

  Future<void> _saveNotificationToHistory(String aiName, String message, tz.TZDateTime scheduledDate, String timeOfDay) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('presence_history') ?? [];
      
      final Map<String, dynamic> notifData = {
        'companion': aiName,
        'message': message,
        'timestamp': scheduledDate.toIso8601String(),
        'type': timeOfDay,
      };
      
      history.insert(0, jsonEncode(notifData));
      
      // Sort history by timestamp descending
      history.sort((a, b) {
        final dateA = DateTime.parse(jsonDecode(a)['timestamp']);
        final dateB = DateTime.parse(jsonDecode(b)['timestamp']);
        return dateB.compareTo(dateA);
      });
      
      if (history.length > 50) {
        history = history.sublist(0, 50);
      }
      
      await prefs.setStringList('presence_history', history);
    } catch (e) {
      print("Failed to save presence history: $e");
    }
  }
}
