import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../models/companion.dart';
import '../auth/auth_service.dart';
import '../memory/memory_service.dart';
import '../models/relationship_chapter.dart';

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
  bool _isClearingMemory = false;

  // Progression metrics calculated from actual behavior parameters
  int _messagesExchanged = 0;
  int _daysTogether = 1;
  int _sharedSecretsCount = 0;
  int _insideJokesCount = 0;
  int _memoriesCount = 0;
  int _trustLevel = 10;
  int _friendshipLevel = 15;
  int _daysReturned = 1;
  List<Map<String, dynamic>> _journeyEvents = [];
  List<Map<String, dynamic>> _unlockedGifts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final userId = AuthService().currentUserId ?? "guest_123";
    
    // 1. Fetch memory summary and diary
    final data = await MemoryService().fetchMemory(userId, widget.companion.name);
    
    // 2. Fetch cached messages to count total messages exchanged
    final messages = await MemoryService().getCachedMessages(userId, widget.companion.name);
    _messagesExchanged = messages.length;

    // 3. Fetch return days from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final activeDaysKey = 'active_days_${userId}_${widget.companion.name}';
    final List<String> activeDays = prefs.getStringList(activeDaysKey) ?? [];
    _daysReturned = activeDays.isNotEmpty ? activeDays.length : 1;

    // 4. Fetch unlocked gifts from SharedPreferences
    final unlockedKey = 'unlocked_gifts_${userId}_${widget.companion.name}';
    final List<String> giftList = prefs.getStringList(unlockedKey) ?? [];
    _unlockedGifts = giftList.map((g) => Map<String, dynamic>.from(jsonDecode(g))).toList();

    if (data != null) {
      if (mounted) {
        setState(() {
          // Reflections (diary entries)
          if (data['diary_entries'] != null) {
            _memoryDiary = List<Map<String, dynamic>>.from(data['diary_entries'].reversed);
          }

          // Summary details
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final userProfile = summary['user_profile'] as Map<String, dynamic>? ?? {};

          // Count shared secrets
          final secretsObj = userProfile['shared_secrets'];
          if (secretsObj is List) {
            _sharedSecretsCount = secretsObj.length;
          } else if (secretsObj is Map) {
            _sharedSecretsCount = secretsObj.keys.where((k) => !k.startsWith('_')).length;
          } else if (secretsObj != null) {
            _sharedSecretsCount = 1;
          }

          // Count inside jokes
          final jokesObj = userProfile['inside_jokes'];
          if (jokesObj is List) {
            _insideJokesCount = jokesObj.length;
          } else if (jokesObj is Map) {
            _insideJokesCount = jokesObj.keys.where((k) => !k.startsWith('_')).length;
          } else if (jokesObj != null) {
            _insideJokesCount = 1;
          }

          // Days together
          final firstConnectedStr = summary['first_connected_at'] as String?;
          if (firstConnectedStr != null) {
            final firstConnected = DateTime.tryParse(firstConnectedStr);
            if (firstConnected != null) {
              _daysTogether = DateTime.now().difference(firstConnected).inDays + 1;
            }
          }

          // Memories count
          int profileKeysCount = 0;
          userProfile.forEach((key, val) {
            if (key.startsWith('_')) return;
            if (val is Map) {
              profileKeysCount += val.keys.where((k) => !k.startsWith('_')).length;
            } else {
              profileKeysCount++;
            }
          });
          _memoriesCount = _memoryDiary.length + profileKeysCount;

          // Milestone events
          if (summary['journey_events'] != null) {
            _journeyEvents = List<Map<String, dynamic>>.from(summary['journey_events']);
          } else {
            // Default first milestone
            _journeyEvents = [
              {
                'date': "${DateTime.now().day} Jun",
                'desc': 'We established our first connection.',
                'icon': '🌱',
              }
            ];
          }

          // Calculate progression metrics dynamically
          _trustLevel = (10 + (_messagesExchanged ~/ 2) + (_sharedSecretsCount * 10) + (_unlockedGifts.length * 8)).clamp(0, 100);
          _friendshipLevel = (15 + _messagesExchanged + (_insideJokesCount * 12) + (_daysReturned * 5)).clamp(0, 100);
          
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
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))
                    : NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: _buildRelationshipStatsCard()
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.05),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _SliverAppBarDelegate(
                                minHeight: 64.0,
                                maxHeight: 64.0,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.5),
                                      alignment: Alignment.center,
                                      child: _buildTabControls(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildJourneyTimelineTab(),
                            _buildJournalTab(),
                            _buildCollectionTab(),
                          ],
                        ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _isClearingMemory
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ChatrixTheme.errorRose),
                )
              : IconButton(
                  tooltip: "Clear ${widget.companion.name}'s Memory",
                  icon: const Icon(Icons.delete_forever_outlined, color: Colors.white38, size: 22),
                  onPressed: _confirmClearThisMemory,
                ),
        ],
      ),
    );
  }

  Widget _buildRelationshipStatsCard() {
    final theme = widget.companion.themeColor;
    final activeChapter = RelationshipChapter.getChapterForTrust(_trustLevel);
    final nextChapter = RelationshipChapter.getNextChapter(_trustLevel);
    
    double progressVal = 1.0;
    String progressText = "Ultimate Soul Bond Achieved";
    if (nextChapter != null) {
      final range = nextChapter.minTrust - activeChapter.minTrust;
      final currentInSegment = _trustLevel - activeChapter.minTrust;
      progressVal = (currentInSegment / range).clamp(0.0, 1.0);
      progressText = "Next Chapter: ${nextChapter.name} in ${nextChapter.minTrust - _trustLevel} Trust points";
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.35), // Gold
            const Color(0xFF9D50BB).withOpacity(0.35), // Amethyst
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(1.5), // Gradient border thickness
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF121318).withOpacity(0.8), // Premium glassmorphic background
              borderRadius: BorderRadius.circular(26.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Chapter Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9D50BB).withOpacity(0.15), // Amethyst tint
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3), // Gold border
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9D50BB).withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      ),
                      child: Text(
                        activeChapter.icon,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CHAPTER ${activeChapter.number}",
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFD700), // Gold text
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeChapter.name,
                            style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D50BB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
                      ),
                      child: Text(
                        "Trust $_trustLevel%",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 18),
                
                // Progress bar & next chapter info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressText,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          nextChapter == null ? "100%" : "${(progressVal * 100).toInt()}%",
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progressVal,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF9D50BB), // Amethyst
                                  Color(0xFFFFD700), // Gold
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9D50BB).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "🤍 Friendship level: $_friendshipLevel%",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Messages: $_messagesExchanged",
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Active unlocks: ${activeChapter.unlocksDescription}",
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 14),
                
                // Original metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTextStat("Memories", "$_memoriesCount", Icons.psychology_outlined),
                    _buildTextStat("Days Together", "$_daysTogether", Icons.calendar_today_outlined),
                    _buildTextStat("Shared Secrets", "$_sharedSecretsCount", Icons.lock_open_outlined),
                    _buildTextStat("Inside Jokes", "$_insideJokesCount", Icons.face_outlined),
                  ],
                ),
                
                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 14),
                
                // Dynamic dream progress
                Text(
                  "COMPANION'S DREAM",
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.companion.personalGoals ?? "To build a lasting connection with you.",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "$_trustLevel%",
                      style: GoogleFonts.inter(
                        color: theme,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _trustLevel / 100.0,
                    backgroundColor: Colors.white.withOpacity(0.04),
                    valueColor: AlwaysStoppedAnimation<Color>(theme),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white30, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 9.5,
          ),
        ),
      ],
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
          Tab(text: "Journey"),
          Tab(text: "Reflections"),
          Tab(text: "Collection"),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupEventsByMonthYear() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final event in _journeyEvents) {
      final key = _getMonthYear(event);
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(event);
    }
    return groups;
  }

  String _getMonthYear(Map<String, dynamic> event) {
    if (event['month_year'] != null) {
      return event['month_year'].toString();
    }
    // Try parsing date like "25 Jun" or "25 June 2026"
    final dateStr = event['date']?.toString() ?? "";
    if (dateStr.isNotEmpty) {
      final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(dateStr);
      String year = yearMatch != null ? yearMatch.group(1)! : DateTime.now().year.toString();
      
      final monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
      final monthFullNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      String month = "June";
      for (int i = 0; i < monthNames.length; i++) {
        if (dateStr.toLowerCase().contains(monthNames[i])) {
          month = monthFullNames[i];
          break;
        }
      }
      return "$month $year";
    }
    return "June ${DateTime.now().year}";
  }

  String _getDayStamp(Map<String, dynamic> event) {
    int day = DateTime.now().day;
    if (event['day'] != null) {
      day = int.tryParse(event['day'].toString()) ?? day;
    } else {
      final dateStr = event['date']?.toString() ?? "";
      final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(dateStr);
      if (dayMatch != null) {
        day = int.tryParse(dayMatch.group(1)!) ?? day;
      }
    }

    String monthName = "June";
    if (event['month_year'] != null) {
      final parts = event['month_year'].toString().split(' ');
      if (parts.isNotEmpty) {
        monthName = parts[0];
      }
    } else {
      final dateStr = event['date']?.toString() ?? "";
      if (dateStr.isNotEmpty) {
        final monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final monthFullNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        for (int i = 0; i < monthNames.length; i++) {
          if (dateStr.toLowerCase().contains(monthNames[i])) {
            monthName = monthFullNames[i];
            break;
          }
        }
      }
    }
    return "$monthName $day";
  }

  Widget _buildStitchingLine() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: widget.companion.themeColor.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyTimelineTab() {
    if (_journeyEvents.isEmpty) {
      return Center(
        child: Text(
          "Exchange messages with ${widget.companion.name} to record milestones.",
          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    final grouped = _groupEventsByMonthYear();
    final keys = grouped.keys.toList();
    List<Widget> children = [];
    int polaroidIndex = 0;

    for (final monthYear in keys) {
      final events = grouped[monthYear]!;
      
      // Add Month/Year Header with Calendar Icon
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                "📅 ${monthYear.toUpperCase()}",
                style: GoogleFonts.cinzel(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                  color: widget.companion.themeColor.withOpacity(0.2),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
      );

      // Add a stitching line from header to first card
      if (events.isNotEmpty) {
        children.add(_buildStitchingLine());
      }

      // Add Polaroid Cards for this month
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final String desc = event['desc'] ?? "";
        final String icon = event['icon'] ?? "🌱";
        final String dayStamp = _getDayStamp(event);
        final double angle = ((polaroidIndex % 3) - 1) * 0.035; // alternates between -2, 0, +2 degrees
        polaroidIndex++;

        children.add(
          Center(
            child: Transform.rotate(
              angle: angle,
              child: Container(
                margin: const EdgeInsets.only(bottom: 28),
                width: MediaQuery.of(context).size.width * 0.78,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF9), // Vintage white
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.06),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(4, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The photo frame (1.0 Aspect Ratio for perfect square photo)
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.2),
                            width: 1.0,
                          ),
                          gradient: RadialGradient(
                            colors: [
                              widget.companion.themeColor.withOpacity(0.18),
                              const Color(0xFF0F1012),
                            ],
                            radius: 0.85,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 48),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                           .scale(end: const Offset(1.08, 1.08), duration: 2.seconds),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Caption in ink color
                    Text(
                      desc,
                      style: GoogleFonts.caveat(
                        color: const Color(0xFF1E1E22), // Ink dark color
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Date stamp in handwriting style
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        dayStamp,
                        style: GoogleFonts.caveat(
                          color: Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Connect subsequent cards in the monthly sequence
        if (i < events.length - 1) {
          children.add(_buildStitchingLine());
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      children: children,
    );
  }

  Widget _buildJournalTab() {
    if (_memoryDiary.isEmpty) {
      return Center(
        child: Text(
          "Talk to ${widget.companion.name} more to unlock reflections.",
          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _memoryDiary.length,
      itemBuilder: (context, index) {
        final entry = _memoryDiary[index];
        final entryText = entry["entry"] ?? entry["content"] ?? "";
        final entryThought = entry["thought"] ?? "— PRIVATE REFLECTION —";
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
                          "RECORDED REFLECTION",
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
                      entryThought,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entryText,
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

  Widget _buildCollectionTab() {
    if (_unlockedGifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            "Unlocking random gifts naturally during deep chat moments.",
            style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: _unlockedGifts.length,
      itemBuilder: (context, index) {
        final gift = _unlockedGifts[index];
        final String name = gift['name'] ?? 'Special Gift';
        final String emoji = gift['emoji'] ?? '🎁';
        final String desc = gift['desc'] ?? '';
        final String date = gift['date'] ?? '';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 34),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                "Recd $date",
                style: GoogleFonts.inter(
                  color: widget.companion.themeColor.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearThisMemory() async {
    final userId = AuthService().currentUserId ?? "guest_123";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AlertDialog(
          backgroundColor: ChatrixTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: widget.companion.themeColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Erase ${widget.companion.name}'s Memory?",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.companion.name} will forget everything about you.",
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                "All timeline milestones, reflections, your emotional profile, and relationship history with this companion will be permanently erased. Your chat transcript will remain untouched.",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Keep", style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Erase Memory",
                style: GoogleFonts.inter(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingMemory = true);
      try {
        await MemoryService().clearMemoryForCompanion(userId, widget.companion.name);
        
        // Clear gifts & active days from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('unlocked_gifts_${userId}_${widget.companion.name}');
        await prefs.remove('active_days_${userId}_${widget.companion.name}');
        await prefs.remove('last_chat_time_${userId}_${widget.companion.name}');

        if (mounted) {
          setState(() {
            _memoryDiary = [];
            _journeyEvents = [];
            _unlockedGifts = [];
            _messagesExchanged = 0;
            _daysTogether = 1;
            _sharedSecretsCount = 0;
            _insideJokesCount = 0;
            _memoriesCount = 0;
            _trustLevel = 10;
            _friendshipLevel = 15;
            _daysReturned = 1;
            _isClearingMemory = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${widget.companion.name}'s memory has been cleared.",
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: ChatrixTheme.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isClearingMemory = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to clear memory. Try again.", style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: ChatrixTheme.errorRose,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

