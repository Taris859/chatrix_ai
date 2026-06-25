import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../memory/memory_service.dart';
import '../auth/auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _lateNightMode = false;
  bool _milestoneNotifications = true;
  bool _ambientSceneNotifications = true;
  bool _isLoading = true;
  bool _isClearingMemory = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
        _lateNightMode = prefs.getBool('lateNightMode') ?? false;
        _milestoneNotifications = prefs.getBool('milestoneNotifications') ?? true;
        _ambientSceneNotifications = prefs.getBool('ambientSceneNotifications') ?? true;
        _isLoading = false;
      });

      // Try syncing from Firestore if authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?.containsKey('notification_settings') == true) {
          final settings = doc.data()?['notification_settings'] as Map<String, dynamic>;
          setState(() {
            _notificationsEnabled = settings['notificationsEnabled'] ?? _notificationsEnabled;
            _lateNightMode = settings['lateNightMode'] ?? _lateNightMode;
            _milestoneNotifications = settings['milestoneNotifications'] ?? _milestoneNotifications;
            _ambientSceneNotifications = settings['ambientSceneNotifications'] ?? _ambientSceneNotifications;
          });
          // Cache locally
          await prefs.setBool('notificationsEnabled', _notificationsEnabled);
          await prefs.setBool('lateNightMode', _lateNightMode);
          await prefs.setBool('milestoneNotifications', _milestoneNotifications);
          await prefs.setBool('ambientSceneNotifications', _ambientSceneNotifications);
        }
      }
    } catch (e) {
      print("Error loading settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    HapticFeedback.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'notification_settings': {
            'notificationsEnabled': _notificationsEnabled,
            'lateNightMode': _lateNightMode,
            'milestoneNotifications': _milestoneNotifications,
            'ambientSceneNotifications': _ambientSceneNotifications,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving setting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        children: [

                          const SizedBox(height: 16),
                          _buildSettingCard(
                            title: "Enable Presence Signals",
                            subtitle: "Allow companions to reach out quietly.",
                            value: _notificationsEnabled,
                            icon: Icons.notifications_active_outlined,
                            onChanged: (val) {
                              setState(() => _notificationsEnabled = val);
                              _saveSetting('notificationsEnabled', val);
                            },
                          ),
                          _buildSettingCard(
                            title: "Late Night Mode Only",
                            subtitle: "Companions will only whisper between 10 PM and 6 AM.",
                            value: _lateNightMode,
                            icon: Icons.nights_stay_outlined,
                            enabled: _notificationsEnabled,
                            onChanged: (val) {
                              setState(() => _lateNightMode = val);
                              _saveSetting('lateNightMode', val);
                            },
                          ),

                          const SizedBox(height: 24),
                          _buildSectionTitle("Atmospheric Events"),
                          const SizedBox(height: 16),
                          _buildSettingCard(
                            title: "Relationship Milestones",
                            subtitle: "Get notified when a companion forms a deep memory.",
                            value: _milestoneNotifications,
                            icon: Icons.favorite_border_outlined,
                            enabled: _notificationsEnabled,
                            onChanged: (val) {
                              setState(() => _milestoneNotifications = val);
                              _saveSetting('milestoneNotifications', val);
                            },
                          ),
                          _buildSettingCard(
                            title: "Ambient Scene Changes",
                            subtitle: "Receive notifications during weather adjustments.",
                            value: _ambientSceneNotifications,
                            icon: Icons.wb_cloudy_outlined,
                            enabled: _notificationsEnabled,
                            onChanged: (val) {
                              setState(() => _ambientSceneNotifications = val);
                              _saveSetting('ambientSceneNotifications', val);
                            },
                          ),
                          const SizedBox(height: 36),
                          _buildSectionTitle("Memory & Privacy"),
                          const SizedBox(height: 16),
                          _buildMemoryClearCard(),
                          const SizedBox(height: 36),
                          _buildFooter(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "COMMUNICATION SETTINGS",
              style: GoogleFonts.cinzel(
                color: ChatrixTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: ChatrixTheme.bioluminescence.withOpacity(0.7),
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.5,
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final opacity = enabled ? 1.0 : 0.4;
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ChatrixTheme.surface.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Icon(icon, color: ChatrixTheme.bioluminescence.withOpacity(0.8), size: 22),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: value,
                    activeColor: ChatrixTheme.bioluminescence,
                    activeTrackColor: ChatrixTheme.bioluminescence.withOpacity(0.2),
                    onChanged: enabled ? onChanged : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }

  Widget _buildMemoryClearCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ChatrixTheme.errorRose.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ChatrixTheme.errorRose.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChatrixTheme.errorRose.withOpacity(0.08),
                        border: Border.all(color: ChatrixTheme.errorRose.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.memory_outlined, color: ChatrixTheme.errorRose, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Clear All AI Memories",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Permanently erase everything your companions remember about you.",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "⚠️  This erases all emotional profiles, diary entries, and relationship memories across every companion. Your chat history remains viewable until you delete it separately. This action is permanent and irreversible.",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChatrixTheme.errorRose.withOpacity(0.12),
                      foregroundColor: ChatrixTheme.errorRose,
                      side: const BorderSide(color: ChatrixTheme.errorRose, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isClearingMemory ? null : _confirmClearAllMemory,
                    child: _isClearingMemory
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ChatrixTheme.errorRose),
                          )
                        : Text(
                            "Clear All Memories",
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }

  Future<void> _confirmClearAllMemory() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AlertDialog(
          backgroundColor: ChatrixTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ChatrixTheme.errorRose, size: 24),
              const SizedBox(width: 10),
              Text(
                "Erase All Memories?",
                style: GoogleFonts.inter(
                  color: ChatrixTheme.errorRose,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Every companion will forget you entirely.",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                "All emotional profiles, personal details, relationship milestones, and diary entries will be permanently deleted. Your companions will greet you as strangers.",
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "This cannot be undone.",
                style: GoogleFonts.inter(
                  color: ChatrixTheme.errorRose,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Keep Memories", style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Yes, Erase Everything", style: GoogleFonts.inter(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isClearingMemory = true);
      try {
        final userId = AuthService().currentUserId;
        if (userId != null) {
          await MemoryService().clearAllMemory(userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "All memories erased. Your companions will start fresh.",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                backgroundColor: ChatrixTheme.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to clear memories. Try again.", style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: ChatrixTheme.errorRose,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isClearingMemory = false);
      }
    }
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 20),
        Text(
          "Chatrix Premium unlocks weather synchronization, scene updates, and custom late-night emotional memory logs.",
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "OneSignal Integration Active",
          style: GoogleFonts.inter(
            color: ChatrixTheme.bioluminescence.withOpacity(0.4),
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }
}
