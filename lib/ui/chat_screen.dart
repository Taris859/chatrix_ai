import 'package:flutter/material.dart';
import 'dart:convert';
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
import 'premium/subscription_screen.dart';
import 'memory_journal_screen.dart';

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
  
  bool _isRecording = false;
  bool _hasText = false;
  bool _isTyping = false;
  bool _isLoading = true;
  bool _isPremiumUser = false; // Mock user state
  
  List<Map<String, dynamic>> _messages = [];
  String _userId = "";
  ChatScene? _currentScene;

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

  Future<void> _initializeUser() async {
    _userId = AuthService().currentUserId ?? "guest_123";
    _isPremiumUser = await AuthService().isPremium();
    
    await _loadHistory();

  }


  Future<void> _loadHistory() async {
    // 1. Try to load local cache first for instant display
    final localMsgs = await _memoryService.getCachedMessages(_userId, widget.companion.name);
    if (localMsgs.isNotEmpty && mounted) {
      setState(() {
        _messages = localMsgs;
        _isLoading = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }

    // 2. Fetch from cloud to sync
    final cloudMsgs = await _memoryService.fetchHistory(_userId, widget.companion.name);
    if (mounted) {
      setState(() {
        if (cloudMsgs.isNotEmpty) {
           _messages = cloudMsgs;
        } else if (_messages.isEmpty) {
           // Parse companion's cinematic greeting
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
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
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
                color: ChatrixTheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ChatrixTheme.errorRose.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ChatrixTheme.errorRose.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.lock_clock_outlined, color: ChatrixTheme.errorRose, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Session Limit Reached",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "You have reached your limit of 50 messages.\n\nYour session will unlock in $minutesLeft minutes, or you can unlock unlimited messages right now with Premium.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatrixTheme.amethyst,
                        foregroundColor: Colors.white,
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
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


    final prefs = await SharedPreferences.getInstance();
    List<String> recentChats = prefs.getStringList('recent_chats') ?? [];
    if (!recentChats.contains(widget.companion.id)) {
      recentChats.insert(0, widget.companion.id);
    } else {
      recentChats.remove(widget.companion.id);
      recentChats.insert(0, widget.companion.id);
    }
    await prefs.setStringList('recent_chats', recentChats);
    
    // Smooth scroll down when user sends a message
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    
    try {
      final responseData = await _memoryService.sendMessage(
        message: userMessage,
        userId: _userId,
        companionName: widget.companion.name,
        companionArchetype: widget.companion.archetype,
        companionPersonality: widget.companion.personality,
        companionGreeting: widget.companion.greeting,
        sceneContext: _currentScene?.name ?? "",
        isPremium: _isPremiumUser,
      );

      if (responseData != null) {
        final aiText = responseData["response"] as String;
        
        // Basic parser to split cinematic action tags (*action*) from dialogue
        String action = "";
        String text = aiText;
        
        if (aiText.contains("*") && aiText.lastIndexOf("*") > aiText.indexOf("*")) {
           int firstStar = aiText.indexOf("*");
           int secondStar = aiText.indexOf("*", firstStar + 1);
           action = aiText.substring(firstStar, secondStar + 1);
           text = aiText.replaceFirst(action, "").trim();
        }

        if (mounted) {
          // Fast response (0.5s - 1.5s delay to simulate typing but keep it under 4s)
          int delayMs = Random().nextInt(1000) + 500;
          await Future.delayed(Duration(milliseconds: delayMs));

          setState(() {
            _messages.add({
              "isUser": false,
              "text": text.isEmpty ? action : text,
              "action": action.isNotEmpty ? action : null,
            });
            _saveLocalCache();
          });
          
          HapticFeedback.lightImpact(); // Emotional UI Haptics
          // Scroll down when AI replies
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

      // 2. Remove from recent_chats list in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> recentChats = prefs.getStringList('recent_chats') ?? [];
      recentChats.remove(widget.companion.id);
      await prefs.setStringList('recent_chats', recentChats);

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
    }
  }



  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
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
            child: Column(
              children: [
                if (_currentScene != null) _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: ChatrixTheme.bioluminescence))
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
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Active now",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white60,
                          ),
                        ),
                        if (widget.companion.creatorId != null) ...[
                          Text(
                            " • Created by ",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white60,
                            ),
                          ),
                          CreatorNameWidget(
                            creatorId: widget.companion.creatorId!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: widget.companion.themeColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
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



  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    bool isUser = msg["isUser"] ?? (msg["role"] == "user");
    String textContent = msg["text"] ?? msg["content"] ?? "";
    
    // Dynamic emotional UI borders based on the action tags in asterisks
    Color glowColor = Colors.transparent;
    
    if (!isUser) {
      final action = msg["action"]?.toString().toLowerCase() ?? "";
      
      if (action.contains("possessive") || action.contains("mine") || action.contains("grip") || 
          action.contains("clench") || action.contains("danger") || action.contains("shadow") || 
          action.contains("locked") || action.contains("tight")) {
        // Crimson for possessive / tense moments
        glowColor = const Color(0xFFD91636);
      } else if (action.contains("gentle") || action.contains("caress") || action.contains("warm") || 
                 action.contains("soft") || action.contains("whisper") || action.contains("smile") || 
                 action.contains("blush") || action.contains("lip") || action.contains("closer")) {
        // Warm gold/amber for intimate / affectionate moments
        glowColor = const Color(0xFFFFB300);
      } else if (action.contains("cold") || action.contains("distant") || action.contains("narrow") || 
                 action.contains("sigh") || action.contains("professor") || action.contains("sterile")) {
        // Cold blue/steel for distance / analytical tension
        glowColor = const Color(0xFF4682B4);
      }
    }
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser 
              ? const Color(0xFF2B2D31)
              : const Color(0xFF202124),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !isUser 
                ? (glowColor != Colors.transparent ? glowColor : widget.companion.themeColor).withOpacity(0.12)
                : Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg["action"] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  msg["action"],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white60,
                  ),
                ),
              ),
            if (textContent.isNotEmpty)
              Text(
                textContent,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, duration: 300.ms);
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1012),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1D1F23),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isRecording ? widget.companion.themeColor : Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !_isTyping,
                style: GoogleFonts.inter(
                  color: _isTyping ? Colors.white38 : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  hintText: _isTyping ? "Wait for reply..." : (_isRecording ? "Listening..." : "Whisper something..."),
                  hintStyle: GoogleFonts.inter(
                    color: _isTyping ? Colors.white24 : (_isRecording ? widget.companion.themeColor : ChatrixTheme.textSecondary),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) {
                  if (!_isTyping) _sendMessage();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Voice / Send Button
          GestureDetector(
            onTap: () {
              if (_isTyping) return;
              if (_hasText) {
                _sendMessage();
              } else {
                _toggleRecording();
              }
            },
            child: Opacity(
              opacity: _isTyping ? 0.3 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? widget.companion.themeColor : const Color(0xFF1D1F23),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  _hasText 
                    ? Icons.send 
                    : (_isRecording ? Icons.mic : Icons.mic_none),
                  color: Colors.white, 
                  size: 24,
                ),
              ).animate(target: _isRecording ? 1 : 0).scale(end: const Offset(1.1, 1.1)),
            ),
          )
        ],
      ),
    );
  }


}
