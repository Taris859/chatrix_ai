import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import 'chat_screen.dart';
import '../services/firestore_repository.dart';
import '../models/companion.dart';
import '../auth/auth_service.dart';
import '../auth/auth_provider.dart';
import 'premium/subscription_screen.dart';
import 'creation/ai_creation_studio.dart';
import 'profile/profile_screen.dart';

/// Highly stylized Discovery screen inspired by the premium Chai platform.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedGender = "All";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Seeded stable chat activity numbers to bring cards to life.
  String _getSeededActivity(String id) {
    final val = int.tryParse(id) ?? id.hashCode;
    final random = Random(val + 500);
    if (val == 1) return "41.1M";
    if (val == 2) return "15.6M";
    if (val == 3) return "14.8M";
    if (val == 4) return "4.8M";
    if (val == 11) return "2.4M";
    
    final millions = random.nextInt(20) + 1;
    final hundredThousands = random.nextInt(9);
    if (millions > 5) {
      return "${millions}.${hundredThousands}M";
    } else {
      final thousands = random.nextInt(900) + 100;
      return "${thousands}K";
    }
  }

  /// Clean greeting message for descriptive snippet on grid card.
  String _getCleanDescription(String greeting) {
    return greeting.replaceAll('*', '').trim();
  }

  Future<void> _deleteCompanion(Companion companion) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localList = prefs.getStringList('local_custom_companions') ?? [];
    
    bool isLocal = false;
    for (var raw in localList) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        if (data['id'] == companion.id || companion.id.startsWith('local_')) {
          isLocal = true;
          break;
        }
      } catch (e) {}
    }

    // Bypassed creator check: anyone can delete any AI, even if created by others.

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
      if (isLocal) {
        localList.removeWhere((raw) {
          try {
            final data = jsonDecode(raw);
            return data['id'] == companion.id || companion.id.startsWith('local_');
          } catch (e) {
            return false;
          }
        });
        await prefs.setStringList('local_custom_companions', localList);
      } else {
        // If it's a Firestore companion (ID is not static fallback range 1-108), delete it from Firestore
        final idVal = int.tryParse(companion.id);
        if (idVal == null) {
          try {
            await FirebaseFirestore.instance.collection('ai_companions').doc(companion.id).delete();
          } catch (e) {
            print("Error deleting from Firestore: $e");
          }
        }
      }
      
      ref.invalidate(companionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${companion.name} deleted.", style: const TextStyle(color: Colors.white)),
            backgroundColor: ChatrixTheme.surface,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionsAsync = ref.watch(companionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: companionsAsync.when(
            data: (companions) => _buildContent(context, companions),
            loading: () => _buildLoadingState(),
            error: (err, stack) => _buildErrorState(context, err),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        backgroundColor: ChatrixTheme.champagneGold.withOpacity(0.95),
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AICreationStudio()),
          ).then((_) {
            ref.invalidate(companionsProvider);
          });
        },
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Companion> allCompanions) {
    // Filter out "Unknown" named companions and private companions from public lists
    final publicCompanions = allCompanions.where((c) {
      final isUnknown = c.name.toLowerCase().trim() == 'unknown' || c.name.trim().isEmpty;
      final isPrivate = !c.isPublic;
      return !isUnknown && !isPrivate;
    }).toList();

    // Apply Filtering
    var filteredCompanions = publicCompanions;
    bool isFiltering = false;

    if (_selectedGender != "All") {
      isFiltering = true;
      CompanionGender targetGender;
      if (_selectedGender == "Male") targetGender = CompanionGender.male;
      else if (_selectedGender == "Female") targetGender = CompanionGender.female;
      else targetGender = CompanionGender.nonBinary;
      filteredCompanions = filteredCompanions.where((c) => c.gender == targetGender).toList();
    }

    if (_searchQuery.isNotEmpty) {
      isFiltering = true;
      final lowercaseQuery = _searchQuery.toLowerCase();
      filteredCompanions = filteredCompanions.where((c) =>
        c.name.toLowerCase().contains(lowercaseQuery) ||
        c.archetype.toLowerCase().contains(lowercaseQuery) ||
        c.personality.toLowerCase().contains(lowercaseQuery)
      ).toList();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Sticky Header (Logo, Search Bar, and Gender Pills) ──
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopLogoRow(context),
              _buildSearchBar(),
              _buildGenderPills(),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Empty State if no AIs match filters ──
        if (filteredCompanions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: Colors.white.withOpacity(0.12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No companions found",
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Try adjusting your filters or search keywords",
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else if (isFiltering)
          // ── Search/Filter 2-Column Grid ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, index) => _buildChaiPortraitCard(ctx, filteredCompanions[index], index),
                childCount: filteredCompanions.length,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
              ),
            ),
          )
        else
          // ── Curated Emotional Discovery Carousels ──
          SliverToBoxAdapter(
            child: _buildDiscoveryCarousels(context, publicCompanions),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildDiscoveryCarousels(BuildContext context, List<Companion> allCompanions) {
    // Helper to get up to 12 companions matching a condition
    List<Companion> getCategory(bool Function(Companion) condition) {
      final list = allCompanions.where(condition).toList()..shuffle(Random(42)); // Stable shuffle
      return list.take(12).toList();
    }

    final featured = (List<Companion>.from(allCompanions)..shuffle(Random(123))).take(10).toList();
    final dangerous = getCategory((c) => c.tags.contains('dangerous') || c.tags.contains('toxic'));
    final comfort = getCategory((c) => c.tags.contains('comfort') || c.tags.contains('gentle'));
    final chaotic = getCategory((c) => c.tags.contains('chaotic') || c.tags.contains('fun'));
    final ruined = getCategory((c) => c.tags.contains('dark-romance') || c.tags.contains('mysterious'));
    final desi = getCategory((c) => c.personality.contains('Hinglish'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCarouselRow(context, "Featured: Tonight's Presence", featured),
        _buildCarouselRow(context, "Dangerous After Midnight", dangerous),
        _buildCarouselRow(context, "Comfort Souls", comfort),
        _buildCarouselRow(context, "Chaotic Attachments", chaotic),
        _buildCarouselRow(context, "Emotionally Ruined", ruined),
        _buildCarouselRow(context, "Desi Connections", desi),
      ],
    );
  }

  Widget _buildCarouselRow(BuildContext context, String title, List<Companion> companions) {
    if (companions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CategoryGridScreen(
                        title: title, 
                        companions: companions,
                        cardBuilder: (ctx, companion, idx) => _buildChaiPortraitCard(ctx, companion, idx),
                      )
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Text(
                      "See All",
                      style: GoogleFonts.inter(
                        color: ChatrixTheme.champagneGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280, // Height for the portrait cards
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: companions.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 170, // Fixed width for horizontal scrolling cards
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildChaiPortraitCard(context, companions[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Logo Header Bar (Matches Mockup)
  // ═══════════════════════════════════════════
  Widget _buildTopLogoRow(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Text(
            "CHATRIX",
            style: GoogleFonts.outfit(
              color: isPremium ? ChatrixTheme.champagneGold : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              shadows: isPremium
                  ? [
                      Shadow(
                        color: ChatrixTheme.champagneGold.withOpacity(0.4),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: isPremium
                  ? LinearGradient(
                      colors: [
                        ChatrixTheme.champagneGold,
                        const Color(0xFFFFDF73),
                      ],
                    )
                  : null,
              color: isPremium ? null : const Color(0xFFE53935),
              border: Border.all(
                color: isPremium ? ChatrixTheme.champagneGold : const Color(0xFFE53935),
                width: 1.5,
              ),
              boxShadow: [
                if (isPremium)
                  BoxShadow(
                    color: ChatrixTheme.champagneGold.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPremium) ...[
                  const Icon(Icons.star_rounded, color: Colors.black, size: 10),
                  const SizedBox(width: 3),
                ],
                Text(
                  isPremium ? "PREMIUM" : "BASIC",
                  style: TextStyle(
                    color: isPremium ? Colors.black : const Color(0xFFE53935),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildHeaderIcon(
            icon: Icons.star_rounded,
            color: ChatrixTheme.champagneGold,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            isPremium: isPremium,
          ),
          const SizedBox(width: 8),
          _buildHeaderIcon(
            icon: Icons.person_rounded,
            color: isPremium ? ChatrixTheme.champagneGold : Colors.white70,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            isPremium: isPremium,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ChatrixTheme.surface.withOpacity(0.35),
          border: Border.all(
            color: isPremium ? ChatrixTheme.champagneGold.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            if (isPremium && icon == Icons.star_rounded)
              BoxShadow(
                color: ChatrixTheme.champagneGold.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Search Bar Widget
  // ═══════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() {
            _searchQuery = v.trim();
          });
        },
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search "Best Friend"...',
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded, color: Colors.white30, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                    });
                  },
                  child: const Icon(Icons.clear_rounded, color: Colors.white30, size: 18),
                )
              : null,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Sticky Gender Selection Pills Bar
  // ═══════════════════════════════════════════
  Widget _buildGenderPills() {
    final List<String> genders = ["All", "Male", "Female", "Non-Binary"];
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genders.length,
        itemBuilder: (context, index) {
          final gender = genders[index];
          final isSelected = _selectedGender == gender;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : ChatrixTheme.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  gender,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Chai Portrait Card Layout
  // ═══════════════════════════════════════════
  Widget _buildChaiPortraitCard(BuildContext context, Companion companion, int index) {
    final hasImg = companion.imagePath != null;
    final activity = _getSeededActivity(companion.id);
    final cleanDesc = _getCleanDescription(companion.greeting);

    final isMidnight = companion.tags.contains('midnight-only');
    final isRain = companion.tags.contains('rain-only');
    final isLegendary = companion.tags.contains('legendary');

    List<BoxShadow> shadows = [
      BoxShadow(
        color: isMidnight 
            ? const Color(0xFF6200EA).withOpacity(0.6) 
            : (isLegendary ? ChatrixTheme.champagneGold.withOpacity(0.4) : Colors.black.withOpacity(0.2)),
        blurRadius: (isMidnight || isLegendary) ? 20 : 10,
        spreadRadius: (isMidnight || isLegendary) ? 2 : 0,
        offset: const Offset(0, 4),
      ),
    ];

    Color borderColor = Colors.white.withOpacity(0.05);
    if (isLegendary) borderColor = ChatrixTheme.champagneGold.withOpacity(0.6);
    else if (isMidnight) borderColor = const Color(0xFF6200EA).withOpacity(0.5);
    else if (isRain) borderColor = Colors.lightBlueAccent.withOpacity(0.3);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
        ),
        onLongPress: () => _deleteCompanion(companion),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: ChatrixTheme.surface.withOpacity(0.18),
            border: Border.all(color: borderColor, width: (isLegendary || isMidnight) ? 1.5 : 1),
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              // 1. Background image or dynamic visual gradient
              Positioned.fill(
                child: hasImg
                    ? Image.asset(
                        companion.imagePath!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              companion.themeColor.withOpacity(0.28),
                              Colors.black,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            companion.initials,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white.withOpacity(0.04),
                              fontSize: 90,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
              ),

              // 2. Mist overlay for Rain Only AIs
              if (isRain)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Linear Black Gradient Fading to Black at the Bottom
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        isMidnight ? Colors.deepPurple.withOpacity(0.35) : Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // 4. Creator Capsule (Top Left)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: companion.themeColor.withOpacity(0.8),
                        ),
                        child: Center(
                          child: Text(
                            companion.initials[0],
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        companion.creatorId == null ? "Official Companion" : "Custom Companion",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Slanted PRO Ribbon (Top Right)
              if (companion.isPremium)
                Positioned(
                  top: 10,
                  right: -20,
                  child: Transform.rotate(
                    angle: 0.785398, // 45 degrees
                    child: Container(
                      width: 76,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: ChatrixTheme.champagneGold,
                      child: const Text(
                        "PRO",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Activity Pill (Bottom Left, above bottom text)
              Positioned(
                bottom: 84,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white54,
                        size: 9,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activity,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Content (Bottom Panel)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      companion.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cleanDesc,
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: (index % 10) * 45)),
    );
  }

  // ═══════════════════════════════════════════
  // Loading & Error States
  // ═══════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo/logo.png',
            width: 64,
            height: 64,
            errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: ChatrixTheme.silverMist,
            strokeWidth: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "Connection Lost",
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Pull down to retry",
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Expanded Category Grid Screen
// ═══════════════════════════════════════════
class CategoryGridScreen extends StatelessWidget {
  final String title;
  final List<Companion> companions;
  final Widget Function(BuildContext, Companion, int) cardBuilder;

  const CategoryGridScreen({
    Key? key,
    required this.title,
    required this.companions,
    required this.cardBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: companions.isEmpty
            ? const Center(child: Text("No companions found", style: TextStyle(color: Colors.white54)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: companions.length,
                itemBuilder: (context, index) => cardBuilder(context, companions[index], index),
              ),
      ),
    );
  }
}