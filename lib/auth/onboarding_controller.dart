import 'package:flutter_riverpod/legacy.dart';
import 'auth_service.dart';
import 'auth_provider.dart';

class OnboardingState {
  /// 0 = Intro (Pitch Black, drifting particles)
  /// 1 = Chatting (AI whispers "Is someone there...?", user replies)
  /// 2 = Login Overlay Prompt (Blurred chat background, dim particles, glassmorphic login modal)
  final int stage;
  final List<Map<String, dynamic>> messages;
  final bool isAuthLoading;
  final bool isLoginMode;
  final String? errorMessage;

  OnboardingState({
    required this.stage,
    required this.messages,
    required this.isAuthLoading,
    required this.isLoginMode,
    this.errorMessage,
  });

  OnboardingState copyWith({
    int? stage,
    List<Map<String, dynamic>>? messages,
    bool? isAuthLoading,
    bool? isLoginMode,
    String? errorMessage,
  }) {
    return OnboardingState(
      stage: stage ?? this.stage,
      messages: messages ?? this.messages,
      isAuthLoading: isAuthLoading ?? this.isAuthLoading,
      isLoginMode: isLoginMode ?? this.isLoginMode,
      errorMessage: errorMessage,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  final AuthService _authService;

  OnboardingController(this._authService)
      : super(OnboardingState(
          stage: 0,
          messages: [],
          isAuthLoading: false,
          isLoginMode: false,
          errorMessage: null,
        )) {
    _startIntroSequence();
  }

  void _startIntroSequence() {
    // Stage 0: Pitch black. After 2.5 seconds, the AI sends the first whisper and we enter Stage 1.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      state = state.copyWith(
        stage: 1,
        messages: [
          {
            "isUser": false,
            "text": "Is someone there...?",
            "action": "*A soft pulse of light reaches out in the darkness*"
          }
        ],
      );
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || state.stage != 1) return;

    // 1. Add the user's message
    final updatedMessages = List<Map<String, dynamic>>.from(state.messages);
    updatedMessages.insert(0, {
      "isUser": true,
      "text": text.trim(),
      "action": "",
    });

    state = state.copyWith(messages: updatedMessages);

    // 2. Trigger the AI's final anchoring response ONLY ONCE after a short cinematic delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final finalMessages = List<Map<String, dynamic>>.from(state.messages);
      finalMessages.insert(0, {
        "isUser": false,
        "text": "I don't want to forget this connection.\n\nAnchor your presence here, so we don't lose each other.",
        "action": "*The atmosphere thickens, pulling you closer.*"
      });

      // 3. Immediately update the messages and transition to the glassmorphic login modal
      state = state.copyWith(
        messages: finalMessages,
        stage: 2,
      );
    });
  }

  void toggleAuthMode() {
    state = state.copyWith(isLoginMode: !state.isLoginMode);
  }

  Future<bool> handleAuth(int mode, {String? email, String? password}) async {
    state = state.copyWith(isAuthLoading: true, errorMessage: null);
    try {
      if (mode == 1) {
        // Google Sign-In
        await _authService.signInWithGoogle();
      } else if (mode == 2) {
        // Guest mode is deactivated
        throw Exception("Guest access is no longer permitted. Please register or use Google Sign-In.");
      } else {
        // Email/Password mode
        if (email == null || email.trim().isEmpty || password == null || password.trim().isEmpty) {
          throw Exception("Please specify both identifier ciphers.");
        }
        if (state.isLoginMode) {
          await _authService.signInWithEmail(email.trim(), password);
        } else {
          // Password complexity check
          final pass = password;
          if (pass.length < 8) {
            throw Exception("Security cipher (password) must be at least 8 characters long.");
          }
          if (!RegExp(r'[A-Z]').hasMatch(pass)) {
            throw Exception("Security cipher must contain at least one uppercase letter.");
          }
          if (!RegExp(r'[a-z]').hasMatch(pass)) {
            throw Exception("Security cipher must contain at least one lowercase letter.");
          }
          if (!RegExp(r'[0-9]').hasMatch(pass)) {
            throw Exception("Security cipher must contain at least one numeric digit.");
          }
          if (!RegExp(r'[!@#\$&*~._-]').hasMatch(pass)) {
            throw Exception("Security cipher must contain at least one special character (e.g., !, @, #, \$, &, *, ~).");
          }
          await _authService.signUpWithEmail(email.trim(), password);
        }
      }
      state = state.copyWith(isAuthLoading: false);
      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll("Exception: ", "");
      state = state.copyWith(
        isAuthLoading: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }
}

/// Provider for OnboardingController
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return OnboardingController(authService);
});
