import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../auth/onboarding_controller.dart';
import '../../auth/auth_provider.dart';

class LoginOverlay extends ConsumerStatefulWidget {
  const LoginOverlay({super.key});

  @override
  ConsumerState<LoginOverlay> createState() => _LoginOverlayState();
}

class _LoginOverlayState extends ConsumerState<LoginOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showEmailForm = false; // collapsed by default — Google is primary
  bool _isForgotLoading = false;
  String? _forgotMessage;

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
    _emailController.dispose();
    _passwordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth(int mode) async {
    HapticFeedback.lightImpact();
    setState(() => _forgotMessage = null);

    final email = _emailController.text;
    final password = _passwordController.text;

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .handleAuth(mode, email: email, password: password);

    if (success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _forgotMessage =
          '⚠ Enter your email above first, then tap Forgot Password.');
      return;
    }
    setState(() {
      _isForgotLoading = true;
      _forgotMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPassword(email);
      setState(() {
        _forgotMessage =
            '✓ Recovery link sent to $email\nCheck your inbox (and spam folder).';
      });
    } catch (e) {
      setState(() {
        _forgotMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isForgotLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isLogin = state.isLoginMode;

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
                    isLogin ? "Resume Connection" : "Anchor Your Presence",
                    style: GoogleFonts.cinzel(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    isLogin
                        ? "Sign in instantly — no password needed."
                        : "One tap to create your account and never lose this bond.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

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
                          state.isAuthLoading ? null : () => _handleAuth(1),
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
                                  isLogin
                                      ? "Continue with Google"
                                      : "Sign up with Google",
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

                  const SizedBox(height: 10),

                  // ── "One tap — same account each time" note ───────────
                  Text(
                    "Your Google account = your Chatrix account.\nSign in anytime with the same email.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 22),

                  // ── OR divider ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.08))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          "OR",
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.08))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Email/Password toggle ────────────────────────────
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showEmailForm = !_showEmailForm);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: ChatrixTheme.bioluminescence
                                .withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isLogin
                                  ? "Use email & password instead"
                                  : "Register with email & password",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            _showEmailForm
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Collapsible Email Form ────────────────────────────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _showEmailForm
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: _buildEmailForm(state, isLogin),
                    secondChild: const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // ── Mode Toggle ───────────────────────────────────────
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _forgotMessage = null;
                        _showEmailForm = false;
                      });
                      ref
                          .read(onboardingControllerProvider.notifier)
                          .toggleAuthMode();
                    },
                    child: Text(
                      isLogin
                          ? "First time here? Create an account →"
                          : "Already connected? Sign in →",
                      style: GoogleFonts.inter(
                        color: ChatrixTheme.bioluminescence.withValues(alpha: 0.8),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            ChatrixTheme.bioluminescence.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }

  // ── Email / Password expandable form ────────────────────────────────────────
  Widget _buildEmailForm(OnboardingState state, bool isLogin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        _buildTextField(
          controller: _emailController,
          hint: "Email address",
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 12),

        _buildTextField(
          controller: _passwordController,
          hint: "Password",
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          isPassword: true,
        ),

        // ── Forgot Password ─────────────────────────────────────
        if (isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isForgotLoading ? null : _handleForgotPassword,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isForgotLoading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white30, strokeWidth: 1.5),
                    )
                  : Text(
                      "Forgot password?",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
            ),
          ),

        // ── Forgot / success message ─────────────────────────────
        if (_forgotMessage != null)
          _buildBanner(
            message: _forgotMessage!,
            isSuccess: _forgotMessage!.startsWith('✓'),
          ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // ── Submit button ───────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ChatrixTheme.bioluminescence,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: state.isAuthLoading ? null : () => _handleAuth(0),
            child: state.isAuthLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isLogin ? "Sign In" : "Create Account",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
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

  // ── Text Field ──────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
          prefixIcon: Icon(
            icon,
            color: ChatrixTheme.bioluminescence.withValues(alpha: 0.5),
            size: 20,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white30,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
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
