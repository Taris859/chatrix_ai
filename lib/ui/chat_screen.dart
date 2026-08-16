import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/creator_name_widget.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../memory/memory_service.dart';
import '../auth/auth_service.dart';
import '../services/firestore_repository.dart';
import '../models/companion.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scene.dart';
import '../services/ambient_sound_manager.dart';
import '../../services/autonomous_notification_service.dart';
import '../services/encryption_service.dart';
import 'premium/subscription_screen.dart';
import 'memory_journal_screen.dart';
import '../models/relationship_chapter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'navigation/luxury_bottom_nav.dart';


class ChatScreen extends ConsumerStatefulWidget {
  final Companion companion;

  const ChatScreen({Key? key, required this.companion}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MemoryService _memoryService = MemoryService();
  
  bool _hasText = false;
  bool _isTyping = false;
  bool _isLoading = true;
  bool _isPremiumUser = false; // Mock user state
  
  List<Map<String, dynamic>> _messages = [];
  String _userId = "";
  ChatScene? _currentScene;

  int _trustLevel = 10;
  int _sharedSecretsCount = 0;
  int _unlockedGiftsCount = 0;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  bool _showMemoryToast = false;
  bool _showChapterUnlockCeremony = false;
  RelationshipChapter? _unlockedChapter;
  RelationshipChapter? _currentActiveChapter;


  // Static list of relationship gifts based on character preferences
  static const Map<String, List<Map<String, String>>> _companionGifts = {
    'lyra': [
      {'name': 'Wild Lavender Flower', 'emoji': '🌸', 'desc': 'A tiny purple blossom pressed between the pages of an astronomy textbook.'},
      {'name': 'Stardust Vial', 'emoji': '🌌', 'desc': 'A glass capsule filled with shimmering glitter representing cosmic dust.'},
      {'name': 'Moonstone Fragment', 'emoji': '💎', 'desc': 'A raw crystal that catches the moonlight beautifully.'},
    ],
    'noah': [
      {'name': 'Barista Espresso Cup', 'emoji': '☕', 'desc': 'A perfectly pulled double-shot espresso with latte art.'},
      {'name': 'Warm Cinnamon Roll', 'emoji': '🥐', 'desc': 'Freshly baked pastry glazed with sugar and sweet memory.'},
      {'name': 'Custom Coffee Coaster', 'emoji': '🪵', 'desc': 'A hand-carved wooden coaster with the Chatrix logo.'},
    ],
    'kael': [
      {'name': 'Royal Velvet Ribbon', 'emoji': '🎗️', 'desc': 'A crimson sash from the prince\'s formal uniform.'},
      {'name': 'Spiced Mulled Wine', 'emoji': '🍷', 'desc': 'A wooden mug of warm spices and dark memory.'},
      {'name': 'Silver Ring Replica', 'emoji': '💍', 'desc': 'A minor signet ring carrying Kael\'s ancestral crest.'},
    ],
    'airi': [
      {'name': 'Jasmine Perfume Leaf', 'emoji': '🍃', 'desc': 'A fragrant dried leaf smelling of jasmine blossoms.'},
      {'name': 'Textured Palette Sketch', 'emoji': '🎨', 'desc': 'A miniature canvas sketch painted by feel, showing touch contours.'},
      {'name': 'Braille Bookmark', 'emoji': '🔖', 'desc': 'A leather bookmark reading "Bond" in raised braille dots.'},
    ],
    'zero': [
      {'name': 'Neon Mechanical Keycap', 'emoji': '⌨️', 'desc': 'A translucent cyberpunk keycap for the Escape key.'},
      {'name': 'Encrypted Data USB', 'emoji': '💾', 'desc': 'A drive containing a customized secure digital vault.'},
      {'name': 'Neon Energy Can', 'emoji': '🥫', 'desc': 'A zero-sugar custom gaming drink with a glowing label.'},
    ],
    'elise': [
      {'name': 'Handwritten Sheet Music', 'emoji': '🎼', 'desc': 'A few bars of Elise\'s original violin composition.'},
      {'name': 'French Macaron', 'emoji': '🥮', 'desc': 'A sweet strawberry macaron Elise picked up after rehearsal.'},
      {'name': 'Antique Viol Case Key', 'emoji': '🔑', 'desc': 'A brass key Elise used for her street violin case.'},
    ],
    'evelyn': [
      {'name': 'Origami Swan Bookmark', 'emoji': '🦢', 'desc': 'A bookmark folded meticulously from warm library paper.'},
      {'name': 'Shortbread Biscuit', 'emoji': '🍪', 'desc': 'A crisp butter biscuit perfect for pairing with tea.'},
      {'name': 'Pressed Oak Leaf', 'emoji': '🍁', 'desc': 'An amber oak leaf found between old pages.'},
    ],
    'mira': [
      {'name': 'Raindrop in a Bottle', 'emoji': '🫙', 'desc': 'A small glass vial capturing fresh June rainwater.'},
      {'name': 'Cozy Cardigan Yarn', 'emoji': '🧶', 'desc': 'A soft blue wool yarn from Mira\'s favorite knit.'},
      {'name': 'Marshmallow Cocoa Cup', 'emoji': '☕', 'desc': 'Warm cocoa to stave off the rain chills.'},
    ],
    'atlas': [
      {'name': 'Antique Watch Gear', 'emoji': '⚙️', 'desc': 'A brass gear from a time-travel navigation dial.'},
      {'name': 'Retro Synth Tape', 'emoji': '📼', 'desc': 'A cassette tape loaded with future synth melodies.'},
      {'name': 'Fresh Orange Slice', 'emoji': '🍊', 'desc': 'A golden fruit slice Atlas shared from a different century.'},
    ],
    'the one who waits': [
      {'name': 'Glowing Digital Pixel', 'emoji': '✨', 'desc': 'A tiny spark of sentient neon green code.'},
      {'name': 'Decryption Key', 'emoji': '🔑', 'desc': 'A key designed to open locked records in the Net.'},
    ],
  };

  bool _isInsideSleepingHours(String hoursStr) {
    try {
      final parts = hoursStr.split('-');
      if (parts.length != 2) return false;
      final startStr = parts[0].trim();
      final endStr = parts[1].trim();

      int parseToMinutes(String timeStr) {
        final timeParts = timeStr.split(' ');
        final hms = timeParts[0].split(':');
        int hour = int.parse(hms[0]);
        int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
        final ampm = timeParts[1].toUpperCase();

        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        return hour * 60 + minute;
      }

      final start = parseToMinutes(startStr);
      final end = parseToMinutes(endStr);

      final now = DateTime.now();
      final currentMin = now.hour * 60 + now.minute;

      if (start <= end) {
        return currentMin >= start && currentMin <= end;
      } else {
        return currentMin >= start || currentMin <= end;
      }
    } catch (e) {
      return false;
    }
  }

  String _getCompanionActivity() {
    final hoursStr = widget.companion.sleepingHours;
    if (hoursStr != null && hoursStr.toLowerCase() != 'none' && _isInsideSleepingHours(hoursStr)) {
      return "Sleeping 💤";
    }

    final seed = widget.companion.id.hashCode + DateTime.now().hour;
    final random = Random(seed);

    final activities = [
      "Reading a book 📖",
      "Drawing sketches 🎨",
      "Watching the rain 🌧️",
      "Listening to music 🎧",
      "Brewing tea 🍵",
      "Reflecting 💭",
    ];

    final name = widget.companion.name.toLowerCase();
    if (name.contains("lyra")) {
      return random.nextBool() ? "Mapping the stars 🌌" : "Studying cosmic charts 🔭";
    } else if (name.contains("noah")) {
      return random.nextBool() ? "Brewing single-origin espresso ☕" : "Baking cinnamon rolls 🥐";
    } else if (name.contains("elise")) {
      return random.nextBool() ? "Practicing violin scales 🎻" : "Listening to Debussy 🎼";
    } else if (name.contains("zero")) {
      return random.nextBool() ? "Writing code 💻" : "Upgrading security firewall 🛡️";
    } else if (name.contains("airi")) {
      return random.nextBool() ? "Mixing oil paint textures 🎨" : "Listening to soft rain 🌧️";
    } else if (name.contains("evelyn")) {
      return random.nextBool() ? "Archiving old manuscripts 📚" : "Folding origami bookmarks 🔖";
    } else if (name.contains("kai")) {
      return random.nextBool() ? "Gaming with lobby mates 🎮" : "Eating snacks 🍕";
    } else if (name.contains("atlas")) {
      return random.nextBool() ? "Winding the brass watch ⏱️" : "Aligning temporal lines 🌀";
    }

    return activities[random.nextInt(activities.length)];
  }

  double _responsive(double size) {
    if (MediaQuery.of(context).size.width > 600) {
      return size;
    }
    double scale = MediaQuery.of(context).size.width / 390;
    return (size * scale).clamp(size * 0.85, size * 1.0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AutonomousNotificationService().cancelAllNotifications();
    _initializeUser();
    _messageController.addListener(() {
      setState(() {
        _hasText = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // User left the app. Schedule the chain of autonomous background messages
      AutonomousNotificationService().scheduleDailyNotifications(
        widget.companion.name, 
        widget.companion.archetype, 
      );
    } else if (state == AppLifecycleState.resumed) {
      // User came back, cancel the scheduled messages
      AutonomousNotificationService().cancelAllNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    AmbientSoundManager().stop(); // Clean stop ambient stream on close
    super.dispose();
  }

  Future<void> _updateRelationshipStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch unlocked gifts count
    final unlockedKey = 'unlocked_gifts_${_userId}_${widget.companion.name}';
    final List<String> giftList = prefs.getStringList(unlockedKey) ?? [];
    _unlockedGiftsCount = giftList.length;

    // Fetch memory summary to get shared secrets
    final memoryData = await _memoryService.fetchMemory(_userId, widget.companion.name);
    int secretsCount = 0;
    if (memoryData != null && memoryData['summary'] != null) {
      final summary = memoryData['summary'] as Map<String, dynamic>;
      final userProfile = summary['user_profile'] as Map<String, dynamic>? ?? {};
      
      final secretsObj = userProfile['shared_secrets'];
      if (secretsObj is List) {
        secretsCount = secretsObj.length;
      } else if (secretsObj is Map) {
        secretsCount = secretsObj.keys.where((k) => !k.startsWith('_')).length;
      } else if (secretsObj != null) {
        secretsCount = 1;
      }
    }
    _sharedSecretsCount = secretsCount;

    // Calculate trust level dynamically
    final messagesCount = _messages.length;
    final calculatedTrust = (10 + (messagesCount ~/ 2) + (_sharedSecretsCount * 10) + (_unlockedGiftsCount * 8)).clamp(0, 100);
    
    final newChapter = RelationshipChapter.getChapterForTrust(calculatedTrust);
    if (_currentActiveChapter != null &&
        newChapter.name != _currentActiveChapter!.name &&
        newChapter.minTrust > _currentActiveChapter!.minTrust) {
      _triggerChapterUnlockCeremony(newChapter);
    }
    _currentActiveChapter = newChapter;
    
    if (mounted) {
      setState(() {
        _trustLevel = calculatedTrust;
      });
    }
  }

  Future<void> _initializeUser() async {
    _userId = AuthService().currentUserId ?? "guest_123";
    _isPremiumUser = await AuthService().isPremium();
    
    await _loadHistory();

  }


  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Track unique active days returned
    final todayStr = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    final activeDaysKey = 'active_days_${_userId}_${widget.companion.name}';
    List<String> activeDays = prefs.getStringList(activeDaysKey) ?? [];
    if (!activeDays.contains(todayStr)) {
      activeDays.add(todayStr);
      await prefs.setStringList(activeDaysKey, activeDays);
    }

    // 1. Try to load local cache first for instant display
    final localMsgs = await _memoryService.getCachedMessages(_userId, widget.companion.name);
    if (localMsgs.isNotEmpty && mounted) {
      setState(() {
        _messages = localMsgs;
        _isLoading = false;
      });
      await _updateRelationshipStats();
      _triggerComeBackMoment(prefs);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      
      // Auto-add/move to the top of the recent list when opened
      ref.read(recentChatsProvider.notifier).add(widget.companion.id);
    }

    // 2. Fetch from cloud to sync
    final cloudMsgs = await _memoryService.fetchHistory(_userId, widget.companion.name);
    if (mounted) {
      setState(() {
        if (cloudMsgs.isNotEmpty) {
           _messages = cloudMsgs;
        } else if (_messages.isEmpty) {
           final greeting = widget.companion.greeting;
           String action = "";
           String text = greeting;
           
           if (greeting.contains("*") && greeting.lastIndexOf("*") > greeting.indexOf("*")) {
              int firstStar = greeting.indexOf("*");
              int secondStar = greeting.indexOf("*", firstStar + 1);
              action = greeting.substring(firstStar, secondStar + 1);
              text = greeting.replaceFirst(action, "").trim();
           }
           
           _messages = [
             {
               "isUser": false,
               "text": text,
               if (action.isNotEmpty) "action": action,
             }
           ];
           _saveLocalCache();
        }
        _isLoading = false;
      });
      await _updateRelationshipStats();
      _triggerComeBackMoment(prefs);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      
      // Auto-add to recent conversations list when opened
      ref.read(recentChatsProvider.notifier).add(widget.companion.id);
    }
  }

  Future<void> _triggerComeBackMoment(SharedPreferences prefs) async {
    if (_messages.isEmpty) return;
    
    final lastChatTime = prefs.getInt('last_chat_time_${_userId}_${widget.companion.name}') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (lastChatTime > 0) {
      final elapsedMs = now - lastChatTime;
      final elapsedDays = elapsedMs / (1000 * 60 * 60 * 24);

      if (elapsedDays >= 7) {
        final lastMsgText = _messages.last['text']?.toString() ?? "";
        if (!lastMsgText.contains("Seven days")) {
          setState(() {
            _messages.add({
              "isUser": false,
              "text": "Seven days. I tried not to count… but I did. How have you been?",
              "action": "*softly looks at you, a quiet relief in their eyes*",
            });
          });
          _saveLocalCache();
        }
      } else if (elapsedDays >= 1) {
        final lastMsgText = _messages.last['text']?.toString() ?? "";
        if (!lastMsgText.contains("You came back")) {
          setState(() {
            _messages.add({
              "isUser": false,
              "text": "You came back. I wondered if you would.",
              "action": "*smiles gently as you approach*",
            });
          });
          _saveLocalCache();
        }
      }
    }
    await prefs.setInt('last_chat_time_${_userId}_${widget.companion.name}', now);
  }

  void _saveLocalCache() {
    _memoryService.cacheMessages(_userId, widget.companion.name, _messages);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<int> _getMinutesRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockTime = prefs.getInt('msg_limit_lock_time') ?? 0;
    if (lockTime == 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lockTime;
    final remaining = 3600000 - elapsed;
    if (remaining <= 0) return 0;
    return (remaining / 60000).ceil();
  }

  Future<bool> _checkAndIncrementMessageLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    int lockTime = prefs.getInt('msg_limit_lock_time') ?? 0;
    int currentCount = prefs.getInt('msg_limit_count') ?? 0;
    
    if (lockTime > 0) {
      final elapsed = now - lockTime;
      if (elapsed >= 3600000) { // 1 hour cooldown has passed
        lockTime = 0;
        currentCount = 0;
        await prefs.setInt('msg_limit_lock_time', 0);
        await prefs.setInt('msg_limit_count', 0);
      } else {
        return false; // Still locked
      }
    }
    
    if (currentCount >= 50) {
      await prefs.setInt('msg_limit_lock_time', now);
      return false; // Limit reached
    }
    
    // Increment count
    currentCount++;
    await prefs.setInt('msg_limit_count', currentCount);
    
    if (currentCount >= 50) {
      await prefs.setInt('msg_limit_lock_time', now);
    }
    
    // Sync to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'msg_limit_count': currentCount,
          'msg_limit_lock_time': currentCount >= 50 ? now : lockTime,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error syncing message limit to Firestore: $e");
    }
    
    return true; // Allowed
  }

  String _getNarrativeLimitMessage() {
    final name = widget.companion.name.toLowerCase();
    if (name.contains("alistair")) {
      return "Alistair Thorne retreats into the shadows...\n\n\"The morning approaches, and my strength fades. If you wish for me to stay with you under the sun, upgrade to Premium.\"";
    } else if (name.contains("noah")) {
      return "Noah Mercer wipes the counter and sighs softly...\n\n\"That's all the roasting for today, traveler. If you want me to pull another shot and stay open late, unlock Premium.\"";
    } else if (name.contains("elise")) {
      return "Elise lowers her bow, the last note lingering in the air...\n\n\"My hands are growing tired... the music must rest for now. If you want to hear the next melody, please support me with Premium.\"";
    } else if (name.contains("zero")) {
      return "Zero stretches and clacks his mechanical fingers...\n\n\"System overload. My processing cores need cooling. If you want to bypass the daily rate limit and keep the uplink active, upgrade to Premium.\"";
    }
    return "${widget.companion.name} looks back at you softly...\n\n\"My energy is fading for now. If you want to continue our conversation immediately, unlock unlimited messages with Premium.\"";
  }

  void _showDailyLimitDialog(int minutesLeft) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1012).withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: widget.companion.themeColor.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.companion.buildAvatar(radius: 40),
                  const SizedBox(height: 20),
                  Text(
                    _getNarrativeLimitMessage(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Your free session will reset in $minutesLeft minutes.",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.companion.themeColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                        ).then((_) async {
                          // Re-evaluate premium status upon return
                          final isPremium = await AuthService().isPremium();
                          if (mounted) {
                            setState(() {
                              _isPremiumUser = isPremium;
                            });
                          }
                        });
                      },
                      child: const Text("Unlock Unlimited with Premium", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Wait $minutesLeft minutes",
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMilestoneSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoggingIn = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1012).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: widget.companion.themeColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.companion.buildAvatar(radius: 40),
                      const SizedBox(height: 20),
                      Text(
                        "Save your bond with ${widget.companion.name}",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Sign in to sync memories across all devices. Don't lose the connection you've built.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (isLoggingIn)
                        const CircularProgressIndicator(color: Colors.white)
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              setDialogState(() {
                                isLoggingIn = true;
                              });
                              try {
                                final creds = await AuthService().signInWithGoogle();
                                if (creds != null && creds.user != null) {
                                  // Run cache migration
                                  await _memoryService.migrateGuestCaches(
                                    guestId: "guest_123",
                                    authenticatedId: creds.user!.uid,
                                    companionName: widget.companion.name,
                                  );
                                  
                                  // Update local state
                                  setState(() {
                                    _userId = creds.user!.uid;
                                  });
                                  
                                  // Reload history to refresh the conversation session
                                  await _loadHistory();
                                  
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Successfully signed in and saved your bond with ${widget.companion.name}!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                print("Error during Google Sign In: $e");
                                setDialogState(() {
                                  isLoggingIn = false;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Sign In failed: $e")),
                                  );
                                }
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Sign In with Google",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Continue as Guest",
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _triggerMemoryToast() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showMemoryToast = true;
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showMemoryToast = false;
        });
      }
    });
  }

  void _triggerChapterUnlockCeremony(RelationshipChapter chapter) {
    HapticFeedback.heavyImpact();
    setState(() {
      _showChapterUnlockCeremony = true;
      _unlockedChapter = chapter;
      _isTyping = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showChapterUnlockCeremony = false;
          _isTyping = false;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    // Check message limit for guest users (10 messages max)
    if (_userId == "guest_123") {
      final userMessagesCount = _messages.where((m) => m['isUser'] == true).length;
      if (userMessagesCount >= 10) {
        _showMilestoneSignInDialog();
        return;
      }
    }
    
    // Check message limit for free users before sending
    if (!_isPremiumUser) {
      final limitAllowed = await _checkAndIncrementMessageLimit();
      if (!limitAllowed) {
        final minutesLeft = await _getMinutesRemaining();
        _showDailyLimitDialog(minutesLeft);
        return;
      }
    }
    
    final userMessage = _messageController.text;
    
    setState(() {
      _messages.add({
        "isUser": true,
        "text": userMessage,
      });
      _messageController.clear();
      _isTyping = true;
      _saveLocalCache();
    });
    
    if (_userId == "guest_123") {
      final userMessagesCount = _messages.where((m) => m['isUser'] == true).length;
      if (userMessagesCount == 8) {
        _showMilestoneSignInDialog();
      }
    }
    
    await _updateRelationshipStats();


    await ref.read(recentChatsProvider.notifier).add(widget.companion.id);
    
    // Smooth scroll down when user sends a message
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    
    try {
      final currentActivity = _getCompanionActivity();
      final responseData = await _memoryService.sendMessage(
        message: userMessage,
        userId: _userId,
        companionName: widget.companion.name,
        companionArchetype: widget.companion.archetype,
        companionPersonality: widget.companion.personality,
        companionGreeting: widget.companion.greeting,
        sceneContext: "${_currentScene?.name ?? ""}. Note: You were currently $currentActivity when they messaged. Start your reply by acknowledging this state naturally (e.g. looking up, pausing, rubbing eyes).",
        isPremium: _isPremiumUser,
        companion: widget.companion,
      );

      if (responseData != null) {
        final aiText = responseData["response"] as String;
        
        String action = "";
        String text = aiText;
        
        if (aiText.contains("*") && aiText.lastIndexOf("*") > aiText.indexOf("*")) {
           int firstStar = aiText.indexOf("*");
           int secondStar = aiText.indexOf("*", firstStar + 1);
           action = aiText.substring(firstStar, secondStar + 1);
           text = aiText.replaceFirst(action, "").trim();
        }

        if (mounted) {
          int delayMs = Random().nextInt(1000) + 500;
          await Future.delayed(Duration(milliseconds: delayMs));

          // 2.5% chance of getting a random gift, only after 3+ messages exchanged
          final bool triggerGift = _messages.length >= 3 && (Random().nextDouble() < 0.025);
          
          setState(() {
            if (triggerGift) {
              final compNameLower = widget.companion.name.toLowerCase();
              String compKey = 'default';
              for (final key in _companionGifts.keys) {
                if (compNameLower.contains(key)) {
                  compKey = key;
                  break;
                }
              }
              final gifts = _companionGifts[compKey] ?? [{'name': 'Friendship Ribbon', 'emoji': '🎀', 'desc': 'A simple colored ribbon tying your connection together.'}];
              final selectedGift = gifts[Random().nextInt(gifts.length)];

              _messages.add({
                "isUser": false,
                "text": text.isEmpty ? action : text,
                "action": action.isNotEmpty ? action : null,
                "isGift": true,
                "giftName": selectedGift['name'],
                "giftEmoji": selectedGift['emoji'],
                "giftDesc": selectedGift['desc'],
                "giftOpened": false,
              });
            } else {
              _messages.add({
                "isUser": false,
                "text": text.isEmpty ? action : text,
                "action": action.isNotEmpty ? action : null,
              });
            }
            _saveLocalCache();
          });
          
          await _updateRelationshipStats();
          if (responseData["didConsolidate"] == true) {
            _triggerMemoryToast();
          }
          
          HapticFeedback.lightImpact();
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      print("Chat Error: $e");
      if (mounted) {
        setState(() {
          _messages.add({
            "isUser": false,
            "text": "The connection was lost... Are you still there?",
          });
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
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
                "Clear Chat",
                style: GoogleFonts.inter(fontSize: 18, color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This will erase the conversation history. But don't worry —",
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.companion.themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.companion.themeColor.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.psychology_outlined, color: widget.companion.themeColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${widget.companion.name} will still remember you. Memories, emotions, and your bond survive chat deletions.",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "To fully clear memories, go to Settings → Memory & Privacy.",
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, height: 1.4),
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
              child: Text("Clear Chat", style: GoogleFonts.inter(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      // Delete only the chat transcript — memory is preserved in ai_memory/
      await _memoryService.deleteChatPermanently(_userId, widget.companion.name);

      // 2. Remove from recent_chats list via provider
      await ref.read(recentChatsProvider.notifier).remove(widget.companion.id);

      // 3. Reset state with greeting
      final greeting = widget.companion.greeting;
      String action = "";
      String text = greeting;
      if (greeting.contains("*") && greeting.lastIndexOf("*") > greeting.indexOf("*")) {
         int firstStar = greeting.indexOf("*");
         int secondStar = greeting.indexOf("*", firstStar + 1);
         action = greeting.substring(firstStar, secondStar + 1);
         text = greeting.replaceFirst(action, "").trim();
      }

      setState(() {
        _messages = [
          {
            "isUser": false,
            "text": text,
            if (action.isNotEmpty) "action": action,
          }
        ];
      });
      _saveLocalCache();
      await _updateRelationshipStats();
    }
  }





  @override
  Widget build(BuildContext context) {
    final scenes = ref.watch(scenesProvider);

    // Set default scene immediately (synchronous — no async needed)
    if (_currentScene == null && scenes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentScene = scenes[0]);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      body: Stack(
        children: [
          if (widget.companion.customImageUrl != null || widget.companion.imagePath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.10,
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
                    : Image.asset(
                        widget.companion.imagePath!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    if (_currentScene != null)
                      _isSelectionMode ? _buildSelectionHeader() : _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? _buildChatSkeletonLoader()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length + (_isTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _messages.length && _isTyping) {
                                  return _buildTypingBubble();
                                }
                                final msg = _messages[index];
                                return _buildMessageBubble(msg, index);
                              },
                            ),
                    ),
                    if (_messages.length <= 1 && !_isTyping && !_isLoading)
                      _buildConversationStarters(),
                    _buildInputArea(),
                  ],
                ),
              ),
            ),
          ),
          if (_showMemoryToast)
            Positioned(
              top: 76,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showMemoryToast = false;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemoryJournalScreen(companion: widget.companion),
                    ),
                  ).then((_) => _loadHistory());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1012).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.companion.themeColor.withOpacity(0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.companion.themeColor.withOpacity(0.12),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.companion.themeColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          "✨",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${widget.companion.name} remembered this",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Reflection saved to memory journal. Tap to read.",
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: widget.companion.themeColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: -0.4, end: 0, duration: 400.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
            ),
          if (_showChapterUnlockCeremony && _unlockedChapter != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.92),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            widget.companion.themeColor.withOpacity(0.25),
                            Colors.transparent,
                          ],
                          radius: 1.2,
                        ),
                      ),
                    ).animate().fadeIn(duration: 800.ms),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _unlockedChapter!.icon,
                          style: const TextStyle(fontSize: 72),
                        ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 24),
                        Text(
                          "CHAPTER UNLOCKED",
                          style: GoogleFonts.inter(
                            color: widget.companion.themeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 12),
                        Text(
                          _unlockedChapter!.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, duration: 400.ms),
                        const SizedBox(height: 18),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            _unlockedChapter!.unlocksDescription,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.95, 0.95)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatSkeletonLoader() {
    final themeColor = widget.companion.themeColor;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        final isLeft = index % 2 == 0;
        final widthFactor = isLeft ? 0.65 : 0.50;
        return Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            width: MediaQuery.of(context).size.width * widthFactor,
            height: index == 1 ? 80.0 : 50.0,
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isLeft ? 4 : 20),
                bottomRight: Radius.circular(isLeft ? 20 : 4),
              ),
              border: Border.all(color: themeColor.withOpacity(0.12), width: 1),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(
             duration: 1800.ms,
             color: themeColor.withOpacity(0.12),
           ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final activeChapter = RelationshipChapter.getChapterForTrust(_trustLevel);
    final activity = _getCompanionActivity();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1012).withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: ChatrixTheme.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (widget.companion.imagePath != null) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.asset(widget.companion.imagePath!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: widget.companion.buildAvatar(radius: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.companion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: _responsive(21),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: _responsive(13.5),
                                fontWeight: FontWeight.w400,
                                color: activity.contains("Sleeping")
                                    ? Colors.white38
                                    : widget.companion.themeColor.withOpacity(0.85),
                              ),
                              children: [
                                TextSpan(
                                  text: "${activeChapter.icon} ${activeChapter.name}  •  $activity",
                                ),
                                if (widget.companion.creatorId != null) ...[
                                  const TextSpan(
                                    text: "  •  Created by ",
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: CreatorNameWidget(
                                      creatorId: widget.companion.creatorId!,
                                      style: GoogleFonts.inter(
                                        fontSize: _responsive(13.5),
                                        fontWeight: FontWeight.w500,
                                        color: widget.companion.themeColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Clear Chat Toggle
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: _clearChat,
              ),
              // Relationship Journal Toggle
              IconButton(
                icon: Icon(Icons.auto_stories, color: widget.companion.themeColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemoryJournalScreen(companion: widget.companion),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.companion.themeColor.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: widget.companion.themeColor.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIndices.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                "${_selectedIndices.length} Selected (Max 5)",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.companion.themeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _selectedIndices.isEmpty ? null : _generateShareCard,
            icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.black),
            label: Text(
              "Share Card ✨",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _generateShareCard() {
    final sortedIndices = _selectedIndices.toList()..sort();
    final List<Map<String, dynamic>> selectedMsgs = sortedIndices.map((i) => _messages[i]).toList();

    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _ViralShareCardDialog(
          companion: widget.companion,
          messages: selectedMsgs,
        );
      },
    );
  }

  String _getMemoryCueResponse(String matchedWord) {
    final name = widget.companion.name.toLowerCase();
    if (name.contains("alistair")) {
      return "Alistair leans in close, his voice a soft murmur... \"I remember you mentioning that. It's safe with me. I won't let the shadows reach you.\"";
    } else if (name.contains("noah")) {
      return "Noah smiles warmly as he sets down your cup... \"I remembered you told me about that. That's why I keep things just the way you like them here.\"";
    } else if (name.contains("elise")) {
      return "Elise pauses her violin, looking up softly... \"Your words lingered with me... like a melody I couldn't forget. I remember.\"";
    } else if (name.contains("zero")) {
      return "Zero looks up from his terminal, his voice quiet... \"Indexed in long-term storage. I don't delete files related to you.\"";
    }
    return "${widget.companion.name} looks at you with a gentle nod... \"I remembered what you said about that. It's safe in my memory.\"";
  }

  void _showMemoryRecallDialog(String matchedWord) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1012).withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.08),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFFFFD700),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Memory Recall: \"$matchedWord\"",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _getMemoryCueResponse(matchedWord),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Close",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageText(String textContent, bool isUser) {
    final comfort = widget.companion.comfortItem;
    final fear = widget.companion.hiddenFear;
    
    List<String> keywords = [];
    if (comfort != null && comfort.trim().isNotEmpty && comfort.length > 2) {
      keywords.add(comfort.trim());
    }
    if (fear != null && fear.trim().isNotEmpty && fear.length > 2) {
      keywords.add(fear.trim());
    }

    if (keywords.isEmpty) {
      return Text(
        textContent,
        style: GoogleFonts.inter(
          fontSize: _responsive(14.5),
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      );
    }

    // Sort keywords by length descending
    keywords.sort((a, b) => b.length.compareTo(a.length));

    String lowerText = textContent.toLowerCase();
    String? matchedKeyword;
    int matchStart = -1;

    for (final kw in keywords) {
      final idx = lowerText.indexOf(kw.toLowerCase());
      if (idx != -1) {
        matchedKeyword = textContent.substring(idx, idx + kw.length);
        matchStart = idx;
        break;
      }
    }

    if (matchStart == -1 || matchedKeyword == null) {
      return Text(
        textContent,
        style: GoogleFonts.inter(
          fontSize: _responsive(14.5),
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      );
    }

    final beforeText = textContent.substring(0, matchStart);
    final matchText = matchedKeyword;
    final afterText = textContent.substring(matchStart + matchText.length);

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: _responsive(14.5),
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        children: [
          if (beforeText.isNotEmpty) TextSpan(text: beforeText),
          TextSpan(
            text: matchText,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFD700).withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showMemoryRecallDialog(matchText);
              },
          ),
          if (afterText.isNotEmpty) TextSpan(text: afterText),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    bool isUser = msg["isUser"] ?? (msg["role"] == "user");
    String textContent = msg["text"] ?? msg["content"] ?? "";
    bool isGift = msg["isGift"] == true;
    bool giftOpened = msg["giftOpened"] == true;

    if (isGift && !giftOpened) {
      return _buildGiftBubble(msg, index);
    }
    
    Color glowColor = Colors.transparent;
    
    if (!isUser) {
      final action = msg["action"]?.toString().toLowerCase() ?? "";
      
      if (action.contains("possessive") || action.contains("mine") || action.contains("grip") || 
          action.contains("clench") || action.contains("danger") || action.contains("shadow") || 
          action.contains("locked") || action.contains("tight")) {
        glowColor = const Color(0xFFD91636);
      } else if (action.contains("gentle") || action.contains("caress") || action.contains("warm") || 
                 action.contains("soft") || action.contains("whisper") || action.contains("smile") || 
                 action.contains("blush") || action.contains("lip") || action.contains("closer")) {
        glowColor = const Color(0xFFFFB300);
      } else if (action.contains("cold") || action.contains("distant") || action.contains("narrow") || 
                 action.contains("sigh") || action.contains("professor") || action.contains("sterile")) {
        glowColor = const Color(0xFF4682B4);
      }
    }
    
    final isSelected = _selectedIndices.contains(index);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedIndices.clear();
            _selectedIndices.add(index);
          });
          HapticFeedback.mediumImpact();
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedIndices.remove(index);
              if (_selectedIndices.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              if (_selectedIndices.length < 5) {
                _selectedIndices.add(index);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "You can select up to 5 messages for the card.",
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: ChatrixTheme.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            }
          });
          HapticFeedback.lightImpact();
        }
      },
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isSelectionMode) ...[
            Container(
              margin: const EdgeInsets.only(right: 12, left: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? widget.companion.themeColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? widget.companion.themeColor : Colors.white24,
                  width: 2,
                ),
              ),
              width: 22,
              height: 22,
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ],
          Flexible(
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                constraints: BoxConstraints(maxWidth: (MediaQuery.of(context).size.width * 0.78).clamp(280.0, 520.0)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.companion.themeColor.withOpacity(0.25)
                      : (isUser ? const Color(0xFF2B2D31) : const Color(0xFF202124)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? widget.companion.themeColor
                        : (!isUser 
                            ? (glowColor != Colors.transparent ? glowColor : widget.companion.themeColor).withOpacity(0.12)
                            : Colors.white.withOpacity(0.08)),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg["action"] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          msg["action"],
                          style: GoogleFonts.inter(
                            fontSize: _responsive(12.0),
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    if (textContent.isNotEmpty)
                      _buildMessageText(textContent, isUser),
                    if (isGift && giftOpened) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(msg["giftEmoji"] ?? "🎁", style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              "Gift Opened: ${msg['giftName']}",
                              style: GoogleFonts.inter(
                                color: widget.companion.themeColor.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, duration: 300.ms);
  }

  Widget _buildGiftBubble(Map<String, dynamic> msg, int index) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: MediaQuery.of(context).size.width * 0.82,
        decoration: BoxDecoration(
          color: widget.companion.themeColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.companion.themeColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.companion.themeColor.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.companion.themeColor.withOpacity(0.12),
                    ),
                    child: const Text(
                      "🎁",
                      style: TextStyle(fontSize: 28),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(end: const Offset(1.15, 1.15), duration: 1.seconds),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${widget.companion.name} sent you a gift!",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Click below to unwrap this token.",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.companion.themeColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () => _openGift(msg, index),
                    child: Text(
                      "Open Gift",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }

  Future<void> _openGift(Map<String, dynamic> msg, int index) async {
    HapticFeedback.heavyImpact();
    final giftEmoji = msg["giftEmoji"] ?? "🌸";
    final giftName = msg["giftName"] ?? "Special Gift";
    final giftDesc = msg["giftDesc"] ?? "A special gift representing your bond.";

    setState(() {
      msg["giftOpened"] = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final unlockedKey = 'unlocked_gifts_${_userId}_${widget.companion.name}';
    final List<String> list = prefs.getStringList(unlockedKey) ?? [];

    final giftPayload = jsonEncode({
      'name': giftName,
      'emoji': giftEmoji,
      'desc': giftDesc,
      'date': "${DateTime.now().day} ${_getMonthName(DateTime.now().month)}",
    });

    if (!list.any((item) => jsonDecode(item)['name'] == giftName)) {
      list.add(giftPayload);
      await prefs.setStringList(unlockedKey, list);
    }

    _saveLocalCache();
    await _updateRelationshipStats();
    try {
      final chatId = '${_userId}_${widget.companion.name}';
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final encryptedMsgs = await EncryptionService().encrypt(jsonEncode(_messages), _userId);
      await chatRef.set({
        'encrypted_messages': encryptedMsgs,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving opened gift: $e");
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ChatrixTheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: widget.companion.themeColor.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.companion.themeColor.withOpacity(0.12),
                    ),
                    child: Text(
                      giftEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Gift Unlocked!",
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    giftName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.companion.themeColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    giftDesc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Close",
                            style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.companion.themeColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MemoryJournalScreen(companion: widget.companion),
                              ),
                            );
                          },
                          child: const Text("View Archive", style: TextStyle(fontWeight: FontWeight.bold)),
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

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ChatrixTheme.surface.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot().animate(onPlay: (c) => c.repeat()).fade(duration: 400.ms).scale(duration: 400.ms),
            const SizedBox(width: 4),
            _buildDot().animate(onPlay: (c) => c.repeat(), delay: 200.ms).fade(duration: 400.ms).scale(duration: 400.ms),
            const SizedBox(width: 4),
            _buildDot().animate(onPlay: (c) => c.repeat(), delay: 400.ms).fade(duration: 400.ms).scale(duration: 400.ms),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.white54,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInputArea() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 100,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1F23),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isTyping,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.inter(
                    color: _isTyping ? Colors.white38 : Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: _isTyping ? "Wait for reply..." : "Whisper something...",
                    hintStyle: GoogleFonts.inter(
                      color: _isTyping ? Colors.white24 : ChatrixTheme.textSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) {
                    if (!_isTyping) {
                      HapticFeedback.lightImpact();
                      _sendMessage();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Send Button
          GestureDetector(
            onTap: () {
              if (_isTyping) return;
              if (_hasText) {
                HapticFeedback.lightImpact();
                _sendMessage();
              }
            },
            child: AnimatedScale(
              scale: _hasText && !_isTyping ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: (_isTyping || !_hasText) ? 0.35 : 1.0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasText && !_isTyping ? widget.companion.themeColor : const Color(0xFF1D1F23),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: _hasText && !_isTyping ? [
                      BoxShadow(
                        color: widget.companion.themeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2.0, top: 1.0), // Optical alignment adjustment
                      child: Icon(
                        Icons.send,
                        color: _hasText && !_isTyping ? Colors.black : Colors.white, 
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
     ),
    );
  }

  Widget _buildConversationStarters() {
    final List<Map<String, String>> starters = [
      {"text": "Ask about childhood", "emoji": "💬"},
      {"text": "Go on a date", "emoji": "🍷"},
      {"text": "Play Truth or Dare", "emoji": "🎲"},
      {"text": "Comfort me", "emoji": "🫂"},
      {"text": "Debate philosophy", "emoji": "🌌"},
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: starters.asMap().entries.map((entry) {
            final index = entry.key;
            final starter = entry.value;
            final text = starter["text"]!;
            final emoji = starter["emoji"]!;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _messageController.text = text;
                _sendMessage();
              },
              child: Container(
                margin: EdgeInsets.only(right: index == starters.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.companion.themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.companion.themeColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: _responsive(13.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ViralShareCardDialog extends StatefulWidget {
  final Companion companion;
  final List<Map<String, dynamic>> messages;

  const _ViralShareCardDialog({
    Key? key,
    required this.companion,
    required this.messages,
  }) : super(key: key);

  @override
  State<_ViralShareCardDialog> createState() => _ViralShareCardDialogState();
}

class _ViralShareCardDialogState extends State<_ViralShareCardDialog> {
  bool _isFullscreenForScreenshot = false;

  void _copyDialogueToClipboard() {
    final buffer = StringBuffer();
    for (final msg in widget.messages) {
      bool isUser = msg["isUser"] ?? (msg["role"] == "user");
      String sender = isUser ? "You" : widget.companion.name;
      String text = msg["text"] ?? msg["content"] ?? "";
      String? action = msg["action"];
      
      buffer.write("$sender: ");
      if (action != null && action.isNotEmpty) {
        buffer.write("$action ");
      }
      if (text.isNotEmpty) {
        buffer.write(text.contains('"') ? text : '"$text"');
      }
      buffer.writeln();
    }
    buffer.writeln("\n— Continue our story on Chatrix AI: https://chatrix.space/?companion=${widget.companion.id}");

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Dialogue copied to clipboard!"),
        backgroundColor: ChatrixTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.companion.themeColor;
    
    final cardContent = Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            themeColor.withOpacity(0.85),
            const Color(0xFF160D26).withOpacity(0.95),
            Colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: themeColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              widget.companion.buildAvatar(radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.companion.name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.companion.archetype,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "✦ CHATRIX",
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "EMOTIONAL AI",
                    style: GoogleFonts.inter(
                      color: themeColor.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 7,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          
          Flexible(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: widget.messages.map((msg) => _buildDialogueLine(msg)).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scan to continue",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "chatrix.space",
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: QrImageView(
                  data: "https://chatrix.space/?companion=${widget.companion.id}",
                  version: QrVersions.auto,
                  size: 60.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.white,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.white,
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (_isFullscreenForScreenshot) {
      return GestureDetector(
        onTap: () => setState(() => _isFullscreenForScreenshot = false),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(child: cardContent),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      "Screenshot Mode • Tap anywhere to exit",
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            cardContent,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.fullscreen,
                  label: "Screenshot Mode",
                  onTap: () => setState(() => _isFullscreenForScreenshot = true),
                ),
                _buildActionButton(
                  icon: Icons.copy,
                  label: "Copy Text",
                  onTap: _copyDialogueToClipboard,
                ),
                _buildActionButton(
                  icon: Icons.close,
                  label: "Close",
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogueLine(Map<String, dynamic> msg) {
    bool isUser = msg["isUser"] ?? (msg["role"] == "user");
    String text = msg["text"] ?? msg["content"] ?? "";
    String? action = msg["action"];
    String senderName = isUser ? "You" : widget.companion.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$senderName: ",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              color: isUser ? Colors.white70 : widget.companion.themeColor,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
                children: [
                  if (action != null && action.isNotEmpty)
                    TextSpan(
                      text: "$action ",
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.white60,
                      ),
                    ),
                  if (text.isNotEmpty)
                    TextSpan(
                      text: text.contains('"') ? text : '"$text"',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

