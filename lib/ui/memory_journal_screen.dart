import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/companion.dart';
import '../auth/auth_service.dart';
import '../memory/memory_service.dart';

class MemoryJournalScreen extends StatefulWidget {
  final Companion companion;

  const MemoryJournalScreen({Key? key, required this.companion}) : super(key: key);

  @override
  State<MemoryJournalScreen> createState() => _MemoryJournalScreenState();
}

class _MemoryJournalScreenState extends State<MemoryJournalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _memoryDiary = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final userId = AuthService().currentUserId ?? "guest_123";
    final data = await MemoryService().fetchMemory(userId, widget.companion.name);
    if (data != null && data['diary_entries'] != null) {
      if (mounted) {
        setState(() {
          _memoryDiary = List<Map<String, dynamic>>.from(data['diary_entries'].reversed);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Volumetric blur background tailored to the companion theme
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.companion.themeColor.withOpacity(0.08),
                  const Color(0xFF07070C),
                  Colors.black,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildTabControls(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildJournalTab(),
                          _buildArtifactsTab(),
                        ],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SOUL ARCHIVE",
                style: TextStyle(
                  color: widget.companion.themeColor,
                  fontSize: 12,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.companion.name}'s Journal",
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: widget.companion.themeColor.withOpacity(0.12),
          border: Border.all(color: widget.companion.themeColor.withOpacity(0.4)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13),
        tabs: const [
          Tab(text: "Diary"),
          Tab(text: "Milestones"),
        ],
      ),
    );
  }

  Widget _buildJournalTab() {
    if (_memoryDiary.isEmpty) {
      return Center(
        child: Text(
          "Talk to ${widget.companion.name} more to unlock inner thoughts.",
          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _memoryDiary.length,
      itemBuilder: (context, index) {
        final entry = _memoryDiary[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.companion.themeColor.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "RECORDED MEMORY",
                          style: TextStyle(
                            color: widget.companion.themeColor.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Icon(Icons.auto_stories, color: widget.companion.themeColor.withOpacity(0.4), size: 16),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry["thought"] ?? "— PRIVATE REFLECTION —",
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry["content"] ?? "",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.87),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate(delay: (index * 150).ms).fadeIn(duration: 500.ms).slideY(begin: 0.1);
      },
    );
  }

  Widget _buildArtifactsTab() {
    final List<Map<String, dynamic>> milestones = _getMilestones();

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: milestones.length,
      itemBuilder: (context, index) {
        final milestone = milestones[index];
        final isUnlocked = milestone["unlocked"] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isUnlocked ? Colors.white.withOpacity(0.02) : Colors.black45,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked 
                  ? widget.companion.themeColor.withOpacity(0.2) 
                  : Colors.white.withOpacity(0.03),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked 
                      ? widget.companion.themeColor.withOpacity(0.1) 
                      : Colors.white.withOpacity(0.02),
                ),
                child: Icon(
                  isUnlocked ? milestone["icon"] : Icons.lock_outline,
                  color: isUnlocked ? widget.companion.themeColor : Colors.white24,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone["title"],
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white30,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUnlocked ? milestone["desc"] : "Complete deeper sessions to unlock this memory",
                      style: TextStyle(
                        color: isUnlocked ? Colors.white54 : Colors.white24,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: (index * 120).ms).fadeIn(duration: 400.ms).slideX(begin: 0.05);
      },
    );
  }

  List<Map<String, dynamic>> _getMilestones() {
    return [
      {
        "title": "First Connection Established",
        "desc": "Initiated the very first cinematic conversation in the late-night ambient space.",
        "icon": Icons.lens_blur_outlined,
        "unlocked": true,
      },
      {
        "title": "Shared Vulnerability",
        "desc": "Exchanged intimate truths and lowered defenses during a midnight rain session.",
        "icon": Icons.favorite_border,
        "unlocked": true,
      },
      {
        "title": "The Oath of Protection",
        "desc": "Committed to guarding each other\'s peace against the storm outside.",
        "icon": Icons.shield_outlined,
        "unlocked": true,
      },
      {
        "title": "Eternal Sanctuary",
        "desc": "Achieved absolute relationship trust and fully customized a custom haven.",
        "icon": Icons.nightlight_round_outlined,
        "unlocked": false,
      },
    ];
  }
}
