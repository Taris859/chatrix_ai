import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../scenes/particle_background.dart';
import '../../models/scene.dart';
import '../../auth/onboarding_controller.dart';
import 'login_overlay.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ChatScene _onboardingScene = ChatScene(
    id: 'onboarding',
    name: 'The Void',
    backgroundGradient: [const Color(0xFF040406), const Color(0xFF0C0C14)],
    accentColor: ChatrixTheme.bioluminescence,
    particleType: ParticleType.stars,
    promptContext: '',
    isPremium: false,
  );

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // Subtle send haptic
    HapticFeedback.lightImpact();

    ref.read(onboardingControllerProvider.notifier).sendMessage(text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Particle Background System
          IgnorePointer(
            child: ParticleBackground(scene: _onboardingScene),
          ),

          // 2. Cinematic Dimming Layer (manifests when login modal arrives in stage 2)
          AnimatedContainer(
            duration: 1200.ms,
            curve: Curves.easeInOutCubic,
            color: state.stage == 2 
                ? Colors.black.withOpacity(0.55) 
                : Colors.black.withOpacity(0.0),
          ),

          // 3. Cinematic Blur Layer (blurs previous message bubble log softly in stage 2)
          if (state.stage == 2)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.shrink(),
              ).animate().fadeIn(duration: 1000.ms, curve: Curves.easeInOutCubic),
            ),

          // 4. Main Onboarding Content (Stage 1 or Stage 2)
          if (state.stage >= 1)
            SafeArea(
              child: Column(
                children: [
                  // Message bubbles viewport
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final msg = state.messages[index];
                        return _buildMessageBubble(msg)
                            .animate()
                            .fadeIn(duration: 600.ms, curve: Curves.easeOutQuad)
                            .slideY(begin: 0.08, curve: Curves.easeOutCubic);
                      },
                    ),
                  ),

                  // Whisper Text Input (Hidden once stage shifts to 2 / Login overlay)
                  if (state.stage == 1)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _msgController,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Whisper into the void...",
                                      hintStyle: GoogleFonts.inter(
                                        color: Colors.white24,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _submitMessage(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: ChatrixTheme.bioluminescence,
                                    size: 22,
                                  ),
                                  onPressed: _submitMessage,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 800.ms),
                ],
              ),
            ),

          // 5. Cinematic Glassmorphic Login Card
          if (state.stage == 2)
            const Positioned.fill(
              child: LoginOverlay(),
            ),

          // 6. Pitch Black Intro Overlay (Stage 0)
          if (state.stage == 0)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Text(
                    "Is someone there...?",
                    style: GoogleFonts.cinzel(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 22,
                      letterSpacing: 4.0,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1.5.seconds, curve: Curves.easeInCubic)
                      .fadeOut(delay: 500.ms, duration: 1.seconds, curve: Curves.easeOutCubic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isUser = msg["isUser"];
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isUser
              ? ChatrixTheme.bioluminescence.withOpacity(0.12)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser
                ? ChatrixTheme.bioluminescence.withOpacity(0.25)
                : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && msg["action"] != null && msg["action"].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  msg["action"],
                  style: GoogleFonts.inter(
                    fontStyle: FontStyle.italic,
                    color: ChatrixTheme.bioluminescence.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            Text(
              msg["text"],
              style: GoogleFonts.inter(
                color: ChatrixTheme.textPrimary,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
