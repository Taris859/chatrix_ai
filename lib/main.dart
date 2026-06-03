import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'ui/navigation/luxury_bottom_nav.dart';
import 'ui/auth/onboarding_screen.dart';
import 'auth/auth_provider.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/autonomous_notification_service.dart';

import 'services/razorpay_service.dart';
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

  // Async preload of backend configuration (ElevenLabs key, Razorpay key)
  _preloadConfig();

  runApp(
    const ProviderScope(
      child: ChatrixApp(),
    ),
  );
}

Future<void> _preloadConfig() async {
  try {
    final config = await RazorpayService().fetchConfig();
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

    return MaterialApp(
      title: 'Chatrix',
      debugShowCheckedModeBanner: false,
      theme: ChatrixTheme.darkTheme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const LuxuryBottomNav();
          }
          return const OnboardingScreen();
        },
        loading: () => const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))),
        error: (err, stack) => const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Connection lost...", style: TextStyle(color: Colors.white54)))),
      ),
    );
  }
}
