import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../models/companion.dart';
import '../../auth/auth_service.dart';
import '../../services/firestore_repository.dart';
import 'ai_creation_studio.dart';

class CreatorDashboardScreen extends ConsumerStatefulWidget {
  const CreatorDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends ConsumerState<CreatorDashboardScreen> {
  bool _isToggling = false;

  Future<void> _togglePublicStatus(Companion companion, bool newStatus) async {
    setState(() {
      _isToggling = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('ai_companions')
          .doc(companion.id)
          .update({'is_public': newStatus});

      ref.invalidate(companionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${companion.name} is now ${newStatus ? "Public" : "Private"}.",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: ChatrixTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: $e"),
            backgroundColor: ChatrixTheme.errorRose,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  Future<void> _deleteCompanion(Companion companion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChatrixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete AI?", style: TextStyle(color: ChatrixTheme.errorRose, fontSize: 22)),
        content: Text("Are you sure you want to permanently delete ${companion.name}?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: ChatrixTheme.errorRose))),
        ],
      )
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('ai_companions').doc(companion.id).delete();
        ref.invalidate(companionsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${companion.name} deleted."),
              backgroundColor: ChatrixTheme.surface,
            )
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: ChatrixTheme.errorRose,
            )
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUserId ?? "guest_123";
    final companionsAsync = ref.watch(companionsProvider);

    return Scaffold(
      backgroundColor: ChatrixTheme.background,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "CREATOR STUDIO",
                      style: GoogleFonts.playfairDisplay(
                        color: ChatrixTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  "Manage your custom AI companions, monitor engagement, and publish them to the public catalog.",
                  style: GoogleFonts.inter(
                    color: ChatrixTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Dashboard List
              Expanded(
                child: companionsAsync.when(
                  data: (companions) {
                    final myCompanions = companions.where((c) {
                      return c.creatorId == currentUserId;
                    }).toList();

                    if (myCompanions.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: myCompanions.length,
                      itemBuilder: (context, index) {
                        final companion = myCompanions[index];
                        return _buildCompanionCard(companion, index);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2),
                  ),
                  error: (err, stack) => Center(
                    child: Text(
                      "Error loading creations: $err",
                      style: GoogleFonts.inter(color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ChatrixTheme.surface,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AICreationStudio()),
        ),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          "New Companion",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildCompanionCard(Companion companion, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    companion.buildAvatar(radius: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companion.name,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            companion.archetype,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: ChatrixTheme.errorRose),
                      onPressed: () => _deleteCompanion(companion),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white38, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Popularity: Active",
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          companion.isPublic ? "Public" : "Private",
                          style: GoogleFonts.inter(
                            color: companion.isPublic ? companion.themeColor : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: companion.isPublic,
                          activeColor: companion.themeColor,
                          onChanged: _isToggling ? null : (val) => _togglePublicStatus(companion, val),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideY(begin: 0.1, duration: 300.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.design_services_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "No creations yet",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap 'New Companion' to bring your own AI to life.",
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
