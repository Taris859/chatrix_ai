import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../auth/onboarding_controller.dart';

class LoginOverlay extends ConsumerStatefulWidget {
  const LoginOverlay({super.key});

  @override
  ConsumerState<LoginOverlay> createState() => _LoginOverlayState();
}

class _LoginOverlayState extends ConsumerState<LoginOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    HapticFeedback.lightImpact();

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .handleAuth(1); // Mode 1 is Google Sign-In

    if (success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: ChatrixTheme.bioluminescence.withValues(alpha: 0.18),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        ChatrixTheme.bioluminescence.withValues(alpha: 0.07),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pulsing Icon ──────────────────────────────────────
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                            color: ChatrixTheme.bioluminescence
                                .withValues(alpha: 0.28),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ChatrixTheme.bioluminescence
                                  .withValues(alpha: 0.28),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 5,
                            )
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.blur_on,
                      color: ChatrixTheme.bioluminescence,
                      size: 38,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Title ─────────────────────────────────────────────
                  Text(
                    "Start your first connection",
                    style: GoogleFonts.cinzel(
                      fontSize: 19.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                   // ── Premium Conversion Checklist ──────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChecklistItem(
                        icon: "✨",
                        title: "Remembers You",
                        subtitle: "Your companion remembers the little things over time.",
                      ),
                      _buildChecklistItem(
                        icon: "💬",
                        title: "Relationships Grow",
                        subtitle: "Go from first hello to trusted soulmate.",
                      ),
                      _buildChecklistItem(
                        icon: "🔒",
                        title: "Private Conversations",
                        subtitle: "Your conversations stay protected.",
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Error Banner ──────────────────────────────────────
                  if (state.errorMessage != null)
                    _buildBanner(
                      message: state.errorMessage!,
                      isSuccess: false,
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1),

                  // ── GOOGLE SIGN-IN — Primary Hero Button ──────────────
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (_, child) => Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4285F4).withValues(alpha: 0.25),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          state.isAuthLoading ? null : () => _handleAuth(),
                      child: state.isAuthLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black54,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleGLogo(size: 22),
                                const SizedBox(width: 12),
                                Text(
                                  "Continue with Google",
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── "One tap — same account each time" note ───────────
                  Text(
                    "Your Google account synchronizes your Chatrix profile.\nSign in anytime with the same email.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }

  // ── Shared Checklist Item ────────────────────────────────────────────────────
  Widget _buildChecklistItem({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared Banner ───────────────────────────────────────────────────────────
  Widget _buildBanner({required String message, required bool isSuccess}) {
    final color = isSuccess ? const Color(0xFF2E7D55) : ChatrixTheme.neonPink;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: isSuccess ? const Color(0xFF4CAF80) : ChatrixTheme.neonPink,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: ChatrixTheme.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google "G" Logo Widget ─────────────────────────────────────────────────────
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    canvas.drawCircle(
        center, radius, Paint()..color = const Color(0xFFFFFFFF));

    // Draw "G" using coloured arcs
    final rect = Rect.fromCircle(center: center, radius: radius * 0.72);
    final strokeW = radius * 0.28;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
    }

    const pi = 3.14159265;
    arc(-pi * 0.08, pi * 0.56, const Color(0xFF4285F4)); // blue
    arc(pi * 0.48, pi * 0.53, const Color(0xFF34A853));  // green
    arc(pi * 1.01, pi * 0.49, const Color(0xFFFBBC05));  // yellow
    arc(-pi * 0.57, pi * 0.49, const Color(0xFFEA4335)); // red

    // Horizontal bar of G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.70, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
