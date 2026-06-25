import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../auth/auth_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  // 6 controllers for the OTP boxes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-send on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        t.cancel();
      }
    });
  }

  String get _otpValue =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _sendCode() async {
    if (_isSending || _resendCooldown > 0) return;
    setState(() {
      _isSending = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No active session found.');
      }
      await ref
          .read(authServiceProvider)
          .generateAndSendOtp(user.email!);

      setState(() {
        _codeSent = true;
        _successMessage =
            'A 6-digit code has been sent to your email. It expires in 10 minutes.';
      });
      _startCooldown();
      // Focus first box
      Future.delayed(300.ms, () {
        if (mounted) _focusNodes[0].requestFocus();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpValue;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits.');
      return;
    }
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No active session found.');
      }
      final valid = await ref
          .read(authServiceProvider)
          .verifyOtp(user.email!, code);

      if (valid) {
        setState(() {
          _successMessage = 'Identity verified! Entering Chatrix...';
        });
        await Future.delayed(800.ms);
        if (mounted) ref.invalidate(authStateProvider);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        // Clear the boxes on wrong code so user can retry
        for (final c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF0F172A), Colors.black],
              radius: 1.2,
              center: Alignment.center,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 36),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color:
                            ChatrixTheme.bioluminescence.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ChatrixTheme.bioluminescence.withOpacity(0.06),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.6),
                            border: Border.all(
                              color: ChatrixTheme.bioluminescence
                                  .withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_outlined,
                            color: ChatrixTheme.bioluminescence,
                            size: 48,
                          ),
                        )
                            .animate(
                                onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1.05, 1.05),
                              duration: 1500.ms,
                              curve: Curves.easeInOut,
                            ),

                        const SizedBox(height: 28),

                        Text(
                          'Verify Your Identity',
                          style: GoogleFonts.cinzel(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 500.ms),

                        const SizedBox(height: 12),

                        Text(
                          'Enter the 6-digit code sent to:',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 8),

                        // Email chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            email,
                            style: GoogleFonts.inter(
                              color: ChatrixTheme.bioluminescence,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms).scale(
                              duration: 400.ms,
                              curve: Curves.easeOutBack,
                            ),

                        const SizedBox(height: 32),

                        // Status messages
                        if (_successMessage != null)
                          _buildStatusBanner(
                            _successMessage!,
                            isError: false,
                          ),
                        if (_errorMessage != null)
                          _buildStatusBanner(
                            _errorMessage!,
                            isError: true,
                          ),

                        // OTP boxes (only show once code is sent or sending)
                        if (_codeSent || _isSending) ...[
                          _buildOtpRow(),
                          const SizedBox(height: 28),

                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    ChatrixTheme.bioluminescence,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _isVerifying ? null : _verifyCode,
                              child: _isVerifying
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      'Verify Code',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 350.ms),

                          const SizedBox(height: 16),
                        ],

                        // Send / Resend button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: (_isSending || _resendCooldown > 0)
                                    ? Colors.white.withOpacity(0.08)
                                    : ChatrixTheme.bioluminescence
                                        .withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: (_isSending || _resendCooldown > 0)
                                ? null
                                : _sendCode,
                            child: _isSending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white54,
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _resendCooldown > 0
                                        ? 'Resend Code in ${_resendCooldown}s'
                                        : _codeSent
                                            ? 'Resend Code'
                                            : 'Send Verification Code',
                                    style: GoogleFonts.inter(
                                      color: (_isSending ||
                                              _resendCooldown > 0)
                                          ? Colors.white30
                                          : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 450.ms),

                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: _signOut,
                          child: Text(
                            'Sign Out / Use Different Account',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ).animate().fadeIn(delay: 550.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 44,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focusNodes[i].hasFocus
                    ? ChatrixTheme.bioluminescence.withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _otpControllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: GoogleFonts.inter(
                color: ChatrixTheme.bioluminescence,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (val) {
                setState(() {}); // refresh border colors
                if (val.isNotEmpty && i < 5) {
                  _focusNodes[i + 1].requestFocus();
                } else if (val.isEmpty && i > 0) {
                  _focusNodes[i - 1].requestFocus();
                }
                // Auto-submit when all 6 filled
                if (_otpValue.length == 6) {
                  _verifyCode();
                }
              },
            ),
          ),
        );
      }),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08);
  }

  Widget _buildStatusBanner(String message, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? ChatrixTheme.neonPink.withOpacity(0.08)
            : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? ChatrixTheme.neonPink.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? ChatrixTheme.neonPink : Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
