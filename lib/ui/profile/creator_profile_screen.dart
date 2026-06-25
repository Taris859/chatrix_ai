import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../models/companion.dart';
import '../../services/firestore_repository.dart';
import '../chat_screen.dart';

class CreatorProfileScreen extends ConsumerStatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({
    Key? key,
    required this.creatorId,
  }) : super(key: key);

  @override
  ConsumerState<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  bool _isLoading = true;
  String _creatorName = "Creator";
  String? _creatorImage;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCreatorDetails();
  }

  Future<void> _loadCreatorDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 1. Fetch Creator Info
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _creatorName = data['username'] ?? 'Wanderer';
        _creatorImage = data['profile_image'];
      }

      // 2. Check if current user is following the creator
      final followDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.creatorId)
          .get();
      
      _isFollowing = followDoc.exists;

      // 3. Fetch Follower & Following count
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorId)
          .collection('followers')
          .count()
          .get();
      _followersCount = followersSnapshot.count ?? 0;

      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorId)
          .collection('following')
          .count()
          .get();
      _followingCount = followingSnapshot.count ?? 0;

    } catch (e) {
      print("Error loading creator details: $e");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else {
        _followersCount--;
      }
    });

    try {
      final followRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.creatorId);

      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorId)
          .collection('followers')
          .doc(currentUser.uid);

      if (_isFollowing) {
        await followRef.set({'timestamp': FieldValue.serverTimestamp()});
        await followerRef.set({'timestamp': FieldValue.serverTimestamp()});
      } else {
        await followRef.delete();
        await followerRef.delete();
      }
    } catch (e) {
      print("Error toggling follow: $e");
      // Revert state on error
      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followersCount++;
        } else {
          _followersCount--;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionsAsync = ref.watch(companionsProvider);

    return Scaffold(
      backgroundColor: ChatrixTheme.background,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))
              : CustomScrollView(
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
                        "CREATOR PROFILE",
                        style: GoogleFonts.cinzel(
                          color: ChatrixTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            _buildAvatar(),
                            const SizedBox(height: 16),
                            Text(
                              _creatorName,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFollowStats(),
                            const SizedBox(height: 24),
                            _buildFollowButton(),
                            const SizedBox(height: 32),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "PUBLIC CREATIONS",
                                style: GoogleFonts.inter(
                                  color: ChatrixTheme.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    companionsAsync.when(
                      data: (companions) {
                        final creatorCompanions = companions.where((c) =>
                          c.creatorId == widget.creatorId && c.isPublic
                        ).toList();

                        if (creatorCompanions.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                "No public companions created yet.",
                                style: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.82,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final companion = creatorCompanions[index];
                                return _buildCreationCard(context, companion);
                              },
                              childCount: creatorCompanions.length,
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2)),
                      ),
                      error: (_, __) => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text("Unable to load creations", style: TextStyle(color: Colors.white30))),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasImg = _creatorImage != null && _creatorImage!.isNotEmpty;
    final initial = _creatorName.isNotEmpty ? _creatorName[0].toUpperCase() : '?';

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ChatrixTheme.bioluminescence.withOpacity(0.3), width: 2),
        image: hasImg
            ? DecorationImage(
                image: MemoryImage(base64Decode(_creatorImage!.split(',').last)),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.white.withOpacity(0.05),
      ),
      child: hasImg
          ? null
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white70,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildFollowStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem("Followers", _followersCount),
        Container(
          width: 1,
          height: 24,
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(horizontal: 24),
        ),
        _buildStatItem("Following", _followingCount),
      ],
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == widget.creatorId) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.white.withOpacity(0.08) : ChatrixTheme.bioluminescence,
          foregroundColor: _isFollowing ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: _isFollowing ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none,
          ),
          elevation: _isFollowing ? 0 : 4,
        ),
        onPressed: _toggleFollow,
        child: Text(
          _isFollowing ? "FOLLOWING" : "FOLLOW",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCreationCard(BuildContext context, Companion companion) {
    return GestureDetector(
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
              Text(
                companion.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
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
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
