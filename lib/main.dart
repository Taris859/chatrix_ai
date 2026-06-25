import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'ui/navigation/luxury_bottom_nav.dart';
import 'ui/auth/onboarding_screen.dart';
import 'ui/auth/email_verification_screen.dart';
import 'auth/auth_provider.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/autonomous_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'services/config_service.dart';
import 'services/voice_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase init error: $e");
  }
  
  // Safe initialization of OneSignal notifications
  await NotificationService().initialize();
  
  // Safe initialization of Autonomous Local Notifications
  await AutonomousNotificationService().initialize();

  // Process web deep links/referrals/companion parameters
  if (kIsWeb) {
    try {
      final uri = Uri.base;
      final segments = uri.pathSegments;
      final prefs = await SharedPreferences.getInstance();

      // Check for invite path: e.g. /invite/CODE
      if (segments.length >= 2 && segments[0] == 'invite') {
        final code = segments[1];
        if (code.isNotEmpty) {
          await prefs.setString('pending_referral_code', code.toUpperCase());
          print("Cached pending referral code from URL path: $code");
        }
      } 
      
      // Check for ref query parameter: e.g. ?ref=CODE
      final refCode = uri.queryParameters['ref'];
      if (refCode != null && refCode.isNotEmpty) {
        await prefs.setString('pending_referral_code', refCode.toUpperCase());
        print("Cached pending referral code from URL query: $refCode");
      }

      // Check for companion query parameter: e.g. ?companion=ID
      final companionId = uri.queryParameters['companion'];
      if (companionId != null && companionId.isNotEmpty) {
        await prefs.setString('pending_companion_id', companionId);
        print("Cached pending companion ID from URL: $companionId");
      }
    } catch (e) {
      print("Error parsing startup URL segments/queries: $e");
    }
  }
 
  // Async preload of backend configuration (ElevenLabs key)
  _preloadConfig();
 
  runApp(
    const ProviderScope(
      child: ChatrixApp(),
    ),
  );
}

Future<void> _preloadConfig() async {
  try {
    final config = await ConfigService().fetchConfig();
    if (config != null) {
      final elevenlabsKey = config['elevenlabs_key'];
      if (elevenlabsKey != null && elevenlabsKey is String && elevenlabsKey.isNotEmpty) {
        VoiceService().updateApiKey(elevenlabsKey);
      }
    }
  } catch (e) {
    print("Error preloading config: $e");
  }
}

class ChatrixApp extends ConsumerWidget {
  const ChatrixApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final otpVerified = ref.watch(otpVerifiedProvider);

    return MaterialApp(
      title: 'Chatrix',
      debugShowCheckedModeBanner: false,
      theme: ChatrixTheme.darkTheme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            // Anonymous users skip verification
            if (user.isAnonymous) return const LuxuryBottomNav();

            // For email/password users: check our Firestore OTP flag
            return otpVerified.when(
              data: (verified) {
                if (verified) return const LuxuryBottomNav();
                return const EmailVerificationScreen();
              },
              loading: () => const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: CircularProgressIndicator(
                      color: ChatrixTheme.bioluminescence),
                ),
              ),
              error: (_, __) => const EmailVerificationScreen(),
            );
          }
          return const OnboardingScreen();
        },
        loading: () => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: CircularProgressIndicator(
                    color: ChatrixTheme.bioluminescence))),
        error: (err, stack) => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: Text("Connection lost...",
                    style: TextStyle(color: Colors.white54)))),
      ),
    );
  }
}
