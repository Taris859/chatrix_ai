import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final premiumStatusProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(authServiceProvider).isPremium();
});

/// Checks if the current email/password user has completed OTP verification.
/// Always true for Google sign-ins and anonymous users.
final otpVerifiedProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(authServiceProvider).isOtpVerified();
});
