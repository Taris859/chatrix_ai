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

  runApp(
    const ProviderScope(
      child: ChatrixApp(),
    ),
  );
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
