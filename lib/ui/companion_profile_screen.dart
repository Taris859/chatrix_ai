import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/companion.dart';
import '../memory/memory_service.dart';
import '../models/relationship_chapter.dart';
import '../auth/auth_service.dart';
import 'chat_screen.dart';
import 'memory_journal_screen.dart';
import 'widgets/relationship_timeline_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CompanionProfileScreen extends StatefulWidget {
  final Companion companion;

  const CompanionProfileScreen({super.key, required this.companion});

  @override
  State<CompanionProfileScreen> createState() => _CompanionProfileScreenState();
}

class _CompanionProfileScreenState extends State<CompanionProfileScreen> {
  bool _isLoading = true;
  
  int _trustLevel = 10;
  int _messagesExchanged = 0;
  List<Map<String, dynamic>> _recentReflections = [];
  
  @override
  void initState() {
    super.initState();
    _loadRelationshipData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadRelationshipData() async {
    final userId = AuthService().currentUserId ?? "guest_123";
    
    // 1. Fetch memory summary and diary entries
    final data = await MemoryService().fetchMemory(userId, widget.companion.name);
    
    // 2. Fetch cached messages to calculate stats
    final messages = await MemoryService().getCachedMessages(userId, widget.companion.name);
    _messagesExchanged = messages.length;

    // 3. Count shared secrets & inside jokes to match stats calculation in memory journal
    int secretsCount = 0;
    int jokesCount = 0;
    int daysReturned = 1;
    int unlockedGiftsCount = 0;

    final prefs = await SharedPreferences.getInstance();
    final activeDaysKey = 'active_days_${userId}_${widget.companion.name}';
    final List<String> activeDays = prefs.getStringList(activeDaysKey) ?? [];
    daysReturned = activeDays.isNotEmpty ? activeDays.length : 1;

    final unlockedKey = 'unlocked_gifts_${userId}_${widget.companion.name}';
    final List<String> giftList = prefs.getStringList(unlockedKey) ?? [];
    unlockedGiftsCount = giftList.length;

    if (data != null) {
      final summary = data['summary'] as Map<String, dynamic>? ?? {};
      final userProfile = summary['user_profile'] as Map<String, dynamic>? ?? {};

      // Shared Secrets Count
      final secretsObj = userProfile['shared_secrets'];
      if (secretsObj is List) {
        secretsCount = secretsObj.length;
      } else if (secretsObj is Map) {
        secretsCount = secretsObj.keys.where((k) => !k.startsWith('_')).length;
      } else if (secretsObj != null) {
        secretsCount = 1;
      }

      // Inside Jokes Count
      final jokesObj = userProfile['inside_jokes'];
      if (jokesObj is List) {
        jokesCount = jokesObj.length;
      } else if (jokesObj is Map) {
        jokesCount = jokesObj.keys.where((k) => !k.startsWith('_')).length;
      } else if (jokesObj != null) {
        jokesCount = 1;
      }

      // Reflections list
      if (data['diary_entries'] != null) {
        final List<Map<String, dynamic>> allEntries = List<Map<String, dynamic>>.from(data['diary_entries']);
        // Take latest 2 reflections
        _recentReflections = allEntries.reversed.take(2).toList();
      }
    }

    _trustLevel = (10 + (_messagesExchanged ~/ 2) + (secretsCount * 10) + (unlockedGiftsCount * 8)).clamp(0, 100);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final themeColor = widget.companion.themeColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2))
        : Stack(
            children: [
              // Cinematic Volumetric blur backing
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        themeColor.withValues(alpha: 0.06),
                        const Color(0xFF070709),
                      ],
                    ),
                  ),
                ),
              ),

              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Netflix-Style Hero Poster Header
                  SliverToBoxAdapter(
                    child: _buildHeroPoster(context),
                  ),

                  // 2. Profile Details & Lore Blocks
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildIdentityRow(),
                        const SizedBox(height: 20),
                        _buildRelationshipCard(),
                        const SizedBox(height: 24),
                        RelationshipTimelineWidget(
                          trustLevel: _trustLevel,
                          companionThemeColor: widget.companion.themeColor,
                        ),
                        const SizedBox(height: 24),
                        _buildQuoteSection(),
                        const SizedBox(height: 24),
                        _buildLoreSection(),
                        const SizedBox(height: 24),
                        _buildMetadataGrid(),
                        const SizedBox(height: 28),
                        _buildMemoryPreviewSection(),
                      ]),
                    ),
                  ),
                ],
              ),

              // 3. Floating Bottom Call-To-Action (START CHAT)
              _buildBottomCTA(context),
            ],
          ),
    );
  }

  Widget _buildHeroPoster(BuildContext context) {
    final hasImg = widget.companion.imagePath != null;
    final themeColor = widget.companion.themeColor;

    return Stack(
      children: [
        // Character Image aspect ratio
        AspectRatio(
          aspectRatio: 0.95,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: widget.companion.customImageUrl != null && widget.companion.customImageUrl!.isNotEmpty
                ? (widget.companion.customImageUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(widget.companion.customImageUrl!.split(',').last),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        widget.companion.customImageUrl!,
                        fit: BoxFit.cover,
                      ))
                : (hasImg
                    ? Image.asset(
                        widget.companion.imagePath!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeColor.withOpacity(0.35),
                              Colors.black,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.companion.initials,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white.withValues(alpha: 0.04),
                              fontSize: 160,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      )),
          ),
        ),

        // Vertical Fade to black at bottom of image
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  const Color(0xFF070709).withValues(alpha: 0.8),
                  const Color(0xFF070709),
                ],
                stops: const [0.0, 0.4, 0.85, 1.0],
              ),
            ),
          ),
        ),

        // Float Navigation Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),

        // Float Share Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                  onPressed: () => _showShareDialog(context),
                ),
              ),
            ),
          ),
        ),


      ],
    );
  }

  Widget _buildIdentityRow() {
    final themeColor = widget.companion.themeColor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.companion.name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (widget.companion.isPremium)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ChatrixTheme.champagneGold.withValues(alpha: 0.15),
                  border: Border.all(color: ChatrixTheme.champagneGold.withValues(alpha: 0.4), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "PREMIUM",
                  style: GoogleFonts.inter(
                    color: ChatrixTheme.champagneGold,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.companion.archetype.toUpperCase(),
                style: GoogleFonts.inter(
                  color: themeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "✦ ${widget.companion.gender.name.toUpperCase()}",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelationshipCard() {
    final themeColor = widget.companion.themeColor;
    final activeChapter = RelationshipChapter.getChapterForTrust(_trustLevel);
    final nextChapter = RelationshipChapter.getNextChapter(_trustLevel);
    
    double progressVal = 1.0;
    String progressText = "Ultimate Soul Bond Achieved";
    if (nextChapter != null) {
      final range = nextChapter.minTrust - activeChapter.minTrust;
      final currentInSegment = _trustLevel - activeChapter.minTrust;
      progressVal = (currentInSegment / range).clamp(0.0, 1.0);
      progressText = "Next Chapter: ${nextChapter.name}";
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryJournalScreen(companion: widget.companion),
          ),
        ).then((_) => _loadRelationshipData());
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1012),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeColor.withValues(alpha: 0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.04),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    activeChapter.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RELATIONSHIP JOURNEY",
                        style: GoogleFonts.inter(
                          color: Colors.white30,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeChapter.name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Text(
                    "Trust $_trustLevel%",
                    style: GoogleFonts.inter(
                      color: themeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              "Chapter Perks: ${activeChapter.unlocksDescription}",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progressVal,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          themeColor.withValues(alpha: 0.6),
                          themeColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    progressText,
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Soul Archive",
                      style: GoogleFonts.inter(
                        color: themeColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: themeColor,
                      size: 11,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildQuoteSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: widget.companion.themeColor.withValues(alpha: 0.5), size: 24),
              const SizedBox(width: 6),
              Text(
                "SIGNATURE CUE",
                style: GoogleFonts.inter(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.companion.greeting,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16.5,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoreSection() {
    // Trim descriptive text details if necessary
    String personalityClean = widget.companion.personality;
    personalityClean = personalityClean
        .replaceAll('You are ${widget.companion.name}.', '')
        .replaceAll('You speak in', 'Speaks in')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "OVERVIEW & PERSONALITY",
          style: GoogleFonts.inter(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          personalityClean.isNotEmpty ? personalityClean : "A mysterious presence waiting to be discovered.",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14.5,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataGrid() {
    final List<Map<String, String>> details = [];
    
    void addDetail(String label, String? value, String emoji) {
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'none') {
        details.add({'label': label, 'value': value, 'emoji': emoji});
      }
    }

    addDetail("Favorite Drink", widget.companion.favoriteDrink, "🍵");
    addDetail("Sleeping Hours", widget.companion.sleepingHours, "💤");
    addDetail("Love Language", widget.companion.loveLanguage, "❤️");
    addDetail("Comfort Item", widget.companion.comfortItem, "🧸");
    addDetail("Favorite Food", widget.companion.favoriteFood, "🥐");
    addDetail("Favorite Books", widget.companion.favoriteBooks, "📚");
    addDetail("Pet Peeves", widget.companion.petPeeves, "🚫");
    addDetail("Birthday", widget.companion.birthday, "🎂");

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CORE METADATA",
          style: GoogleFonts.inter(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: details.length,
          itemBuilder: (context, index) {
            final item = details[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  Text(
                    item['emoji']!,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['label']!.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['value']!,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemoryPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "MEMORY LOGS",
          style: GoogleFonts.inter(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentReflections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              children: [
                Icon(Icons.psychology_outlined, color: Colors.white12, size: 36),
                const SizedBox(height: 12),
                Text(
                  "Every relationship begins with one conversation.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.caveat(
                    color: Colors.white54,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentReflections.length,
            itemBuilder: (context, index) {
              final ref = _recentReflections[index];
              final String text = ref['entry'] ?? ref['content'] ?? '';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.015),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "AI DIARY ENTRY",
                          style: TextStyle(
                            color: widget.companion.themeColor.withValues(alpha: 0.7),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Icon(
                          Icons.auto_stories_outlined, 
                          color: widget.companion.themeColor.withValues(alpha: 0.3), 
                          size: 14
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    final themeColor = widget.companion.themeColor;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF070709).withValues(alpha: 0.85),
              const Color(0xFF070709),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(companion: widget.companion),
                ),
              );
            },
            child: Text(
              "START CONVERSATION",
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scale(end: const Offset(1.02, 1.02), duration: 1200.ms),
      ),
    );
  }
  void _showShareDialog(BuildContext context) {
    final String deepLink = "https://chatrix.space/?companion=${widget.companion.id}";
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: ChatrixTheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: widget.companion.themeColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Share ${widget.companion.name}",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Scan QR code or copy the link below to invite others.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: deepLink,
                    version: QrVersions.auto,
                    size: 160.0,
                    gapless: false,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.companion.themeColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: deepLink));
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Deep link copied to clipboard!"),
                        backgroundColor: ChatrixTheme.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text("Copy Link", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
