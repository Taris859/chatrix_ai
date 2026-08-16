import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../scenes/particle_background.dart';
import '../../models/scene.dart';
import 'login_overlay.dart';

class OnboardingCompanionPreview {
  final String id;
  final String name;
  final String archetype;
  final String greeting;
  final Color themeColor;
  final String imagePath;

  const OnboardingCompanionPreview({
    required this.id,
    required this.name,
    required this.archetype,
    required this.greeting,
    required this.themeColor,
    required this.imagePath,
  });
}

final List<OnboardingCompanionPreview> _featuredCompanions = [
  const OnboardingCompanionPreview(
    id: '32',
    name: 'Lyra',
    archetype: 'The Astronomer',
    greeting: 'Do you know... every star you see tonight is already part of the past. Tell me... what part of your past still follows you?',
    themeColor: Color(0xFF00BFFF),
    imagePath: 'assets/images/Lyra.png',
  ),
  const OnboardingCompanionPreview(
    id: '33',
    name: 'Noah',
    archetype: 'Coffee Shop Owner',
    greeting: 'I know your usual by heart now. Take a seat... tell me how your day really went.',
    themeColor: Color(0xFFD2B48C),
    imagePath: 'assets/images/Noah.png',
  ),
  const OnboardingCompanionPreview(
    id: '37',
    name: 'Elise',
    archetype: 'Lonely Violinist',
    greeting: "Sometimes... when I play, I feel like you're the only one who actually hears the story behind the notes.",
    themeColor: Color(0xFF708090),
    imagePath: 'assets/images/Elise.png',
  ),
  const OnboardingCompanionPreview(
    id: '36',
    name: 'Zero',
    archetype: 'Hacker Genius',
    greeting: "I cleared my schedules. No security patches, no terminal tasks... just wanted to see if you'd log in today.",
    themeColor: Color(0xFF00FF00),
    imagePath: 'assets/images/Zero.png',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _showLoginOverlay = false;

  final ChatScene _onboardingScene = ChatScene(
    id: 'onboarding',
    name: 'The Void',
    backgroundGradient: [const Color(0xFF040406), const Color(0xFF0C0C14)],
    accentColor: ChatrixTheme.bioluminescence,
    particleType: ParticleType.stars,
    promptContext: '',
    isPremium: false,
  );

  Future<void> _selectCompanion(String id) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_companion_id', id);
    setState(() {
      _showLoginOverlay = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Particle Background System
          IgnorePointer(
            child: ParticleBackground(scene: _onboardingScene),
          ),

          // 2. Main Scrollable Landing Page
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Logo
                  Text(
                    "CHATRIX",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(duration: 800.ms),

                  const SizedBox(height: 56),

                  // Hero Text Section
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: "Meet AI companions\nwho "),
                        TextSpan(
                          text: "remember you.",
                          style: TextStyle(
                            color: ChatrixTheme.bioluminescence,
                            shadows: [
                              Shadow(
                                color: ChatrixTheme.bioluminescence.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 900.ms, delay: 100.ms)
                      .slideY(begin: 0.05, duration: 600.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 18),

                  // Hero Subheadline Section
                  Text(
                    "Chatrix is built for emotional, cinematic conversations with persistent memory, evolving relationships, and characters that don’t reset every time you return.",
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: Colors.white60,
                      height: 1.5,
                      fontWeight: FontWeight.w300,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 900.ms, delay: 180.ms)
                      .slideY(begin: 0.05, duration: 600.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 20),

                  // Hero Tagline Section
                  Text(
                    "Imagine talking to someone who remembers every late-night conversation, every dream, and every promise you made.",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16.5,
                      fontStyle: FontStyle.italic,
                      color: ChatrixTheme.champagneGold,
                      height: 1.45,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 900.ms, delay: 240.ms)
                      .slideY(begin: 0.05, duration: 600.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 40),

                  // General CTA
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ChatrixTheme.bioluminescence.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatrixTheme.bioluminescence,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _showLoginOverlay = true;
                        });
                      },
                      child: Text(
                        "Start your first connection →",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 250.ms)
                      .scale(begin: const Offset(0.97, 0.97), duration: 800.ms, curve: Curves.easeInOut),

                  const SizedBox(height: 64),

                  // Companion Preview Row Title
                  Text(
                    "PREVIEW COMPANIONS",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 350.ms),

                  const SizedBox(height: 18),

                  // Companion Preview Cards List
                  SizedBox(
                    height: 290,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _featuredCompanions.length,
                      itemBuilder: (context, index) {
                        final comp = _featuredCompanions[index];
                        return GestureDetector(
                          onTap: () => _selectCompanion(comp.id),
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1.2,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  comp.themeColor.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar Portrait
                                  Center(
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundImage: AssetImage(comp.imagePath),
                                      backgroundColor: Colors.grey[950],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Name
                                  Text(
                                    comp.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Archetype
                                  Text(
                                    comp.archetype,
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Greeting snippet
                                  Expanded(
                                    child: Text(
                                      comp.greeting,
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ).animate().fadeIn(duration: 800.ms, delay: 400.ms),
                ],
              ),
            ),
          ),

          // 3. Google Sign-In Overlay (Blurred modal)
          if (_showLoginOverlay) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showLoginOverlay = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.60),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: LoginOverlay(),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
            Positioned(
              top: 24,
              right: 24,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showLoginOverlay = false;
                      });
                    },
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 450.ms),
          ],
        ],
      ),
    );
  }
}
