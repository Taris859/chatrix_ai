import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _copyToClipboard(BuildContext context, String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$label copied to clipboard"),
        backgroundColor: ChatrixTheme.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                  "ABOUT CHATRIX",
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
                      
                      // Brand Identity / Logo placeholder with nice glows
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    ChatrixTheme.amethyst.withOpacity(0.6),
                                    ChatrixTheme.champagneGold.withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: ChatrixTheme.champagneGold.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ChatrixTheme.amethyst.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 36,
                              ),
                            ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 16),
                            Text(
                              "CHATRIX",
                              style: GoogleFonts.cinzel(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4.0,
                              ),
                            ).animate().fadeIn(delay: 200.ms),
                            Text(
                              "Immersive AI Character Chat Platform",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ChatrixTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Mission Section
                      _buildSectionHeader("OUR MISSION"),
                      const SizedBox(height: 12),
                      _buildContentCard(
                        child: Text(
                          "Chatrix is an AI character platform designed for immersive conversations, roleplay experiences, storytelling, and creative companionship.",
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: ChatrixTheme.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),
                      
                      const SizedBox(height: 32),
                      
                      // Why Chatrix?
                      _buildSectionHeader("WHY CHATRIX?"),
                      const SizedBox(height: 12),
                      _buildContentCard(
                        child: Column(
                          children: [
                            _buildFeatureRow(Icons.face_retouching_natural_rounded, "Character-driven AI", "Interact with distinct, lifelike personalities."),
                            _buildFeatureRow(Icons.auto_stories_rounded, "Storytelling experiences", "Build intricate narratives together step-by-step."),
                            _buildFeatureRow(Icons.theater_comedy_rounded, "Creative roleplay", "Explore infinite roleplay scenarios in rich worlds."),
                            _buildFeatureRow(Icons.diversity_3_rounded, "Diverse personalities", "Choose from a wide variety of companion archetypes."),
                            _buildFeatureRow(Icons.brush_rounded, "User-created characters", "Design and manifest your own custom companions."),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05),
                      
                      const SizedBox(height: 32),
                      
                      // Founder Story
                      _buildSectionHeader("THE FOUNDER STORY"),
                      const SizedBox(height: 12),
                      _buildContentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Chatrix was founded by Tanu Bhukal, an independent developer passionate about AI, storytelling, and creating immersive digital experiences.",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: ChatrixTheme.textPrimary,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Chatrix began as an independent passion project built from curiosity, persistence, and a desire to create unique AI experiences. What started as an idea gradually evolved into a live platform through continuous learning, experimentation, and development.",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: ChatrixTheme.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05),
                      
                      const SizedBox(height: 32),
                      
                      // Contact Section
                      _buildSectionHeader("GET IN TOUCH"),
                      const SizedBox(height: 12),
                      _buildContentCard(
                        padding: EdgeInsets.zero,
                        child: _buildContactTile(
                          context: context,
                          icon: Icons.email_outlined,
                          title: "Email Support",
                          value: "chatrix@zohomail.in",
                        ),
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.05),
                      
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: ChatrixTheme.champagneGold,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildContentCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: child,
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ChatrixTheme.amethyst.withOpacity(0.15),
            ),
            child: Icon(icon, color: ChatrixTheme.champagneGold, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: ChatrixTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: ChatrixTheme.silverMist, size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.inter(
          color: ChatrixTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.copy_rounded, color: Colors.white30, size: 18),
      onTap: () => _copyToClipboard(context, title, value),
    );
  }
}
