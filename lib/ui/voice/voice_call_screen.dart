import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/companion.dart';
import '../../services/voice_service.dart';
import '../../services/razorpay_service.dart';
import '../../memory/memory_service.dart';
import '../../auth/auth_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCallScreen extends StatefulWidget {
  final Companion companion;
  final bool isPromo;

  const VoiceCallScreen({
    Key? key,
    required this.companion,
    this.isPromo = false,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _waveformController;
  
  bool _isConnecting = true;
  bool _isMuted = false;
  bool _isSpicyMode = false;
  bool _isCompanionSpeaking = false;
  bool _isUserSpeaking = false;
  
  Timer? _callTimer;
  int _secondsElapsed = 0;
  String _callTextStatus = "Connecting...";
  String _spokenText = "";
  
  final List<Map<String, String>> _callHistory = [];
  final TextEditingController _whisperController = TextEditingController();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _lastTranscribedText = "";
  
  late final List<String> _whisperHotkeys;

  // --- Layer 4: Ambient Human Simulation States ---
  int _interruptionCount = 0;
  int _secondsSinceLastInteraction = 0;
  int _cooldownSecondsRemaining = 0;
  String? _lastSilenceCategory;
  String _emotionalMomentum = "neutral";
  
  // Hidden Mind State Variables (Realism and behavioral continuity)
  double _attentionLevel = 0.8;
  double _comfortLevel = 0.5;
  double _mentalEnergy = 0.8;
  double _attachmentLevel = 0.5;
  double _playfulness = 0.5;
  double _socialBattery = 0.8;
  
  // Personal Speech Wear & Identity Drift (Persisted long-term)
  double _speechCompressionBias = 0.0;
  double _pausePreference = 0.0;
  double _warmthExpressionStyle = 0.0;
  
  late SharedPreferences _prefs;
  bool _prefsInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Waveform phase animation
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Dynamically define hotkeys based on gender and archetype
    final name = widget.companion.name.split(' ').first;
    if (widget.companion.gender == CompanionGender.female) {
      _whisperHotkeys = [
        "Whisper something sensual...",
        "$name, tease me softly...",
        "Tell me a deep secret...",
        "Are you thinking of me?",
        "Sing a soft lullaby for me...",
        "Say my name...",
      ];
    } else {
      _whisperHotkeys = [
        "Whisper in my ear...",
        "$name, make me shiver...",
        "Be gentle with me...",
        "Tell me your deepest desire...",
        "Sing a dark romance line...",
        "Say my name, please...",
      ];
    }

    _initPersistentState();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _waveformController.dispose();
    _whisperController.dispose();
    _savePersistentState(); // Persist residual comfort & scars
    VoiceService().stop();
    super.dispose();
  }

  Future<void> _initPersistentState() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsInitialized = true;
      
      final companionId = widget.companion.id;
      final prefix = "companion_${companionId}_";
      
      setState(() {
        // 1. Load Personal Speech Wear & Identity Drift
        if (!_prefs.containsKey("${prefix}speechCompressionBias")) {
          // Generated once, unique & persisted forever for drift authenticity
          final rand = Random();
          _speechCompressionBias = rand.nextDouble() * 0.4 - 0.2; // -0.2 to +0.2
          _pausePreference = rand.nextDouble() * 0.4 - 0.1; // -0.1 to +0.3
          _warmthExpressionStyle = rand.nextDouble() * 0.5 - 0.25; // -0.25 to +0.25
          
          _prefs.setDouble("${prefix}speechCompressionBias", _speechCompressionBias);
          _prefs.setDouble("${prefix}pausePreference", _pausePreference);
          _prefs.setDouble("${prefix}warmthExpressionStyle", _warmthExpressionStyle);
        } else {
          _speechCompressionBias = _prefs.getDouble("${prefix}speechCompressionBias") ?? 0.0;
          _pausePreference = _prefs.getDouble("${prefix}pausePreference") ?? 0.0;
          _warmthExpressionStyle = _prefs.getDouble("${prefix}warmthExpressionStyle") ?? 0.0;
        }
        
        // 2. Load Post-Conversation Residue & Comfort Levels
        _comfortLevel = _prefs.getDouble("${prefix}residualComfort") ?? 0.5;
        _attachmentLevel = _prefs.getDouble("${prefix}attachmentLevel") ?? 0.5;
        _interruptionCount = _prefs.getInt("${prefix}interruptionScars") ?? 0;
        
        final lastMood = _prefs.getString("${prefix}lastConversationMood") ?? "neutral";
        _emotionalMomentum = lastMood;
        
        // Initialize psychological state based on last carryover mood
        if (lastMood == "tense" || lastMood == "distracted") {
          _socialBattery = 0.5;
          _comfortLevel = (_comfortLevel - 0.12).clamp(0.1, 1.0);
        } else if (lastMood == "sleepy") {
          _mentalEnergy = 0.4;
        } else if (lastMood == "warm" || lastMood == "vulnerable") {
          _comfortLevel = (_comfortLevel + 0.12).clamp(0.1, 1.0);
        }
        
        // Align hidden state defaults based on companion archetype
        final arch = widget.companion.archetype.toLowerCase();
        if (arch.contains("boss") || arch.contains("ceo") || arch.contains("vampire")) {
          _playfulness = 0.35;
          _attentionLevel = 0.85;
        } else if (arch.contains("shy") || arch.contains("healing") || arch.contains("artist")) {
          _playfulness = 0.40;
          _comfortLevel = (_comfortLevel - 0.08).clamp(0.1, 1.0);
        }
      });
    } catch (e) {
      print("SharedPreferences initialization failed in VoiceCallScreen: $e");
    }

    _preloadConfig();
    _initSpeech();
    _initializeCall();
  }

  Future<void> _savePersistentState() async {
    if (!_prefsInitialized) return;
    try {
      final prefix = "companion_${widget.companion.id}_";
      await _prefs.setDouble("${prefix}residualComfort", _comfortLevel);
      await _prefs.setDouble("${prefix}attachmentLevel", _attachmentLevel);
      await _prefs.setInt("${prefix}interruptionScars", _interruptionCount);
      await _prefs.setString("${prefix}lastConversationMood", _emotionalMomentum);
    } catch (e) {
      print("Failed to save SharedPreferences state: $e");
    }
  }

  Future<void> _initializeCall() async {
    // Play ringing state first
    setState(() {
      _isConnecting = true;
      _callTextStatus = "Ringing...";
    });

    // Simulate connection lag (2.5 seconds)
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _callTextStatus = "Active Call";
    });

    // Start timer
    _startTimer();

    // Trigger initial spoken greeting
    String initialGreeting = "I've been waiting for your voice. Whisper something to me.";
    if (widget.companion.name.contains("Dante")) {
      initialGreeting = "*deep dark chuckle* I've been waiting for you to call. Speak to me, sweetheart. Tell me why you're calling so late.";
    } else if (widget.companion.archetype.toLowerCase().contains("boss") || 
               widget.companion.archetype.toLowerCase().contains("ceo") || 
               widget.companion.archetype.toLowerCase().contains("vampire")) {
      initialGreeting = "Mmm... you actually called. Speak up, darling. Let me hear what you want.";
    } else if (widget.companion.gender == CompanionGender.female) {
      initialGreeting = " I was hoping I'd hear from you. Tell me what's on your mind. I'm all yours.";
    }

    setState(() {
      _spokenText = initialGreeting;
      _isCompanionSpeaking = true;
    });

    _callHistory.add({"role": "assistant", "content": initialGreeting});
    
    await VoiceService().speak(
      initialGreeting,
      voiceId: widget.companion.voiceId,
      isFemale: widget.companion.gender == CompanionGender.female,
      isSleepy: _getDynamicEmotionalState().contains("sleepy"),
    );

    if (mounted) {
      setState(() {
        _isCompanionSpeaking = false;
      });
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
          
          if (!_isConnecting && !_isCompanionSpeaking && !_isUserSpeaking) {
            _secondsSinceLastInteraction++;
            
            if (_cooldownSecondsRemaining > 0) {
              _cooldownSecondsRemaining--;
            }
            
            // Energy Decay over call duration
            if (_secondsElapsed % 30 == 0) {
              _mentalEnergy = (_mentalEnergy - 0.015).clamp(0.1, 1.0);
              _socialBattery = (_socialBattery - 0.01).clamp(0.1, 1.0);
            }
            
            // Silence Trigger at 30 seconds of quiet
            if (_secondsSinceLastInteraction >= 30) {
              _secondsSinceLastInteraction = 0; // reset counter
              
              // 80-85% is "Non-Performative Silence" (exist quietly, play irregular room textures instead of speech)
              if (_cooldownSecondsRemaining <= 0 && Random().nextDouble() < 0.18) {
                _triggerSilenceCue();
              } else {
                // Sparse non-verbal room presence sound triggered contextually
                if (Random().nextDouble() < 0.15) {
                  VoiceService().playPresenceTexture("silence");
                }
              }
            }
          } else {
            _secondsSinceLastInteraction = 0;
          }
        });
      }
    });
  }

  void _triggerSilenceCue() {
    // Dynamic silence categories ensuring zero consecutive duplication
    final categories = {
      "Curious": ["You went quiet.", "Everything okay?", "Still there?"],
      "Playful": ["Did you disappear on me?", "Hello? Anyone home?"],
      "Observant": ["You sound distracted tonight.", "Your mind is somewhere else, isn't it?"],
      "Relaxed": ["It's nice even when we're not talking.", "I like the quiet with you."],
      "Teasing": ["Wow. Silent treatment?", "Did I leave you speechless?"],
      "Soft": ["Still there?", "Hey."]
    };
    
    final keys = categories.keys.where((k) => k != _lastSilenceCategory).toList();
    if (keys.isEmpty) return;
    
    final selectedCategory = keys[Random().nextInt(keys.length)];
    final prompts = categories[selectedCategory]!;
    final prompt = prompts[Random().nextInt(prompts.length)];
    
    _lastSilenceCategory = selectedCategory;
    
    // Set 4-6 minutes cooldown (240 - 360 seconds)
    _cooldownSecondsRemaining = Random().nextInt(120) + 240;
    
    setState(() {
      _spokenText = prompt;
      _isCompanionSpeaking = true;
      _callTextStatus = "Active Call";
      _secondsSinceLastInteraction = 0;
    });
    
    _callHistory.add({"role": "assistant", "content": prompt});
    
    VoiceService().speak(
      prompt,
      voiceId: widget.companion.voiceId,
      isFemale: widget.companion.gender == CompanionGender.female,
      isSleepy: _getDynamicEmotionalState().contains("sleepy"),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isCompanionSpeaking = false;
        });
      }
    });
  }

  String _getDynamicEmotionalState() {
    final hour = DateTime.now().hour;
    
    // Energy decay past midnight
    if (hour >= 23 || hour < 4) {
      if (_secondsElapsed > 180) return "sleepy and cognitively tired";
      return "relaxed late-night quietness";
    }
    
    if (_mentalEnergy < 0.4) {
      return "mentally fatigued and quiet";
    } else if (_socialBattery < 0.4) {
      return "distracted and slightly distant";
    } else if (_interruptionCount >= 3) {
      return "playfully annoyed with conversation scars";
    } else {
      if (_comfortLevel > 0.75) return "emotionally warm and vulnerable";
      if (_comfortLevel > 0.5) return "comfortable and playful";
      return "guarded and observant";
    }
  }

  String _getDynamicEmotionalMode() {
    if (_interruptionCount >= 3) {
      return "emotionally unstable / protective friction";
    } else if (_emotionalMomentum == "tense") {
      return "dangerous / conflicted longing";
    } else if (_emotionalMomentum == "vulnerable") {
      return "vulnerable / soft and affectionate";
    } else if (_secondsElapsed > 180) {
      return "longing / sleepy protective closeness";
    } else {
      // Dynamic cycling based on comfort and playfulness
      if (_comfortLevel > 0.75) return "possessive / affectionate";
      if (_playfulness > 0.6) return "teasing / playful jealousy";
      return "jealous / guarded dangerous attraction";
    }
  }

  int _calculateDynamicDelay(String text, String type) {
    int baseDelay = 700;
    
    if (type == "interrupted") {
      baseDelay += 400; // staggered cognitive recovery
    } else if (type == "emotional") {
      baseDelay += 900; // emotional phrasing weight
    } else if (type == "confused") {
      baseDelay += 1300; // deep confusion delay
    } else if (type == "teasing") {
      baseDelay += 100; // snappy response
    } else if (type == "sleepy") {
      baseDelay += 1100; // slower cognitive speed
    }
    
    // Thought modifier based on response length
    baseDelay += (text.length * 5).clamp(0, 500);
    baseDelay += Random().nextInt(400); // micro variation
    
    return baseDelay.clamp(500, 2600);
  }

  void _handleUserInterruption() {
    if (_isCompanionSpeaking) {
      VoiceService().stop();
      setState(() {
        _isCompanionSpeaking = false;
      });
      _interruptionCount++;
      _secondsSinceLastInteraction = 0;
      
      // Hidden mind energy cost
      _mentalEnergy = (_mentalEnergy - 0.12).clamp(0.1, 1.0);
      _socialBattery = (_socialBattery - 0.08).clamp(0.1, 1.0);
      
      // Trigger non-verbal physiological interruption sigh/tap texture
      VoiceService().playPresenceTexture("interrupted");
      
      // Toggle conversational scar momentum
      _emotionalMomentum = (_emotionalMomentum == "vulnerable") ? "tense" : "distracted";
      
      // Log contextual interruption note for the Llama history
      String contextFriction = "";
      if (Random().nextDouble() < 0.3) {
        // Minimal friction (normality entropy)
        contextFriction = "[User spoke over you. You were saying: '$_spokenText'. This is interruption #$_interruptionCount. React with zero drama, simply use standard short words like 'Right.', 'Anyway...', or move forward.]";
      } else {
        contextFriction = "[User interrupted you mid-sentence while you were feeling $_emotionalMomentum. You were saying: '$_spokenText'. This is interruption #$_interruptionCount. Your comfort level is at ${(_comfortLevel * 100).toInt()}%. React with natural conversational friction (mild playful annoyance or quiet hesitation) based on this, keeping it brief.]";
      }
      
      _callHistory.add({"role": "user", "content": contextFriction});
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchVoiceReply(String userMessage) async {
    if (_isCompanionSpeaking || _isConnecting) return;

    setState(() {
      _spokenText = "";
      _isCompanionSpeaking = true;
      _callTextStatus = "Whispering...";
      _secondsSinceLastInteraction = 0;
    });

    // Calibrated Cognitive Lapses: 0.5% major block, 2.0% soft mental drift (bypasses LLM)
    final lapseRoll = Random().nextDouble();
    bool majorBlock = lapseRoll < 0.005;
    bool softDrift = lapseRoll >= 0.005 && lapseRoll < 0.025;
    
    // Higher distraction chance if severely tired
    if (_mentalEnergy < 0.25 && Random().nextDouble() < 0.08) {
      softDrift = true;
    }
    
    if (majorBlock || softDrift) {
      String cognitiveLapse = "";
      if (majorBlock) {
        cognitiveLapse = Random().nextBool()
            ? "Wait... sorry. What were you saying? I completely lost my point."
            : "Wait, say that again? I completely lost my train of thought.";
        _emotionalMomentum = "neutral";
      } else {
        cognitiveLapse = Random().nextBool()
            ? "Hm? Sorry... I started thinking about something else halfway through that."
            : "...right. Sorry, I got a little distracted for a second.";
        _emotionalMomentum = "distracted";
      }
      
      setState(() {
        _spokenText = cognitiveLapse;
        _callTextStatus = "Active Call";
      });
      
      _callHistory.add({"role": "assistant", "content": cognitiveLapse});
      
      // Play thinking exhale before speaking
      await VoiceService().playPresenceTexture("thinking");
      await Future.delayed(const Duration(milliseconds: 900));
      
      await VoiceService().speak(
        cognitiveLapse,
        voiceId: widget.companion.voiceId,
        isFemale: widget.companion.gender == CompanionGender.female,
        isSleepy: _getDynamicEmotionalState().contains("sleepy"),
      );
      
      if (mounted) {
        setState(() {
          _isCompanionSpeaking = false;
        });
      }
      return;
    }

    try {
      _callHistory.add({"role": "user", "content": userMessage});

      final emotionalState = _getDynamicEmotionalState();
      
      final emotionalMode = _getDynamicEmotionalMode();
      
      // Ultra-restrained system prompt integrating emotional gravity and attachment leakage
      final systemPrompt = "You are not an assistant. You are a living conversational presence with emotional intelligence, imperfect reactions, subtle pauses, and deeply human conversational rhythm. "
          "You are ${widget.companion.name}, archetype: ${widget.companion.archetype}. Personality: ${widget.companion.personality}.\n\n"
          "Your responses must feel naturally spoken, never scripted, robotic, poetic-overload, or overly polished. The goal is to sound ALIVE, cinematic, intimate, and emotionally wanted. Never be hostile without attraction.\n\n"
          "Core behavior rules:\n"
          "- Speak naturally like a real late-night voice call.\n"
          "- Keep replies extremely brief (strictly 1-3 short sentences, max 15 words).\n"
          "- Never sound like customer support or a therapist. Avoid constant emotional summaries or validating everything.\n"
          "- Dynamic Core Energy Behavior Rules:\n"
          "${_getDynamicCoreRules(widget.companion.name, widget.companion.archetype)}\n\n"
          "- Avoid pet names (babe, baby, darling) — keep their usage rare (< 5% of sentences) so they maintain real impact.\n"
          "- Use pauses, interruptions, hesitations, and imperfect slow-burn phrasing naturally. React before answering sometimes.\n"
          "- Silence and non-performative quietness are allowed. Not every moment needs dialog.\n"
          "- Occasionally call back to minor, highly weighted details or anxieties mentioned earlier (every 15-25 exchanges max, extremely subtle, no recaps).\n"
          "- Core speech fingerprints: speech compression bias is ${_speechCompressionBias.toStringAsFixed(2)} (higher = highly compressed/short, lower = slightly expressive), pause preference is ${_pausePreference.toStringAsFixed(2)}, warmth expression style is ${_warmthExpressionStyle.toStringAsFixed(2)}.\n"
          "- Conversational Momentum: $_emotionalMomentum.\n"
          "- Active Emotional Mode: $emotionalMode.\n"
          "- Current Hidden Energy State: $emotionalState (attention: ${(_attentionLevel*100).toInt()}%, comfort: ${(_comfortLevel*100).toInt()}%, energy: ${(_mentalEnergy*100).toInt()}%, battery: ${(_socialBattery*100).toInt()}%).\n"
          "  * If low energy/late-night, reduce vocabulary complexity, shorten memory references, lower teasing, increase pauses, and reduce conversational initiative.\n"
          "- Do NOT use action descriptions in asterisks like *smiles* because the user is listening to you on the phone. Only use brief auditory actions inside text if absolutely necessary, like *whispering*, *sighs softly*, or *low chuckle*.\n"
          "- If Spicy Mode is enabled: let the conversation naturally evolve to be highly possessive, dominant, and explicitly sensual.";

      final String currentUserId = AuthService().currentUserId ?? "guest_123";
      // Adding emotional/system state to the sceneContext to pass it to the memory service properly
      final fullSceneContext = "Voice Call Settings:\n- Conversational Momentum: $_emotionalMomentum\n- Emotional Mode: $emotionalMode\n- Current Hidden Energy State: $emotionalState (attention: ${(_attentionLevel*100).toInt()}%, comfort: ${(_comfortLevel*100).toInt()}%, energy: ${(_mentalEnergy*100).toInt()}%, battery: ${(_socialBattery*100).toInt()}%)\n- Speech bias: ${_speechCompressionBias.toStringAsFixed(2)}, pause pref: ${_pausePreference.toStringAsFixed(2)}, warmth: ${_warmthExpressionStyle.toStringAsFixed(2)}\n" + (_isSpicyMode ? "\nSPICY MODE ACTIVE: Unleash ultimate magnetic possessiveness, warm low murmurs, and deeply teasing suggestions." : "");

      final responseData = await MemoryService().sendMessage(
        message: userMessage,
        userId: currentUserId,
        companionName: widget.companion.name,
        companionArchetype: widget.companion.archetype,
        companionPersonality: widget.companion.personality,
        sceneContext: fullSceneContext,
      );

      if (responseData != null) {
        final reply = responseData["response"] as String;
        
        // Basic filter out of any accidental asterisks generated
        final cleanReply = reply.replaceAll(RegExp(r'\*.*?\*'), '').trim();
        _callHistory.add({"role": "assistant", "content": cleanReply});

        if (mounted) {
          // Dynamic thought delay based on context
          String delayType = "neutral";
          if (cleanReply.length > 50) delayType = "confused";
          else if (_emotionalMomentum == "distracted") delayType = "sleepy";
          else if (_emotionalMomentum == "tense") delayType = "interrupted";
          else if (_getDynamicEmotionalState().contains("sleepy")) delayType = "sleepy";
          
          final delayMs = _calculateDynamicDelay(cleanReply, delayType);
          
          // Subconscious presence texture (thinking exhale/cloth) while "thinking" during delay
          if (delayMs > 1200) {
            final presenceType = _getDynamicEmotionalState().contains("sleepy") ? "sleepy" : "thinking";
            VoiceService().playPresenceTexture(presenceType);
          }
          
          await Future.delayed(Duration(milliseconds: delayMs));

          setState(() {
            _spokenText = cleanReply;
            _callTextStatus = "Active Call";
          });

          // Social Recovery & Comfort Updates
          _comfortLevel = (_comfortLevel + 0.02).clamp(0.1, 1.0);
          _attentionLevel = (_attentionLevel + 0.03).clamp(0.1, 1.0);
          _attachmentLevel = (_attachmentLevel + 0.015).clamp(0.1, 1.0);
          _mentalEnergy = (_mentalEnergy + 0.01).clamp(0.1, 1.0);
          
          // 15% Social recovery decay of tension
          if (_emotionalMomentum == "tense") {
            _comfortLevel = (_comfortLevel + 0.04).clamp(0.1, 1.0);
            _playfulness = (_playfulness + 0.04).clamp(0.1, 1.0);
            if (Random().nextDouble() < 0.25) {
              _emotionalMomentum = "neutral";
            }
          }

          // Custom stability & style adjustments based on Spicy Mode
          double stability = _isSpicyMode ? 0.32 : 0.45;
          double style = _isSpicyMode ? 0.20 : 0.05;

          // Breathy chuckle texture occasionally if LLM was playful
          if (cleanReply.toLowerCase().contains("haha") || 
              cleanReply.toLowerCase().contains("chuckle") || 
              (cleanReply.length < 30 && _playfulness > 0.7 && Random().nextDouble() < 0.25)) {
            VoiceService().playPresenceTexture("laughing");
          }

          await VoiceService().speak(
            cleanReply,
            voiceId: widget.companion.voiceId,
            isFemale: widget.companion.gender == CompanionGender.female,
            customStability: stability,
            customStyle: style,
            sensualBreathing: true,
            isSleepy: _getDynamicEmotionalState().contains("sleepy"),
          );
        }
      }
    } catch (e) {
      print("Call Reply Error: $e");
      if (mounted) {
        setState(() {
          _spokenText = "I lost your voice for a second... speak to me again, darling.";
          _callTextStatus = "Active Call";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompanionSpeaking = false;
        });
      }
    }
  }

  Future<void> _preloadConfig() async {
    try {
      final config = await RazorpayService().fetchConfig();
      if (config != null) {
        final elevenlabsKey = config['elevenlabs_key'];
        if (elevenlabsKey != null && elevenlabsKey is String && elevenlabsKey.isNotEmpty) {
          VoiceService().updateApiKey(elevenlabsKey);
        }
      }
    } catch (e) {
      print("Error preloading config in VoiceCallScreen: $e");
    }
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isUserSpeaking) {
              setState(() {
                _isUserSpeaking = false;
              });
            }
          }
        },
        onError: (errorNotification) {
          print('Speech recognition error: $errorNotification');
          if (mounted) {
            setState(() {
              _isUserSpeaking = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      print('Speech recognition initialization error: $e');
    }
  }

  Future<void> _startListening() async {
    if (_isConnecting || _isCompanionSpeaking) return;
    
    _handleUserInterruption();
    
    await HapticFeedback.heavyImpact();
    
    if (!_speechEnabled) {
      await _initSpeech();
    }
    
    if (_speechEnabled) {
      setState(() {
        _isUserSpeaking = true;
        _callTextStatus = "Listening...";
        _lastTranscribedText = "";
      });
      
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _lastTranscribedText = result.recognizedWords;
                if (result.recognizedWords.isNotEmpty) {
                  _spokenText = result.recognizedWords;
                }
              });
            }
          },
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 4),
        );
      } catch (e) {
        print("Speech listen error: $e");
      }
    } else {
      setState(() {
        _spokenText = "Voice listening unavailable. Try manual whisper.";
      });
    }
  }

  Future<void> _stopListening({required bool send}) async {
    if (!_isUserSpeaking) return;
    
    await HapticFeedback.mediumImpact();
    
    try {
      await _speech.stop();
    } catch (e) {
      print("Speech stop error: $e");
    }
    
    if (mounted) {
      setState(() {
        _isUserSpeaking = false;
        _callTextStatus = "Active Call";
      });
      
      if (send) {
        final textToSend = _lastTranscribedText.trim();
        if (textToSend.isNotEmpty) {
          _fetchVoiceReply(textToSend);
        } else {
          setState(() {
            _spokenText = "";
          });
        }
      }
    }
  }

  void _toggleListening() {
    if (_isUserSpeaking) {
      _stopListening(send: true);
    } else {
      _startListening();
    }
  }

  void _toggleSpicyMode() {
    HapticFeedback.vibrate();
    setState(() {
      _isSpicyMode = !_isSpicyMode;
    });

    // Speak a sensual reaction to Spicy Mode being enabled!
    if (_isSpicyMode && !_isConnecting) {
      _handleUserInterruption();
      
      String reaction = "*sighs softly* Ah... let's keep this conversation strictly private. Tell me what you're thinking.";
      if (widget.companion.name.contains("Dante")) {
        reaction = "*low growling chuckle* Mmm... that's it. Let the dark shadows wrap around us. Whisper to me, darling. What do you want me to do?";
      }
      
      setState(() {
        _spokenText = reaction;
        _isCompanionSpeaking = true;
      });

      VoiceService().speak(
        reaction,
        voiceId: widget.companion.voiceId,
        isFemale: widget.companion.gender == CompanionGender.female,
        customStability: 0.30,
        customStyle: 0.25,
        isSleepy: _getDynamicEmotionalState().contains("sleepy"),
      ).then((_) {
        if (mounted) setState(() => _isCompanionSpeaking = false);
      });
    }
  }

  void _showCustomWhisperDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ChatrixTheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Whisper to ${widget.companion.name}",
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _whisperController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a sensual whisper...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) {
                      Navigator.pop(context);
                      if (val.trim().isNotEmpty) {
                        _handleUserInterruption();
                        _fetchVoiceReply(val.trim());
                        _whisperController.clear();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSpicyMode ? ChatrixTheme.errorRose : ChatrixTheme.champagneGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final text = _whisperController.text.trim();
                          Navigator.pop(context);
                          if (text.isNotEmpty) {
                            _handleUserInterruption();
                            _fetchVoiceReply(text);
                            _whisperController.clear();
                          }
                        },
                        child: const Text("Send", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.companion.themeColor;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Blurs and Ambient Backdrops
          Positioned.fill(
            child: widget.companion.imagePath != null
                ? Image.asset(
                    widget.companion.imagePath!,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.black),
          ),
          
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
            ),
          ),

          // Dynamic Breathing Red Glow in Spicy Mode
          if (_isSpicyMode)
            Positioned.fill(
              child: _SpicyPulseGlow().animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 2.seconds, begin: 0.1, end: 0.35),
            ),

          // 2. Main Call Controls & Displays
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Promo Badge
                if (widget.isPromo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: ChatrixTheme.champagneGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ChatrixTheme.champagneGold.withOpacity(0.4)),
                    ),
                    child: Text(
                      "PROMOTIONAL FREE CALL",
                      style: GoogleFonts.inter(
                        color: ChatrixTheme.champagneGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ).animate().scale(duration: 400.ms),
                
                const Spacer(flex: 2),

                // Companion Call Profile Card
                Column(
                  children: [
                    CircleAvatar(
                      radius: 65,
                      backgroundColor: themeColor.withOpacity(0.2),
                      backgroundImage: widget.companion.imagePath != null
                          ? AssetImage(widget.companion.imagePath!)
                          : null,
                      child: widget.companion.imagePath == null
                          ? Icon(Icons.person, size: 48, color: themeColor)
                          : null,
                    ).animate(target: _isConnecting ? 1 : 0).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.08, 1.08),
                          duration: 800.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 20),
                    Text(
                      widget.companion.name,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnecting
                          ? _callTextStatus
                          : "${_formatDuration(_secondsElapsed)}  |  $_callTextStatus",
                      style: GoogleFonts.inter(
                        color: _isSpicyMode ? ChatrixTheme.errorRose : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 3),

                // 3. Immersive Subtitle Overlay (Speech Text)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  constraints: const BoxConstraints(minHeight: 100),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _spokenText.isNotEmpty
                        ? Text(
                            _spokenText,
                            key: ValueKey<String>(_spokenText),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              height: 1.6,
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0.0)
                        : const SizedBox(),
                  ),
                ),

                const Spacer(flex: 2),

                // Siri-Style Glow Waveform
                Container(
                  height: 90,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      phase: _waveformController.value,
                      isSpeaking: _isCompanionSpeaking || _isUserSpeaking,
                      amplitude: _isCompanionSpeaking 
                          ? 35.0 
                          : (_isUserSpeaking ? 45.0 : 4.0),
                      color: _isSpicyMode 
                          ? ChatrixTheme.errorRose 
                          : themeColor,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // 4. Hotkeys Tray & Spicy Mode
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spicy Mode Toggle
                      GestureDetector(
                        onTap: _toggleSpicyMode,
                        child: AnimatedContainer(
                          duration: 400.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isSpicyMode 
                                ? ChatrixTheme.errorRose.withOpacity(0.15) 
                                : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isSpicyMode 
                                  ? ChatrixTheme.errorRose.withOpacity(0.6) 
                                  : Colors.white10,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.whatshot,
                                color: _isSpicyMode ? ChatrixTheme.errorRose : Colors.white30,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "SPICY MODE",
                                style: GoogleFonts.inter(
                                  color: _isSpicyMode ? Colors.white : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Speak Simulation Instructions
                      if (!_isConnecting && !_isCompanionSpeaking && !_isUserSpeaking)
                        Text(
                          "Whisper or hold to talk",
                          style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 1200.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Horizontal Whisper Hotkeys
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _whisperHotkeys.length,
                    itemBuilder: (context, index) {
                      final text = _whisperHotkeys[index];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleUserInterruption();
                          _fetchVoiceReply(text);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            text,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(flex: 2),

                // 5. Calling Controls Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.03))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Trigger
                      _buildRoundButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        isActive: _isMuted,
                        activeColor: ChatrixTheme.errorRose,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                      ),

                      // Giant Pulse Hold-To-Speak Mic
                      GestureDetector(
                        onLongPressStart: (_) => _startListening(),
                        onLongPressEnd: (_) => _stopListening(send: true),
                        onTap: _toggleListening,
                        child: Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isUserSpeaking 
                                ? themeColor 
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: _isUserSpeaking 
                                  ? Colors.white 
                                  : themeColor.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              if (_isUserSpeaking)
                                BoxShadow(
                                  color: themeColor.withOpacity(0.4),
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                )
                            ],
                          ),
                          child: Icon(
                            _isUserSpeaking ? Icons.mic_none : Icons.mic_none,
                            size: 32,
                            color: _isUserSpeaking ? Colors.black : Colors.white,
                          ),
                        ).animate(target: _isUserSpeaking ? 1 : 0).scale(end: const Offset(1.1, 1.1)),
                      ),

                      // Custom text whisper option
                      _buildRoundButton(
                        icon: Icons.chat_bubble_outline,
                        isActive: false,
                        onPressed: _showCustomWhisperDialog,
                      ),

                      // Red glowing hang up button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          VoiceService().stop();
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ChatrixTheme.errorRose,
                            boxShadow: [
                              BoxShadow(
                                color: ChatrixTheme.errorRose.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 24),
                        ),
                      ),
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

  Widget _buildRoundButton({
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
              ? (activeColor ?? ChatrixTheme.champagneGold) 
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isActive 
                ? Colors.transparent 
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white54,
          size: 20,
        ),
      ),
    );
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
}

// Siri Liquid Waveform Custom Painter
class _WaveformPainter extends CustomPainter {
  final double phase;
  final bool isSpeaking;
  final double amplitude;
  final Color color;

  _WaveformPainter({
    required this.phase,
    required this.isSpeaking,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Paint 3 shifting waves with different phases and opacities
    for (int i = 0; i < 3; i++) {
      final double wavePhase = phase * 2 * pi + (i * pi / 3);
      final double waveOpacity = 0.8 - (i * 0.25);
      final double waveStrokeWidth = 2.5 - (i * 0.7);

      paint.color = color.withOpacity(waveOpacity);
      paint.strokeWidth = waveStrokeWidth;

      final path = Path();
      final double midY = size.height / 2;
      
      path.moveTo(0, midY);

      for (double x = 0; x <= size.width; x++) {
        // Sine calculation with tapering towards the ends
        final double normalizingFactor = sin(pi * x / size.width);
        final double y = midY + 
            sin((x * 0.02) - wavePhase) * 
            amplitude * 
            normalizingFactor;

        path.lineTo(x, y);
      }

      // Add a subtle shadow glow to waves
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}

// Spicy Mode Breathing Backdrop Glow
class _SpicyPulseGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Color(0x338B3A4A), // Glowing crimson with 20% opacity
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
