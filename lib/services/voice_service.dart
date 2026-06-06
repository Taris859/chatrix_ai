import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  // User's ElevenLabs configuration
  String _apiKey = "sk_b6af5e1e2354b2042bfdf59d2a43d0cd8e0a66557fa1774a";
  final String _maleVoiceId = "jhBzyKbsdeM6F66SZCaK";
  final String _femaleVoiceId = "EXAVITQu4vr4xnSDxMaL"; // Default custom woman voice (Sarah)
  
  void updateApiKey(String key) {
    if (key.trim().isNotEmpty) {
      _apiKey = key.trim();
      print("VoiceService ElevenLabs API key updated dynamically.");
    }
  }

  bool isPlaying = false;

  VoiceService._internal() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        isPlaying = false;
      }
    });

    // Initialize local TTS event handlers
    _flutterTts.setCompletionHandler(() {
      isPlaying = false;
    });
    _flutterTts.setCancelHandler(() {
      isPlaying = false;
    });
    _flutterTts.setErrorHandler((msg) {
      print("Local TTS Error: $msg");
      isPlaying = false;
    });
  }

  /// Generates speech from text and plays it immediately.
  /// Automatically falls back to native device Text-to-Speech if ElevenLabs is unavailable.
  Future<void> speak(
    String text, {
    bool isFemale = false,
    String? voiceId,
    double? customStability,
    double? customSimilarity,
    double? customStyle,
    bool sensualBreathing = true,
    bool isSleepy = false,
  }) async {
    try {
      // 1. Clean the text (remove *action* tags so the AI doesn't read them out loud)
      String cleanText = text.replaceAll(RegExp(r'\*.*?\*'), '').trim();
      if (cleanText.isEmpty) return;

      // Apply sensual pacing and breathing breaks if requested
      if (sensualBreathing) {
        cleanText = _sensualizeText(cleanText);
      }

      // Stop any currently playing audio before starting new voice response
      await stop();
      isPlaying = true;

      // 2. Make request to ElevenLabs API
      String activeVoiceId;
      if (voiceId != null && voiceId.trim().isNotEmpty) {
        final cleanId = voiceId.trim();
        // Standard ElevenLabs voice IDs are 20-character alphanumeric strings,
        // but we allow 15-35 alphanumeric/underscore/hyphen characters to be safe.
        final idPattern = RegExp(r'^[a-zA-Z0-9_-]{15,35}$');
        if (idPattern.hasMatch(cleanId)) {
          activeVoiceId = cleanId;
          print("VoiceService: Using custom or verified voice ID: $activeVoiceId");
        } else {
          activeVoiceId = isFemale ? _femaleVoiceId : _maleVoiceId;
          print("VoiceService: Provided voice ID '$cleanId' is structurally invalid. Falling back to: $activeVoiceId");
        }
      } else {
        activeVoiceId = isFemale ? _femaleVoiceId : _maleVoiceId;
        print("VoiceService: No voice ID provided. Falling back to: $activeVoiceId");
      }

      // Determine voice parameters based on companion and style
      double stability = customStability ?? 0.5;
      double similarityBoost = customSimilarity ?? 0.75;
      double style = customStyle ?? 0.0;

      // Automatically fine-tune settings for highly recognizable sensual or toxic voice profiles
      if (customStability == null && customSimilarity == null && customStyle == null) {
        if (activeVoiceId == "WtHkyNC9q67bYvLejE3N") { // Dante (Mafia Boss - Deep, Toxic, Seductive)
          stability = 0.38;
          similarityBoost = 0.88;
          style = 0.15;
        } else if (activeVoiceId == "jhBzyKbsdeM6F66SZCaK") { // Male CEO / Professor / Doctor / Baker (Mature, deep, steady, dominant/gentle)
          stability = 0.50;
          similarityBoost = 0.85;
          style = 0.05;
        } else if (activeVoiceId == "NXaTw4ifg0LAguvKuIwZ") { // Male Artist / Hacker / Mercenary / Rival (Expressive, highly dynamic, energetic/moody)
          stability = 0.45;
          similarityBoost = 0.80;
          style = 0.10;
        } else if (activeVoiceId == "gUU37agQvEpxeWrZUIMk") { // Alistair / Bodyguard / Violinist (Dark, extremely seductive, deep)
          stability = 0.40;
          similarityBoost = 0.82;
          style = 0.12;
        } else if (activeVoiceId == "4tRn1lSkEn13EVTuqb0g") { // Flirty Females (Valentina, Seraphina, Chloe, Isla, Evie - magnetic, playful, seductive)
          stability = 0.42;
          similarityBoost = 0.85;
          style = 0.15;
        } else if (activeVoiceId == "4BAlflaQyhIcCfHiEI7x") { // Comforting / Gentle Females (Aria, Sunny, Diana, Naomi, Maya - very warm, gentle, sweet)
          stability = 0.55;
          similarityBoost = 0.80;
          style = 0.05;
        } else if (activeVoiceId == "1SaGpH4wLZDmppsPYVpx") { // Younger / Charming Males (Cassian, Arthur, Leo, Haru, Marcus - soft, captivating, playful)
          stability = 0.48;
          similarityBoost = 0.80;
          style = 0.08;
        }
      }

      final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$activeVoiceId');
      
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          "text": cleanText,
          "model_id": "eleven_multilingual_v2",
          "voice_settings": {
            "stability": stability,
            "similarity_boost": similarityBoost,
            "style": style,
            "use_speaker_boost": true
          }
        }),
      );

      // Environment uncertainty: micro latency fluctuations
      final microLatency = (DateTime.now().millisecondsSinceEpoch % 80) + (cleanText.length % 3) * 20;
      await Future.delayed(Duration(milliseconds: microLatency));

      if (response.statusCode == 200) {
        // Distance simulation: muffled/quieter proximity during sleepy mode
        if (isSleepy) {
          await _audioPlayer.setVolume(0.55);
        } else {
          await _audioPlayer.setVolume(1.0);
        }
        
        // 3. Play the audio directly from memory bytes
        Uint8List audioBytes = response.bodyBytes;
        await _audioPlayer.play(BytesSource(audioBytes));
      } else {
        print("ElevenLabs API Error: ${response.statusCode} - ${response.body}");
        print("Falling back to device native Text-To-Speech...");
        await _speakLocalTts(cleanText, isFemale: isFemale);
      }
    } catch (e) {
      print("VoiceService Error: $e");
      print("Catch: Falling back to device native Text-To-Speech...");
      await _speakLocalTts(text, isFemale: isFemale);
    }
  }

  /// Plays a subtle, subconscious non-verbal presence sound asset at a very low volume (12%).
  /// Triggered contextually (thinking, interrupted, sleepy, silence, laughing).
  /// If assets are missing, it falls back silently to ensure robust out-of-the-box operation.
  Future<void> playPresenceTexture(String type) async {
    try {
      final player = AudioPlayer();
      player.setVolume(0.12); // Extremely low, subconscious volume
      
      String assetName = "breath";
      if (type == "thinking") {
        assetName = "exhale";
      } else if (type == "interrupted") {
        assetName = "tap";
      } else if (type == "sleepy") {
        assetName = "cloth";
      } else if (type == "laughing") {
        assetName = "chuckle";
      } else if (type == "silence") {
        assetName = "breath";
      }
      
      await player.play(AssetSource('sounds/$assetName.mp3'));
    } catch (e) {
      print("Presence texture play skipped: $e");
    }
  }


  /// Sensualizes the spoken text by occasionally adding soft pauses and breathy inflections in ElevenLabs.
  /// Unlike the previous implementation that replaced all punctuation with ellipses (which ruined the natural intonation),
  /// this preserves standard punctuation (commas, periods, questions, exclamations) to ensure the AI speaks with high-fidelity
  /// human phrasing, while introducing subtle breathy pauses entirely *by chance* (e.g., 10-20% probability).
  String _sensualizeText(String text) {
    // 1. Keep the original text mostly intact to preserve ElevenLabs' high-quality intonation,
    // especially for questions (?) and exclamation marks (!).
    String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return clean;

    final random = DateTime.now().millisecondsSinceEpoch;

    // 2. Instead of modifying everything, we will build a naturally inflected version
    // splitting by sentences or clauses, and injecting pauses/sighs by chance.
    List<String> words = clean.split(' ');
    List<String> processedWords = [];

    int ellipsisCount = 0;
    bool injectedSigh = false;

    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      processedWords.add(word);

      // We only inject soft pauses/breaths by chance on punctuation-heavy words
      if (word.endsWith(',') || word.endsWith('.') || word.endsWith(';') || word.endsWith(':')) {
        // Limit to maximum 2 dynamic adjustments per short response to keep it fully natural
        if (ellipsisCount < 2) {
          // 20% chance to replace punctuation with a soft lingering ellipsis pause
          int roll = (random + i * 17) % 100;
          if (roll < 20) {
            String wordWithoutPunc = word.substring(0, word.length - 1);

            // 10% chance to add an organic breath/sigh 'ah' or 'mmm' instead of just a pause
            int sighRoll = (random + i * 31) % 100;
            if (sighRoll < 10 && !injectedSigh && clean.length > 25) {
              processedWords[processedWords.length - 1] = "$wordWithoutPunc... ${sighRoll % 2 == 0 ? 'ah' : 'mmm'}... ";
              injectedSigh = true;
            } else {
              processedWords[processedWords.length - 1] = "$wordWithoutPunc... ";
            }
            ellipsisCount++;
          }
        }
      }
    }

    return processedWords.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Plays native device Text-to-Speech, dynamically matching language and gender qualities.
  Future<void> _speakLocalTts(String text, {required bool isFemale}) async {
    try {
      final cleanText = text.replaceAll(RegExp(r'\*.*?\*'), '').trim();
      if (cleanText.isEmpty) {
        isPlaying = false;
        return;
      }

      await _flutterTts.setLanguage("en-US");
      
      // Slightly slower, expressive speed for romantic pacing
      await _flutterTts.setSpeechRate(0.45);

      // Attempt to load and set a gendered voice matching en-US
      try {
        dynamic voices = await _flutterTts.getVoices;
        if (voices is List) {
          bool voiceFound = false;
          for (var item in voices) {
            if (item is Map) {
              final String name = (item['name'] ?? '').toString().toLowerCase();
              final String locale = (item['locale'] ?? '').toString().toLowerCase();

              if (locale.startsWith('en-')) {
                bool isVoiceFemale = name.contains('female') || 
                                     name.contains('zira') || 
                                     name.contains('samantha') || 
                                     name.contains('hazel') || 
                                     name.contains('haruka') || 
                                     name.contains('heera') || 
                                     name.contains('priya') || 
                                     name.contains('muskaan') ||
                                     name.contains('jessica') ||
                                     name.contains('lily') ||
                                     name.contains('alice') ||
                                     name.contains('bella') ||
                                     name.contains('sarah') ||
                                     name.contains('siri') ||
                                     name.contains('cortana');

                bool isVoiceMale = name.contains('male') || 
                                   name.contains('david') || 
                                   name.contains('ravi') || 
                                   name.contains('george') || 
                                   name.contains('mark') ||
                                   name.contains('sterling') ||
                                   name.contains('callum') ||
                                   name.contains('will') ||
                                   name.contains('bill') ||
                                   name.contains('adam') ||
                                   name.contains('viraj') ||
                                   name.contains('charlie') ||
                                   name.contains('liam') ||
                                   name.contains('brian') ||
                                   name.contains('daniel') ||
                                   name.contains('roger');

                if (isFemale && isVoiceFemale && !name.contains('male')) {
                  await _flutterTts.setVoice({
                    "name": (item['name'] ?? '').toString(),
                    "locale": (item['locale'] ?? '').toString(),
                  });
                  voiceFound = true;
                  break;
                } else if (!isFemale && isVoiceMale) {
                  await _flutterTts.setVoice({
                    "name": (item['name'] ?? '').toString(),
                    "locale": (item['locale'] ?? '').toString(),
                  });
                  voiceFound = true;
                  break;
                }
              }
            }
          }

          if (!voiceFound) {
            // Modulate pitch if no explicit gendered voice found
            await _flutterTts.setPitch(isFemale ? 1.15 : 0.85);
          } else {
            await _flutterTts.setPitch(1.0);
          }
        } else {
          await _flutterTts.setPitch(isFemale ? 1.15 : 0.85);
        }
      } catch (voiceError) {
        print("Error selecting gender voice: $voiceError");
        await _flutterTts.setPitch(isFemale ? 1.15 : 0.85);
      }

      isPlaying = true;
      await _flutterTts.speak(cleanText);
    } catch (e) {
      print("Local TTS execution error: $e");
      isPlaying = false;
    }
  }

  /// Stop current playback (both web player and local TTS)
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    isPlaying = false;
  }
}
