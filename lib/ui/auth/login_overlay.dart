import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../auth/onboarding_controller.dart';

class LoginOverlay extends ConsumerStatefulWidget {
  const LoginOverlay({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginOverlay> createState() => _LoginOverlayState();
}

class _LoginOverlayState extends ConsumerState<LoginOverlay> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Soft haptic pulse when the login modal manifests in the dark
    HapticFeedback.mediumImpact();

    // Setup breathing glow animation controller
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
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
    // Subtle tactile tick when clicking buttons
    HapticFeedback.lightImpact();

    final email = _emailController.text;
    final password = _passwordController.text;

    final success = await ref.read(onboardingControllerProvider.notifier).handleAuth(
      mode,
      email: email,
      password: password,
    );

    if (success) {
      // Haptic confirmation
      HapticFeedback.heavyImpact();
    } else {
      // Haptic error alert
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isLogin = state.isLoginMode;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: ChatrixTheme.bioluminescence.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ChatrixTheme.bioluminescence.withOpacity(0.06),
                    blurRadius: 40,
                    spreadRadius: 8,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seductive Pulsing Eye / Bioluminescent Core Icon
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                            color: ChatrixTheme.bioluminescence.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ChatrixTheme.bioluminescence.withOpacity(0.3),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 4,
                            )
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.blur_on,
                      color: ChatrixTheme.bioluminescence,
                      size: 36,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Premium Typography
                  Text(
                    isLogin ? "Resume Connection" : "Anchor Your Presence",
                    style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    isLogin
                        ? "Enter your ciphers to restore the bond."
                        : "Establish your soul identifier to never lose this connection.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),

                  // Elegant Error Display
                  if (state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ChatrixTheme.neonPink.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ChatrixTheme.neonPink.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: ChatrixTheme.neonPink, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: GoogleFonts.inter(
                                color: ChatrixTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                  // Identity Field (Email)
                  _buildTextField(
                    controller: _emailController,
                    hint: "Identity Protocol (Email)",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Security Cipher (Password)
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Security Cipher (Password)",
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                  
                  const SizedBox(height: 28),

                  // Primary Button with Breathing Glow
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: ChatrixTheme.bioluminescence.withOpacity(0.2),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatrixTheme.bioluminescence,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: state.isAuthLoading ? null : () => _handleAuth(0),
                      child: state.isAuthLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isLogin ? "Reconnect" : "Anchor Presence",
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR",
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google Sign-In Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: ChatrixTheme.bioluminescence.withOpacity(0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.02),
                    ),
                    onPressed: state.isAuthLoading ? null : () => _handleAuth(1),
                    icon: const Icon(
                      Icons.blur_circular,
                      color: ChatrixTheme.bioluminescence,
                      size: 24,
                    ),
                    label: Text(
                      "Authenticate with Google",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Guest/Wanderer Access Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: ChatrixTheme.accentGold.withOpacity(0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.02),
                    ),
                    onPressed: state.isAuthLoading ? null : () => _handleAuth(2),
                    icon: const Icon(
                      Icons.explore_outlined,
                      color: ChatrixTheme.accentGold,
                      size: 24,
                    ),
                    label: Text(
                      "Explore as Guest",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mode Toggle Button
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(onboardingControllerProvider.notifier).toggleAuthMode();
                    },
                    child: Text(
                      isLogin
                          ? "First time here? Anchor a new presence"
                          : "Already connected? Resume connection",
                      style: GoogleFonts.inter(
                        color: ChatrixTheme.bioluminescence.withOpacity(0.8),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
            color: ChatrixTheme.bioluminescence.withOpacity(0.5),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
