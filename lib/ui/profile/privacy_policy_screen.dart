import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatrixTheme.background,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "PRIVACY POLICY",
                  style: GoogleFonts.playfairDisplay(
                    color: ChatrixTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      Text(
                        "Your Privacy is Sovereign",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        "We believe AI should feel personal, and personal means private. Below is a simple, transparent summary of how your data is handled on Chatrix.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: ChatrixTheme.textSecondary,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      
                      const SizedBox(height: 32),
                      
                      _buildPolicyCard(
                        icon: Icons.storage_rounded,
                        title: "What Data is Stored",
                        description: "• Account Info: Basic profile details (email, username, date of birth) to identify your presence.\n• Companion Data: Names, descriptions, and configurations of companions you design.\n• Emotional Memory: Optional details (identity layer, emotional profile, lifestyle inputs) that you save to personalize AI responses.",
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                      
                      _buildPolicyCard(
                        icon: Icons.fingerprint_rounded,
                        title: "Authentication",
                        description: "We use secure industry-standard authentication methods (Firebase Auth). Your password credentials are handled by secure validation layers and are never stored directly or seen by us.",
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),
                      
                      _buildPolicyCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: "Chat History & Logs",
                        description: "Your conversation history with AI companions is stored securely to allow seamless continuous conversations. You can choose to encrypt or clear these logs at your discretion.",
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05),
                      
                      _buildPolicyCard(
                        icon: Icons.delete_sweep_rounded,
                        title: "User-Controlled Data Removal",
                        description: "We believe in the 'Right to be Forgotten'. Under your Profile, you can:\n• Wipe Memories: Erase all chat histories and companion memory journals instantly.\n• Delete Account: Permanently delete your entire account, customized companions, and all logs from our database.",
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05),
                      
                      _buildPolicyCard(
                        icon: Icons.security_rounded,
                        title: "Security Protocols",
                        description: "Data in transit and at rest is protected with modern cryptographic mechanisms. We regularly update our backend pipelines to defend against unauthorized exposure and maintain a secure digital environment.",
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.05),
                      
                      const SizedBox(height: 40),
                      
                      Center(
                        child: Text(
                          "Last Updated: June 2026",
                          style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ChatrixTheme.amethyst.withOpacity(0.15),
            ),
            child: Icon(icon, color: ChatrixTheme.champagneGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: ChatrixTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
