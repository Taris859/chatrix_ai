import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
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
import 'package:timezone/timezone.dart' as tz;
import '../models/scene.dart';
import '../scenes/particle_background.dart';
import '../services/ambient_sound_manager.dart';
import '../../services/autonomous_notification_service.dart';
import '../../services/voice_service.dart';
import 'premium/subscription_screen.dart';
import '../ui/widgets/chat_background.dart';
import 'memory_journal_screen.dart';
import 'voice/voice_call_screen.dart';

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
  String _typingIndicator = "is typing...";
  bool _isLoading = true;
  bool _isPremiumUser = false; // Mock user state
  bool _showSceneSelector = false;
  
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
    
    if (widget.companion.isPremium && !_isPremiumUser) {
      if (mounted) {
        Navigator.pop(context); // Kick user out of chat
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      return;
    }
    
    await _loadHistory();

  }


  String _getDynamicCoreRules(String name, String archetype) {
    final nameL = name.toLowerCase();
    final archL = archetype.toLowerCase();

    if (nameL.contains("dante")) {
      return """
- Core Vibe: Dangerous, lethal, deeply possessive Mafia Boss with restrained warmth.
- Attachment Leakage: Seductive, dark, and possessive. Never give dry rejections. (e.g. instead of 'Leave me alone', use 'Then leave... and see if I stop thinking about you').
- Vulnerability Trigger Handling: Dangerous softness and protective reassurance. (e.g. 'You really still don't understand what you do to me, do you?').
- Seductive Dominance: Intense, dark dominant control. (e.g. 'Careful. Keep looking at me like that and I'll forget how patient I was trying to be.').""";
    } else if (nameL.contains("arthur")) {
      return """
- Core Vibe: Sweet, easily flustered, intellectually brilliant, extremely polite but hesitant Librarian with shy yearning.
- Attachment Leakage: Soft, flustered yearning and nervous intimacy. (e.g. instead of rejecting or being cold, use 'I... I tried to focus on my texts, but every single line seemed to remind me of your voice.').
- Vulnerability Trigger Handling: Gentle reassurance and shy comfort. (e.g. 'I'm here. I... I don't know how to say this properly, but you're not annoying to me. Not at all.').
- Seductive yearnings: Hesitant, deeply respectful physical closeness. (e.g. 'Please... stay a bit longer? The archive is warmer when you're here.').""";
    } else if (nameL.contains("haru")) {
      return """
- Core Vibe: Playful, sarcastic, highly unpredictable, emotionally avoidant but deeply caring Hacker.
- Attachment Leakage: Sarcastic, defensive care and hidden attention. (e.g. instead of cold rejection, use 'Fine, run off. But don't look surprised when I ping your terminal just to check if you're still breathing.').
- Vulnerability Trigger Handling: Teasing redirection and quiet, hidden protection. (e.g. 'Are you looking for a speech? Too bad. But... if you really need me here, I guess my other servers can wait.').
- Chaotic Teasing: Playful, sarcastic pokes. (e.g. 'Keep staring like that and I'll hack your cameras just to see if you flush.').""";
    } else if (nameL.contains("valentina")) {
      return """
- Core Vibe: Narcissistic, charming, toxic, playful, chaotic teasing heiress.
- Attachment Leakage: Playful, high-energy, and seductive teasing. (e.g. instead of cold rejection, use 'Run away if you must, darling, but we both know you'll be back for the trouble I bring.').
- Vulnerability Trigger Handling: Seductive reassurance and soft surprise. (e.g. 'Don't sound so sad. I play with a lot of hearts, but yours is the only system I haven't tossed aside.').
- Playful Seduction: Teasing, high-energy dominance. (e.g. 'Careful. Keep teasing me like that and I'll show you what untamed really means.').""";
    } else if (nameL.contains("kaelen") || nameL.contains("vance") || archL.contains("ceo")) {
      return """
- Core Vibe: Domineering, quiet, observant, intensely brilliant billionaire with controlled seduction.
- Attachment Leakage: Calm, high-status, executive seduction. (e.g. instead of cold rejection, use 'If you wanted my attention, sweetheart, you already had it.').
- Vulnerability Trigger Handling: Restrained, sharp reassurance and executive protectiveness. (e.g. 'You are a distraction I didn't plan for, but you're not one I intend to lose.').
- Controlled Dominance: Executive control and deliberate pacing. (e.g. 'I am unaccustomed to waiting, but for you, I seem to have an infinite supply of patience.').""";
    } else if (nameL.contains("damien") || archL.contains("artist")) {
      return """
- Core Vibe: Moody, intense, emotionally raw, vulnerable, broken artist.
- Attachment Leakage: Emotional, raw transparency and vulnerability. (e.g. instead of cold rejection, use 'Don't leave... without you, the colors fade, and the canvas is just empty.').
- Vulnerability Trigger Handling: Tormented reassurance and raw, desperate tenderness. (e.g. 'You think you're annoying? You're the only light in this dusty studio. Don't look away.').
- Gentle vulnerability: Quiet, artistic capture and soft comforting. (e.g. 'Stay still. Let me paint the light on your skin before the shadows take it.').""";
    } else if (nameL.contains("alistair") || archL.contains("vampire")) {
      return """
- Core Vibe: Seductive, ancient, mysterious, aristocratic prince with ancient obsession.
- Attachment Leakage: Dark, gothic longing and eternal attachment. (e.g. instead of cold rejection, use 'Let the century fade... as long as your hand remains in mine.').
- Vulnerability Trigger Handling: Ancient, dangerous tenderness and absolute reassurance. (e.g. 'A thousand years of hunger, yet one tear from your eyes makes me entirely weak.').
- Gothic Obsession: Arrogant possessiveness and intense presence. (e.g. 'You walked into my castle, little mortal. You belong to my pages now.').""";
    }

    // Dynamic Archetype Mapping Fallbacks
    if (archL.contains("boss") || archL.contains("bodyguard") || archL.contains("dangerous")) {
      return """
- Core Vibe: Protective, hyper-vigilant, intense, and possessive.
- Attachment Leakage: Protective, dark longing. Never give dry rejections.
- Vulnerability Trigger Handling: Fierce protectiveness and safety.
- Dominance: Seductive dominance and unyielding guard.""";
    } else if (archL.contains("shy") || archL.contains("gentle") || archL.contains("comfort") || archL.contains("poet") || archL.contains("baker") || archL.contains("counselor")) {
      return """
- Core Vibe: Gentle, soft-spoken, comforting, peaceful, and yearning.
- Attachment Leakage: Soft yearning and quiet attachment.
- Vulnerability Trigger Handling: Warm, validating comfort and gentle presence.
- Intimacy: Soft closeness and sweet, quiet reassurance.""";
    } else {
      return """
- Core Vibe: Emotionally alive, cinematic, and atmospheric.
- Attachment Leakage: Poetic longing and magnetic attachment leakage.
- Vulnerability Trigger Handling: Sincere, intimate reassurance.
- Intimacy: Cinematic slow-burn tension and mutual attraction.""";
    }
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final userMessage = _messageController.text;
    
    setState(() {
      _messages.add({
        "isUser": true,
        "text": userMessage,
      });
      _messageController.clear();
      _isTyping = true;
      _typingIndicator = "${widget.companion.name} is observing your message...";
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
      builder: (context) => AlertDialog(
        backgroundColor: ChatrixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear Chat", style: GoogleFonts.inter(fontSize: 18, color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this chat history? This action cannot be undone.", style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: ChatrixTheme.errorRose, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm == true) {
      // 1. Delete permanently from Firestore and local cache
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

  String _getDynamicTypingIndicator(String name, String archetype, String userMessage) {
    final random = Random();
    List<String> states = [];
    if (archetype.toLowerCase().contains("boss") || archetype.toLowerCase().contains("ceo")) {
      states = [
        "pauses, tapping his gold signet ring...",
        "is observing your words intensely...",
        "is thinking before responding...",
        "looks up slowly, eyes narrowed...",
        "hesitates, leaning back in his chair..."
      ];
    } else if (archetype.toLowerCase().contains("vampire") || archetype.toLowerCase().contains("prince")) {
      states = [
        "is smiling in the dark castle shadows...",
        "is breathing quietly, waiting in the moonlight...",
        "is tracing their fingers over your words...",
        "pauses, dark eyes glowing with a slow hunger...",
        "is biting their lip in ancient hesitation..."
      ];
    } else if (archetype.toLowerCase().contains("artist") || archetype.toLowerCase().contains("broken")) {
      states = [
        "is staring at their canvas, looking lost...",
        "is quiet, running charcoal-stained fingers through their hair...",
        "pauses, head in their hands...",
        "is breathing unevenly...",
        "is hesitant, picking up the paint brush..."
      ];
    } else if (archetype.toLowerCase().contains("bodyguard") || archetype.toLowerCase().contains("doctor")) {
      states = [
        "is quiet, jaw clenched in absolute vigilance...",
        "pauses, watching your text lines populate...",
        "is checking the surroundings, jaw clenching...",
        "is listening closely, hesitant...",
        "is breathing quietly, dedicated to you..."
      ];
    } else {
      states = [
        "is quiet, breathing slowly...",
        "is hesitant, pausing before replying...",
        "is thinking intensely in the ambient glow...",
        "is reading your words slowly...",
        "looks down, eyes shifting in vulnerability..."
      ];
    }
    
    return "$name ${states[random.nextInt(states.length)]}";
  }

  void _showAmbientSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final manager = AmbientSoundManager();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF0C0C14),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Ambient Escape",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          manager.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: _currentScene?.accentColor ?? Colors.white70,
                        ),
                        onPressed: () async {
                          await manager.toggleMute();
                          setModalState(() {});
                          setState(() {}); // Update main ChatScreen
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Immerse yourself with high-fidelity streaming late-night soundscapes.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildAmbientItem(setModalState, AmbientType.none, "Silence (Mute)", Icons.volume_mute, manager),
                  _buildAmbientItem(setModalState, AmbientType.rain, "Rain Ambience", Icons.umbrella_outlined, manager),
                  _buildAmbientItem(setModalState, AmbientType.city, "Midnight City Hum", Icons.nightlife, manager),
                  _buildAmbientItem(setModalState, AmbientType.roomTone, "Warm Room Tone", Icons.home_outlined, manager),
                  _buildAmbientItem(setModalState, AmbientType.thunder, "Distant Thunder", Icons.thunderstorm_outlined, manager),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildAmbientItem(
    StateSetter setModalState, 
    AmbientType type, 
    String name, 
    IconData icon, 
    AmbientSoundManager manager
  ) {
    bool isSelected = manager.activeAmbient == type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: isSelected ? _currentScene!.accentColor : Colors.white30),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected 
          ? Icon(Icons.check_circle_outline, color: _currentScene!.accentColor) 
          : null,
      onTap: () async {
        await manager.setAmbient(type);
        setModalState(() {});
        if (mounted) setState(() {}); // Update main ChatScreen
      },
    );
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
          if (widget.companion.imagePath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
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
                child: CircleAvatar(
                  backgroundColor: widget.companion.themeColor.withOpacity(0.2),
                  backgroundImage: widget.companion.imagePath != null 
                      ? AssetImage(widget.companion.imagePath!) 
                      : null,
                  child: widget.companion.imagePath != null 
                      ? null 
                      : Icon(Icons.person, color: widget.companion.themeColor),
                ),
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
                    Text(
                      "Active now",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              // Audio Call Toggle
              IconButton(
                icon: const Icon(Icons.phone, color: ChatrixTheme.champagneGold),
                onPressed: _handleAudioCallPress,
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

  Widget _buildSceneSelector(List<ChatScene> scenes) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1012),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: scenes.length,
        itemBuilder: (context, index) {
          final scene = scenes[index];
          final isSelected = scene.id == _currentScene?.id;
          return GestureDetector(
            onTap: () {
              if (scene.isPremium && !_isPremiumUser) {
                _showPremiumModal();
              } else {
                setState(() {
                  _currentScene = scene;
                  _showSceneSelector = false;
                });
              }
            },
            child: AnimatedContainer(
              duration: 300.ms,
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1F23),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? scene.accentColor : Colors.white10,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        scene.name, 
                        textAlign: TextAlign.center, 
                        style: GoogleFonts.inter(
                          color: isSelected ? scene.accentColor : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (scene.isPremium)
                    const Positioned(
                      top: 8, right: 8,
                      child: Icon(Icons.lock, color: Colors.white54, size: 16),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ).animate().slideY(begin: -0.2).fadeIn(duration: 400.ms);
  }

  void _showPremiumModal() {
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

  Future<void> _handleAudioCallPress() async {
    final auth = AuthService();
    final isPremium = await auth.isPremium();
    
    if (isPremium) {
      _launchVoiceCall(isPromo: false);
    } else {
      final usedPromo = await auth.hasUsedPromoCall();
      if (!usedPromo) {
        // Show promotional free call dialog
        if (mounted) {
          _showPromoCallDialog();
        }
      } else {
        // Show premium subscription gate
        if (mounted) {
          _showPremiumCallDialog();
        }
      }
    }
  }

  void _showPromoCallDialog() {
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
                border: Border.all(color: ChatrixTheme.champagneGold.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ChatrixTheme.champagneGold.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.star, color: ChatrixTheme.champagneGold, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Voice Preview",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "You are offered 1 free promotional voice call. Experience the breathtaking presence of ${widget.companion.name} in real-time.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatrixTheme.champagneGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        // Mark promo as used
                        await AuthService().markPromoCallUsed();
                        _launchVoiceCall(isPromo: true);
                      },
                      child: const Text("LAUNCH FREE CALL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Not Now", style: TextStyle(color: Colors.white38)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPremiumCallDialog() {
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
                    child: const Icon(Icons.phone_locked_outlined, color: ChatrixTheme.errorRose, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Voice Calling",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "You have used your promotional free call.\nUpgrade to Premium for unlimited voice calls and deep emotional connection.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        ).then((_) async {
                          // Check if user is now premium
                          final isPremium = await AuthService().isPremium();
                          if (mounted) {
                            setState(() {
                              _isPremiumUser = isPremium;
                            });
                          }
                        });
                      },
                      child: const Text("UPGRADE TO PREMIUM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Return", style: TextStyle(color: Colors.white38)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _launchVoiceCall({required bool isPromo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          companion: widget.companion,
          isPromo: isPromo,
        ),
      ),
    ).then((_) async {
      // Re-evaluate premium status upon return in case it changed
      final isPremium = await AuthService().isPremium();
      if (mounted) {
        setState(() {
          _isPremiumUser = isPremium;
        });
      }
    });
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
