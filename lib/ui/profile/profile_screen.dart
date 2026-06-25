import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../auth/auth_service.dart';
import '../settings_screen.dart';
import '../premium/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../memory/memory_service.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'creator_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../services/firestore_repository.dart';
import '../chat_screen.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _socialController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();
  final TextEditingController _comfortController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPremium = false;
  String _email = '';
  String _username = 'Wanderer';
  String? _profileImageBase64;
  List<Map<String, dynamic>> _followedCreators = [];
  String _referralCode = '';
  int _referralCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _dobController.dispose();
    _socialController.dispose();
    _hobbiesController.dispose();
    _attachmentController.dispose();
    _comfortController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          _username = data['username'] ?? 'Wanderer';
          _isPremium = data['premium_status'] ?? false;
          _referralCode = data['referral_code'] ?? '';
          _referralCount = data['referral_count'] ?? 0;
          
          if (_referralCode.isEmpty) {
            _referralCode = _generateReferralCode();
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'referral_code': _referralCode,
              'referral_count': 0,
              'referred_users': [],
            }, SetOptions(merge: true));
          }
          
          _profileImageBase64 = data['profile_image'];
          
          final idData = data['identity'] as Map<String, dynamic>? ?? {};
          final emoData = data['emotional_profile'] as Map<String, dynamic>? ?? {};
          final socData = data['social_memory'] as Map<String, dynamic>? ?? {};
          final lifeData = data['lifestyle'] as Map<String, dynamic>? ?? {};

          _nameController.text = idData['name'] ?? data['username'] ?? '';
          _nicknameController.text = idData['nickname'] ?? '';
          _dobController.text = idData['dob'] ?? data['dob'] ?? '';
          
          _socialController.text = socData['important_people'] ?? data['bio'] ?? '';
          _hobbiesController.text = lifeData['hobbies'] ?? '';
          
          _attachmentController.text = emoData['attachment_style'] ?? '';
          _comfortController.text = emoData['comfort_style'] ?? '';
        }

        // Fetch followed creators
        final followingSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('following')
            .get();
        final List<String> followedCreatorIds = followingSnapshot.docs.map((doc) => doc.id).toList();

        List<Map<String, dynamic>> creatorsList = [];
        for (var creatorId in followedCreatorIds) {
          final creatorDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
          if (creatorDoc.exists && creatorDoc.data() != null) {
            creatorsList.add({
              'uid': creatorId,
              'username': creatorDoc.data()?['username'] ?? 'Wanderer',
              'profile_image': creatorDoc.data()?['profile_image'],
            });
          }
        }
        _followedCreators = creatorsList;
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
        setState(() {
          _profileImageBase64 = base64Str;
        });
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'profile_image': base64Str,
          }, SetOptions(merge: true));
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile portrait updated successfully.")),
            );
          }
        }
      }
    } catch (e) {
      print("Error picking profile image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': newName.isEmpty ? 'Wanderer' : newName,
          'identity': {
            'name': newName,
            'nickname': _nicknameController.text.trim(),
            'dob': _dobController.text.trim(),
          },
          'emotional_profile': {
            'attachment_style': _attachmentController.text.trim(),
            'comfort_style': _comfortController.text.trim(),
          },
          'social_memory': {
            'important_people': _socialController.text.trim(),
          },
          'lifestyle': {
            'hobbies': _hobbiesController.text.trim(),
          }
        }, SetOptions(merge: true));
            
        setState(() {
          _username = newName.isEmpty ? 'Wanderer' : newName;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Profile updated to $newName"),
              backgroundColor: ChatrixTheme.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print("Error saving profile: $e");
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _signOut() async {
    HapticFeedback.mediumImpact();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChatrixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Sign Out", 
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Text(
          "Are you sure you want to sign out?", 
          style: GoogleFonts.inter(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _deleteAccount() async {
    HapticFeedback.heavyImpact();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChatrixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Account", 
          style: GoogleFonts.playfairDisplay(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)
        ),
        content: Text(
          "Are you absolutely sure you want to delete your account? This will permanently erase your AI companions, your chat history, and your profile. This action cannot be undone.", 
          style: GoogleFonts.inter(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE EVERYTING", style: TextStyle(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final uid = user.uid;
          
          final companionsQuery = await FirebaseFirestore.instance.collection('ai_companions').where('created_by', isEqualTo: uid).get();
          for (var doc in companionsQuery.docs) {
             await doc.reference.delete();
          }

          await FirebaseFirestore.instance.collection('users').doc(uid).delete();
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          await user.delete();
          
          await AuthService().signOut();
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } catch (e) {
        print("Error deleting account: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("Failed to delete account. Please sign out and sign in again before trying to delete."),
             backgroundColor: ChatrixTheme.errorRose,
           ));
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatrixTheme.background,
      body: Container(
        decoration: ChatrixTheme.cinematicBackground,
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: ChatrixTheme.silverMist,
                    strokeWidth: 2,
                  ),
                )
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
                        "PROFILE",
                        style: GoogleFonts.playfairDisplay(
                          color: ChatrixTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),

                            _buildAvatar().animate().fadeIn(duration: 600.ms).scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                              duration: 600.ms,
                            ),

                            const SizedBox(height: 20),

                            Text(
                              _username,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate().fadeIn(delay: 200.ms),

                            const SizedBox(height: 4),

                            if (_email.isNotEmpty)
                              Text(
                                _email,
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ).animate().fadeIn(delay: 300.ms),

                            const SizedBox(height: 12),

                            if (_isPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ChatrixTheme.champagneGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: ChatrixTheme.champagneGold.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: ChatrixTheme.champagneGold, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "PREMIUM",
                                      style: GoogleFonts.inter(
                                        color: ChatrixTheme.champagneGold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 400.ms),

                            const SizedBox(height: 40),

                            _buildSectionTitle("IDENTITY LAYER"),
                            const SizedBox(height: 12),
                            _buildInputField(_nameController, "What is your real name?"),
                            const SizedBox(height: 12),
                            _buildInputField(_nicknameController, "What do they call you in the dark?"),
                            const SizedBox(height: 12),
                            _buildInputField(_dobController, "Date of Birth (e.g., Oct 31)"),

                            const SizedBox(height: 32),
                            _buildSectionTitle("EMOTIONAL PROFILE"),
                            const SizedBox(height: 12),
                            _buildInputField(_attachmentController, "Attachment Style (e.g., Needs reassurance, overthinks)", maxLines: 2),
                            const SizedBox(height: 12),
                            _buildInputField(_comfortController, "What kind of things comfort you at 2AM?", maxLines: 2),

                            const SizedBox(height: 32),
                            _buildSectionTitle("SOCIAL & LIFESTYLE MEMORY"),
                            const SizedBox(height: 12),

                            const SizedBox(height: 12),
                            _buildInputField(_socialController, "Who matters to you the most? (Friends, family)", maxLines: 2),
                            const SizedBox(height: 12),
                            _buildInputField(_hobbiesController, "Music taste, favorite movies, late night habits...", maxLines: 2),

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ChatrixTheme.amethyst,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: _isSaving ? null : _saveProfile,
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        "ENGRAIN MEMORIES",
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 32),
                            _buildSectionTitle("MY CREATED AIS"),
                            const SizedBox(height: 12),
                            _buildCreatedAIsSection(),

                            const SizedBox(height: 32),
                            _buildSectionTitle("CREATORS I FOLLOW"),
                            const SizedBox(height: 12),
                            _buildFollowedCreatorsSection(),

                            const SizedBox(height: 32),
                            _buildReferralCard(),

                            const SizedBox(height: 48),

                            _buildSectionTitle("PREFERENCES & PRIVACY"),
                            const SizedBox(height: 12),

                            _buildActionCard(
                              icon: Icons.star_outline_rounded,
                              title: "Premium",
                              subtitle: _isPremium ? "Active" : "Upgrade your experience",
                              color: ChatrixTheme.champagneGold,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                              ).then((_) => _loadProfile()),
                            ),

                            _buildActionCard(
                              icon: Icons.notifications_outlined,
                              title: "Communication Settings",
                              subtitle: "Presence, notifications, ambient events",
                              color: ChatrixTheme.silverMist,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ),
                            ),

                            _buildActionCard(
                              icon: Icons.lock_outline_rounded,
                              title: "Privacy Settings",
                              subtitle: "Manage data visibility and sharing",
                              color: ChatrixTheme.silverMist,
                              onTap: () => _showPrivacySettingsSheet(context),
                            ),

                            _buildActionCard(
                              icon: Icons.info_outline_rounded,
                              title: "About Chatrix",
                              subtitle: "Mission, story, and contact channels",
                              color: ChatrixTheme.silverMist,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AboutScreen()),
                              ),
                            ),

                            _buildActionCard(
                              icon: Icons.description_outlined,
                              title: "Privacy Policy",
                              subtitle: "Learn how your digital memories are secured",
                              color: ChatrixTheme.silverMist,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                              ),
                            ),

                            _buildActionCard(
                              icon: Icons.delete_outline_rounded,
                              title: "Clear Memory",
                              subtitle: "Wipe all conversational context",
                              color: ChatrixTheme.errorRose,
                              onTap: () => _showClearMemoryDialog(context),
                            ),

                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: ChatrixTheme.errorRose.withOpacity(0.3)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _signOut,
                                child: Text(
                                  "Sign Out",
                                  style: GoogleFonts.inter(
                                    color: ChatrixTheme.errorRose,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Delete Account ──
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _deleteAccount,
                                child: Text(
                                  "Delete Account",
                                  style: GoogleFonts.inter(
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Footer
                            Text(
                              "Chatrix v1.0.0",
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.15),
                                fontSize: 11,
                              ),
                            ),

                            const SizedBox(height: 40),
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

  Widget _buildAvatar() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final hasProfileImage = _profileImageBase64 != null && _profileImageBase64!.isNotEmpty;
    
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasProfileImage ? null : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPremium
                ? [
                    ChatrixTheme.champagneGold,
                    const Color(0xFFFFDF73).withOpacity(0.6),
                  ]
                : [
                    ChatrixTheme.amethyst.withOpacity(0.4),
                    ChatrixTheme.roseDust.withOpacity(0.2),
                  ],
          ),
          image: hasProfileImage
              ? DecorationImage(
                  image: MemoryImage(base64Decode(_profileImageBase64!.split(',').last)),
                  fit: BoxFit.cover,
                )
              : null,
          border: Border.all(
            color: _isPremium ? ChatrixTheme.champagneGold : Colors.white.withOpacity(0.1),
            width: _isPremium ? 3 : 2,
          ),
          boxShadow: [
            if (_isPremium)
              BoxShadow(
                color: ChatrixTheme.champagneGold.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: hasProfileImage
            ? null
            : Center(
                child: Text(
                  initial,
                  style: GoogleFonts.playfairDisplay(
                    color: _isPremium ? Colors.black : Colors.white.withOpacity(0.8),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCreatedAIsSection() {
    final companionsAsync = ref.watch(companionsProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return companionsAsync.when(
      data: (companions) {
        final myCompanions = companions.where((c) => c.creatorId == user.uid).toList();
        if (myCompanions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: ChatrixTheme.surface.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              "You haven't custom-engineered any companions yet.",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: myCompanions.length,
            itemBuilder: (context, index) {
              final companion = myCompanions[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(companion: companion)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 90,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: companion.themeColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: companion.buildAvatar(radius: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        companion.name,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        companion.archetype,
                        style: GoogleFonts.inter(color: Colors.white30, fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: ChatrixTheme.silverMist, strokeWidth: 2)),
      error: (_, __) => const Center(child: Text("Error loading companions", style: TextStyle(color: Colors.white38))),
    );
  }

  Widget _buildFollowedCreatorsSection() {
    if (_followedCreators.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: ChatrixTheme.surface.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          "Not following any creators yet.",
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _followedCreators.length,
        itemBuilder: (context, index) {
          final creator = _followedCreators[index];
          final String name = creator['username'];
          final String? profileImage = creator['profile_image'];
          final bool hasProfileImage = profileImage != null && profileImage.isNotEmpty;
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(creatorId: creator['uid']),
                ),
              ).then((_) => _loadProfile()); // reload when coming back
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 90,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ChatrixTheme.bioluminescence.withOpacity(0.3), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      backgroundImage: hasProfileImage
                          ? MemoryImage(base64Decode(profileImage.split(',').last))
                          : null,
                      child: hasProfileImage
                          ? null
                          : Text(
                              initial,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Creator",
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: ChatrixTheme.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ChatrixTheme.surface.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 22),
          ],
        ),
      ),
    );
  }

  void _showClearMemoryDialog(BuildContext context) {
    final userId = AuthService().currentUserId;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ChatrixTheme.errorRose.withOpacity(0.3), width: 1.5),
        ),
        title: Text(
          "CLEAR EMOTIONAL MEMORY?",
          style: GoogleFonts.cinzel(
            color: ChatrixTheme.errorRose,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          "This will permanently erase all chat history and memory journals with all companions. This action is absolute and cannot be undone.",
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CANCEL",
              style: GoogleFonts.inter(color: Colors.white60, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ChatrixTheme.errorRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: ChatrixTheme.errorRose),
                ),
              );
              try {
                await MemoryService().clearAllMemory(userId);
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("All memories cleared.", style: GoogleFonts.inter(color: Colors.white)),
                      backgroundColor: ChatrixTheme.errorRose,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error clearing memory: $e", style: GoogleFonts.inter(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(
              "WIPE MEMORIES",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettingsSheet(BuildContext context) async {
    final userId = AuthService().currentUserId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    bool allowAnalytics = prefs.getBool('privacy_allow_analytics') ?? true;
    bool publicSearch = prefs.getBool('privacy_public_search') ?? true;
    bool encryptedLogs = prefs.getBool('privacy_encrypted_logs') ?? false;

    // Load from Firestore if exists
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data()?.containsKey('privacy_settings') == true) {
        final settings = doc.data()?['privacy_settings'] as Map<String, dynamic>;
        allowAnalytics = settings['allow_analytics'] ?? allowAnalytics;
        publicSearch = settings['public_search'] ?? publicSearch;
        encryptedLogs = settings['encrypted_logs'] ?? encryptedLogs;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "PRIVACY SETTINGS",
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your digital emotional security and visibility.",
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildPrivacyToggle(
                    title: "Emotional Analytics & Diagnostics",
                    subtitle: "Allow anonymous logging to improve companion replies.",
                    value: allowAnalytics,
                    icon: Icons.analytics_outlined,
                    onChanged: (val) async {
                      setModalState(() => allowAnalytics = val);
                      await prefs.setBool('privacy_allow_analytics', val);
                      await FirebaseFirestore.instance.collection('users').doc(userId).set({
                        'privacy_settings': {'allow_analytics': val}
                      }, SetOptions(merge: true));
                    },
                  ),
                  
                  _buildPrivacyToggle(
                    title: "Public Search Visibility",
                    subtitle: "Allow custom created companions to be searchable by others.",
                    value: publicSearch,
                    icon: Icons.search_rounded,
                    onChanged: (val) async {
                      setModalState(() => publicSearch = val);
                      await prefs.setBool('privacy_public_search', val);
                      await FirebaseFirestore.instance.collection('users').doc(userId).set({
                        'privacy_settings': {'public_search': val}
                      }, SetOptions(merge: true));
                    },
                  ),
                  
                  _buildPrivacyToggle(
                    title: "Encrypted Message Logs",
                    subtitle: "Apply client-side hashing parameters to chat database.",
                    value: encryptedLogs,
                    icon: Icons.vpn_key_outlined,
                    onChanged: (val) async {
                      setModalState(() => encryptedLogs = val);
                      await prefs.setBool('privacy_encrypted_logs', val);
                      await FirebaseFirestore.instance.collection('users').doc(userId).set({
                        'privacy_settings': {'encrypted_logs': val}
                      }, SetOptions(merge: true));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivacyToggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ChatrixTheme.silverMist, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: ChatrixTheme.champagneGold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Helper to generate a unique referral code for legacy users
  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Widget _buildReferralCard() {
    final inviteLink = 'https://chatrix.space/invite/$_referralCode';
    return Container(
      decoration: BoxDecoration(
        color: ChatrixTheme.surface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ChatrixTheme.bioluminescence.withOpacity(0.15),
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ChatrixTheme.bioluminescence.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChatrixTheme.bioluminescence.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.people_alt_outlined, color: ChatrixTheme.bioluminescence, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SHARE THE SOUL",
                            style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Get Premium by inviting friends",
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Referral Link box
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Invite link copied to clipboard!", style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: ChatrixTheme.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            inviteLink,
                            style: GoogleFonts.inter(
                              color: ChatrixTheme.bioluminescence.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy_rounded, color: ChatrixTheme.bioluminescence.withOpacity(0.8), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Simple rule / progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Invite 1 friend = 7 days Premium",
                      style: GoogleFonts.inter(
                        color: _referralCount >= 1 ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: _referralCount >= 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (_referralCount >= 1)
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Invite 3 friends = 30 bonus days",
                      style: GoogleFonts.inter(
                        color: _referralCount >= 3 ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: _referralCount >= 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (_referralCount >= 3)
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                  ],
                ),
                const SizedBox(height: 16),
                // Referral stats
                Row(
                  children: [
                    Text(
                      "Friends Verified: ",
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "$_referralCount",
                      style: GoogleFonts.inter(
                        color: ChatrixTheme.bioluminescence,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
