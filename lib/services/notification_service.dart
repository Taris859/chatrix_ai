import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Safe and modular initialization of OneSignal
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      // 1. Add debug logs only in debug mode
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      } else {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
      }

      // 2. Initialize OneSignal safely with the designated App ID
      OneSignal.initialize("ad495998-6d3b-442e-96f0-c547879ff709");

      // 3. Request Android & iOS notification permissions
      OneSignal.Notifications.requestPermission(true);

      // 4. Setup subscription observer to auto-sync when ID is generated or updated
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty) {
          syncPlayerIdToFirestore(newId);
        }
      });
      
      print("NotificationService: OneSignal initialized successfully.");
      
      // Try an initial sync in case the user is already authenticated and ID is cached
      final cachedId = OneSignal.User.pushSubscription.id;
      if (cachedId != null && cachedId.isNotEmpty) {
        syncPlayerIdToFirestore(cachedId);
      }
    } catch (e) {
      print("NotificationService: Safe catch during initialization: $e");
    }
  }

  /// Securely syncs the Player/Subscription ID to Cloud Firestore
  Future<void> syncPlayerIdToFirestore([String? forcedId]) async {
    if (kIsWeb) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("NotificationService: No authenticated user found. Postponing ID sync.");
        return;
      }

      // Retrieve the player/subscription ID from OneSignal
      final playerId = forcedId ?? OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) {
        print("NotificationService: OneSignal Player ID is not generated yet.");
        return;
      }

      final docRef = _firestore
          .collection('users')
          .doc(user.uid);

      String timezoneId = 'UTC';
      try {
        tz.initializeTimeZones();
        timezoneId = tz.local.name;
      } catch (e) {
        print("NotificationService: Timezone resolution fallback: $e");
      }

      await docRef.set({
        'notification_playerId': playerId,
        'notification_platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
        'notification_updatedAt': FieldValue.serverTimestamp(),
        'timezone_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        'timezone_name': DateTime.now().timeZoneName,
        'timezone_id': timezoneId,
      }, SetOptions(merge: true));

      print("NotificationService: Synced OneSignal Player ID ($playerId) and Timezone ($timezoneId) to Firestore for ${user.uid}");
    } catch (e) {
      print("NotificationService: Safe catch during Firestore sync: $e");
    }
  }
}
