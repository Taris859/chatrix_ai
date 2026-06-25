import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../home_screen.dart';
import '../chat_screen.dart';
import '../../core/theme.dart';
import '../../services/firestore_repository.dart';
import '../../models/companion.dart';
import '../creation/ai_creation_studio.dart';
import '../../auth/auth_service.dart';
import '../../ui/emotional_space_registry.dart';
import '../../ui/emotional_space_screen.dart';
import '../../memory/memory_service.dart';


// Navigation state provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);
class LuxuryBottomNav extends ConsumerStatefulWidget {
  const LuxuryBottomNav({Key? key}) : super(key: key);

  @override
  ConsumerState<LuxuryBottomNav> createState() => _LuxuryBottomNavState();
}

class _LuxuryBottomNavState extends ConsumerState<LuxuryBottomNav> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingCompanion();
    });
  }

  Future<void> _checkPendingCompanion() async {
    final prefs = await SharedPreferences.getInstance();
    final companionId = prefs.getString('pending_companion_id');
    if (companionId != null && companionId.isNotEmpty) {
      await prefs.remove('pending_companion_id');
      try {
        final companionsList = await ref.read(companionsProvider.future);
        final companion = companionsList.firstWhere(
          (c) => c.id == companionId || c.id.toLowerCase() == companionId.toLowerCase(),
          orElse: () => companionsList.firstWhere(
            (c) => c.name.toLowerCase().replaceAll(' ', '-') == companionId.toLowerCase().replaceAll(' ', '-'),
            orElse: () => null as dynamic,
          ),
        );

        if (companion != null) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
            );
          }
        }
      } catch (e) {
        print("Error handling pending companion navigation: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: ChatrixTheme.background,
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          ChatsScreen(),
          ExploreScreen(),
          MyAIsScreen(),
        ],
      ),
      bottomNavigationBar: _buildLuxuryNavBar(context, currentIndex, ref),
    );
  }

  Widget _buildLuxuryNavBar(BuildContext context, int currentIndex, WidgetRef ref) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    currentIndex: currentIndex,
                    ref: ref,
                  ),
                  _buildNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Chats',
                    index: 1,
                    currentIndex: currentIndex,
                    ref: ref,
                  ),
                  _buildNavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: 'Explore',
                    index: 2,
                    currentIndex: currentIndex,
                    ref: ref,
                  ),
                  _buildNavItem(
                    icon: Icons.face_retouching_natural,
                    activeIcon: Icons.face_rounded,
                    label: 'My AI',
                    index: 3,
                    currentIndex: currentIndex,
                    ref: ref,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
    required WidgetRef ref,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => ref.read(navigationIndexProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withOpacity(0.35),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════
// CHATS SCREEN — Conversation List
// ═══════════════════════════════════════════════
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  List<String> _recentChats = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
  }

  Future<void> _loadRecentChats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentChats = prefs.getStringList('recent_chats') ?? [];
      _isLoadingRecent = false;
    });
  }

  Future<void> _deleteChat(Companion companion) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = AuthService().currentUserId ?? "guest_123";
    
    // 1. Delete permanently from Firestore and local cache
    await MemoryService().deleteChatPermanently(userId, companion.name);

    // 2. Remove companion from recent_chats list
    setState(() {
      _recentChats.remove(companion.id);
    });
    await prefs.setStringList('recent_chats', _recentChats);
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  "Conversations",
                  style: GoogleFonts.playfairDisplay(
                    color: ChatrixTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  "Your recent connections",
                  style: GoogleFonts.inter(
                    color: ChatrixTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),

              // Chat List
              Expanded(
                child: companionsAsync.when(
                  data: (companions) => _buildChatList(context, companions),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: ChatrixTheme.silverMist,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      "Unable to load conversations",
                      style: GoogleFonts.inter(color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, List<Companion> companions) {
    if (_isLoadingRecent) {
      return const Center(child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2));
    }

    final recentCompanions = companions.where((c) => _recentChats.contains(c.id)).toList();
    
    // Sort them by the order in _recentChats (most recent first)
    recentCompanions.sort((a, b) {
      return _recentChats.indexOf(a.id).compareTo(_recentChats.indexOf(b.id));
    });

    if (recentCompanions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recentCompanions.length,
      itemBuilder: (context, index) {
        final companion = recentCompanions[index];
        return Dismissible(
          key: Key('chat_${companion.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: ChatrixTheme.errorRose.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.delete_outline, color: ChatrixTheme.errorRose),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AlertDialog(
                  backgroundColor: ChatrixTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Row(
                    children: [
                      const Icon(Icons.delete_sweep_outlined, color: ChatrixTheme.errorRose, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "Delete Conversation",
                        style: GoogleFonts.playfairDisplay(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "The chat history with ${companion.name} will be erased from this list.",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: companion.themeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: companion.themeColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.psychology_outlined, color: companion.themeColor, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${companion.name} will still remember you. Erase memories from Settings.",
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel", style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("Delete Chat", style: GoogleFonts.inter(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
          onDismissed: (_) => _deleteChat(companion),
          child: _buildChatItem(context, companion, index),
        );
      },
    );
  }

  Widget _buildChatItem(BuildContext context, Companion companion, int index) {
    final hasImg = companion.imagePath != null;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
        );
        _loadRecentChats(); // Reload when coming back in case a new chat started
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ChatrixTheme.surface.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Avatar
            companion.buildAvatar(radius: 26),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          companion.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (companion.isPremium)
                        Icon(Icons.star_rounded, color: ChatrixTheme.champagneGold, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companion.archetype,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 20),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 40 * index)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "No conversations yet",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start a connection from the Home screen",
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.2),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// EXPLORE SCREEN — Search & Discover
// ═══════════════════════════════════════════════
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _searchQuery = '';
  String _selectedTag = 'all';

  final List<Map<String, dynamic>> _tags = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Dark Romance', 'value': 'dark-romance'},
    {'label': 'Comfort', 'value': 'comfort'},
    {'label': 'Dangerous', 'value': 'dangerous'},
    {'label': 'Toxic', 'value': 'toxic'},
    {'label': 'Mysterious', 'value': 'mysterious'},
    {'label': 'Chaotic', 'value': 'chaotic'},
    {'label': 'Gentle', 'value': 'gentle'},
    {'label': 'Romantic', 'value': 'romantic'},
    {'label': 'Fun', 'value': 'fun'},
  ];

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  "Explore",
                  style: GoogleFonts.playfairDisplay(
                    color: ChatrixTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: ChatrixTheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Search companions...",
                      hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: Colors.white24, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Tags
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    final isSelected = _selectedTag == tag['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTag = tag['value']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Text(
                          tag['label'],
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.white38,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Grid
              Expanded(
                child: companionsAsync.when(
                  data: (companions) {
                    var filtered = companions.where((c) {
                      final isUnknown = c.name.toLowerCase().trim() == 'unknown' || c.name.trim().isEmpty;
                      final isPrivate = !c.isPublic;
                      return !isUnknown && !isPrivate;
                    }).toList();

                    // Apply tag filter
                    if (_selectedTag != 'all') {
                      filtered = filtered.where((c) => c.tags.contains(_selectedTag)).toList();
                    }

                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      filtered = filtered.where((c) =>
                        c.name.toLowerCase().contains(_searchQuery) ||
                        c.archetype.toLowerCase().contains(_searchQuery) ||
                        c.personality.toLowerCase().contains(_searchQuery)
                      ).toList();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 12),
                            Text(
                              "No companions found",
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildExploreCard(context, filtered[index], index),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2),
                  ),
                  error: (_, __) => Center(
                    child: Text("Unable to load", style: GoogleFonts.inter(color: Colors.white38)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Create Your Own FAB
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'explore_fab',
        backgroundColor: ChatrixTheme.surface,
        foregroundColor: Colors.white70,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AICreationStudio()),
        ),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          "Create",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildExploreCard(BuildContext context, Companion companion, int index) {
    final hasImg = companion.imagePath != null;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: ChatrixTheme.surface.withOpacity(0.25),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                companion.themeColor.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: companion.buildAvatar(radius: 34),
                  ),
                ),
                if (companion.isPremium) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ChatrixTheme.champagneGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "PREMIUM",
                      style: TextStyle(
                        color: ChatrixTheme.champagneGold,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  companion.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  companion.archetype,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: 60 + (index * 25))).fadeIn(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PRESENCE SCREEN — Activity & Notifications
// ═══════════════════════════════════════════════
class PresenceScreen extends ConsumerStatefulWidget {
  const PresenceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends ConsumerState<PresenceScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.75);
  int _currentIndex = 0;
  List<Map<String, dynamic>> _dynamicNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('presence_history') ?? [];
    
    List<Map<String, dynamic>> loaded = [];
    final now = DateTime.now();

    for (String raw in history) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        final dt = DateTime.parse(data['timestamp']);
        if (dt.isAfter(now)) continue;
        loaded.add({
          'companion': data['companion'] ?? 'Unknown',
          'message': data['message'] ?? '',
        });
      } catch (e) {}
    }
    
    setState(() {
      _dynamicNotifications = loaded;
    });
  }

  String _getMuffledHint(String companionName) {
    // Check if there's a recent notification
    final recent = _dynamicNotifications.where((n) => n['companion'] == companionName).toList();
    if (recent.isNotEmpty) {
      return "You can hear something moving behind the door...";
    }

    final lower = companionName.toLowerCase();
    if (lower.contains('dante')) return "The faint smell of smoke and rain...";
    if (lower.contains('arthur')) return "The quiet rustle of turning pages...";
    if (lower.contains('valentina')) return "Muffled jazz and clinking glass...";
    if (lower.contains('haru')) return "The low hum of server fans...";
    if (lower.contains('kaelen')) return "Absolute, controlled silence...";
    if (lower.contains('alistair')) return "A cold draft slips under the door...";
    if (lower.contains('leo')) return "The faint strum of an acoustic guitar...";
    return "A quiet presence lingers...";
  }

  @override
  Widget build(BuildContext context) {
    final companionsAsync = ref.watch(companionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dark Hallway Atmosphere
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.black87,
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 24, 8),
                  child: Text(
                    "The Hallway",
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(duration: 1000.ms).slideX(begin: -0.05),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 24, 32),
                  child: Text(
                    "Walk the corridor. Who will you visit?",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      letterSpacing: 0.5,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 1200.ms, delay: 200.ms),
                ),

                // Doors
                Expanded(
                  child: companionsAsync.when(
                    data: (companions) {
                      if (companions.isEmpty) {
                        return const Center(child: Text("The hallway is empty.", style: TextStyle(color: Colors.white54)));
                      }
                      return PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemCount: companions.length,
                        itemBuilder: (context, index) {
                          final companion = companions[index];
                          final isFocused = _currentIndex == index;
                          return _buildDoor(context, companion, isFocused, index);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: ChatrixTheme.silverMist)),
                    error: (_, __) => const Center(child: Text("Lost in the dark.", style: TextStyle(color: Colors.white54))),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoor(BuildContext context, Companion companion, bool isFocused, int index) {
    final hint = _getMuffledHint(companion.name);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: Builder(
                builder: (context) {
                  final space = EmotionalSpaceRegistry.getSpaceForCompanion(companion.id);
                  if (space == null) {
                    return ChatScreen(companion: companion);
                  }
                  return EmotionalSpaceScreen(
                    space: space,
                    companion: companion,
                  );
                },
              ),
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
        margin: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isFocused ? 20 : 60,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0C), // Dark wood/metal feel
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? companion.themeColor.withOpacity(0.3) : Colors.white.withOpacity(0.02),
            width: 2,
          ),
          boxShadow: [
            if (isFocused)
              BoxShadow(
                color: companion.themeColor.withOpacity(0.12),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 20), // Light bleeding from bottom of door
              )
          ],
        ),
        child: Stack(
          children: [
            // Door texture / grain
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Image.asset(
                  'assets/backgrounds/cinematic_particles.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
            // Door Handle
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.28,
              child: Container(
                width: 6,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(-2, 2)),
                  ],
                ),
              ),
            ),
            // Light bleeding from the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      companion.themeColor.withOpacity(isFocused ? 0.35 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 2500.ms, begin: 0.6, end: 1.0),
            ),
            // Companion Info (Name plate)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: isFocused ? 1.0 : 0.2,
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      companion.name.toUpperCase(),
                      style: GoogleFonts.cinzel(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: isFocused ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: companion.themeColor.withOpacity(0.9),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MY AI SCREEN — User Created Companions
// ═══════════════════════════════════════════════
class MyAIsScreen extends ConsumerStatefulWidget {
  const MyAIsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyAIsScreen> createState() => _MyAIsScreenState();
}

class _MyAIsScreenState extends ConsumerState<MyAIsScreen> {
  @override
  Widget build(BuildContext context) {
    final companionsAsync = ref.watch(companionsProvider);
    final currentUserId = AuthService().currentUserId ?? "anonymous_user";

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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  "My AI",
                  style: GoogleFonts.playfairDisplay(
                    color: ChatrixTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  "Your privately engineered custom souls",
                  style: GoogleFonts.inter(
                    color: ChatrixTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),

              // Creation Grid
              Expanded(
                child: companionsAsync.when(
                  data: (companions) {
                    final userCreations = companions.where((c) =>
                      c.creatorId == currentUserId
                    ).toList();

                    if (userCreations.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: userCreations.length,
                      itemBuilder: (context, index) => _buildCreationCard(context, userCreations[index], index),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2),
                  ),
                  error: (_, __) => Center(
                    child: Text("Unable to load creations", style: GoogleFonts.inter(color: Colors.white38)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'my_ai_fab',
        backgroundColor: ChatrixTheme.surface,
        foregroundColor: Colors.white70,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AICreationStudio()),
        ).then((_) {
          ref.invalidate(companionsProvider);
        }),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          "Create",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.12),
            ),
            const SizedBox(height: 20),
            Text(
              "No custom AIs created yet",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Awaken your own companion, personalize their voice, archetype, and emotional spectrum.",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AICreationStudio()),
              ).then((_) {
                ref.invalidate(companionsProvider);
              }),
              child: const Text("Awaken Soul"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationCard(BuildContext context, Companion companion, int index) {
    final hasImg = companion.imagePath != null;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: ChatrixTheme.surface.withOpacity(0.25),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                companion.themeColor.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: companion.buildAvatar(radius: 34),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (companion.isPublic ? Colors.greenAccent : ChatrixTheme.neonPink).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        companion.isPublic ? "PUBLIC" : "PRIVATE",
                        style: TextStyle(
                          color: companion.isPublic ? Colors.greenAccent : ChatrixTheme.neonPink,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (companion.isPremium)
                      Icon(Icons.star_rounded, color: ChatrixTheme.champagneGold, size: 12),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  companion.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  companion.archetype,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: 60 + (index * 25))).fadeIn(),
      ),
    );
  }
}
