import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/llm_engine.dart';
import '../services/encryption_service.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // LOCAL CACHE — Chat Transcript
  // ─────────────────────────────────────────────────────────────

  Future<void> cacheMessages(String userId, String companionName, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${userId}_$companionName';
    final payload = jsonEncode(messages);
    final encrypted = await EncryptionService().encrypt(payload, userId);
    await prefs.setString(key, encrypted);
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String userId, String companionName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${userId}_$companionName';
    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        final decrypted = await EncryptionService().decrypt(cached, userId);
        final List<dynamic> decoded = jsonDecode(decrypted);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        print('Error decrypting cached messages: $e');
      }
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  // LOCAL CACHE — AI Memory (NEVER cleared on chat delete)
  // ─────────────────────────────────────────────────────────────

  Future<void> cacheMemory(String userId, String companionName, Map<String, dynamic> memoryData) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'memory_${userId}_$companionName';
    final payload = jsonEncode(memoryData);
    final encrypted = await EncryptionService().encrypt(payload, userId);
    await prefs.setString(key, encrypted);
  }

  Future<Map<String, dynamic>?> getCachedMemory(String userId, String companionName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'memory_${userId}_$companionName';
    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        final decrypted = await EncryptionService().decrypt(cached, userId);
        return jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (e) {
        print('Error decrypting cached memory: $e');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH HISTORY — reads from chats/ collection
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchHistory(String userId, String companionName) async {
    try {
      final chatId = '${userId}_$companionName';
      final doc = await _firestore.collection('chats').doc(chatId).get();

      if (doc.exists) {
        final data = doc.data()!;
        List<Map<String, dynamic>> parsedMessages = [];

        if (data.containsKey('encrypted_messages')) {
          final decrypted = await EncryptionService().decrypt(data['encrypted_messages'], userId);
          final List<dynamic> decoded = jsonDecode(decrypted);
          parsedMessages = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data.containsKey('messages')) {
          // Fallback to cleartext legacy format
          final List<dynamic> messages = data['messages'] ?? [];
          parsedMessages = messages.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        await cacheMessages(userId, companionName, parsedMessages);
        return parsedMessages;
      }
    } catch (e) {
      print('Firestore error fetching history: $e');
    }
    return await getCachedMessages(userId, companionName);
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH MEMORY — reads from ai_memory/ collection
  // Memory persists independently of chat transcript deletions.
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchMemory(String userId, String companionName) async {
    Map<String, dynamic>? memory;

    // Primary: read from dedicated ai_memory collection
    try {
      final memoryId = '${userId}_$companionName';
      final doc = await _firestore.collection('ai_memory').doc(memoryId).get();

      if (doc.exists) {
        final data = doc.data()!;
        Map<String, dynamic> summary = {};
        List<dynamic> diary = [];

        if (data.containsKey('encrypted_summary')) {
          final decrypted = await EncryptionService().decrypt(data['encrypted_summary'], userId);
          summary = jsonDecode(decrypted) as Map<String, dynamic>;
        } else if (data.containsKey('summary')) {
          summary = Map<String, dynamic>.from(data['summary'] ?? {});
        }

        if (data.containsKey('encrypted_diary_entries')) {
          final decrypted = await EncryptionService().decrypt(data['encrypted_diary_entries'], userId);
          diary = jsonDecode(decrypted) as List<dynamic>;
        } else if (data.containsKey('diary_entries')) {
          diary = data['diary_entries'] ?? [];
        }

        memory = {
          'summary': summary,
          'diary_entries': diary,
          'version': data['version'] ?? 0,
        };
      }
    } catch (e) {
      print('Firestore error fetching memory from ai_memory: $e');
    }

    // Fallback: legacy data may still be in chats/ document (migration path)
    if (memory == null) {
      try {
        final chatId = '${userId}_$companionName';
        final doc = await _firestore.collection('chats').doc(chatId).get();
        if (doc.exists) {
          final data = doc.data()!;
          Map<String, dynamic> summary = {};
          List<dynamic> diary = [];

          if (data.containsKey('encrypted_summary')) {
            final decrypted = await EncryptionService().decrypt(data['encrypted_summary'], userId);
            summary = jsonDecode(decrypted) as Map<String, dynamic>;
          } else if (data.containsKey('summary')) {
            summary = Map<String, dynamic>.from(data['summary'] ?? {});
          }

          if (data.containsKey('encrypted_diary_entries')) {
            final decrypted = await EncryptionService().decrypt(data['encrypted_diary_entries'], userId);
            diary = jsonDecode(decrypted) as List<dynamic>;
          } else if (data.containsKey('diary_entries')) {
            diary = data['diary_entries'] ?? [];
          }

          if (summary.isNotEmpty || diary.isNotEmpty) {
            memory = {'summary': summary, 'diary_entries': diary, 'version': 0};
            _migrateLegacyMemory(userId, companionName, summary, diary);
          }
        }
      } catch (e) {
        print('Firestore error reading legacy memory from chats/: $e');
      }
    }

    // Final fallback: local encrypted cache
    if (memory == null) {
      memory = await getCachedMemory(userId, companionName) ??
          {'summary': <String, dynamic>{}, 'diary_entries': [], 'version': 0};
    }

    // Inject user profile from users/ document (Tiered Priority System)
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (memory['summary'] == null || memory['summary'] is! Map) {
          memory['summary'] = <String, dynamic>{};
        }

        final idData = data['identity'] as Map<String, dynamic>? ?? {};
        final emoData = data['emotional_profile'] as Map<String, dynamic>? ?? {};
        final socData = data['social_memory'] as Map<String, dynamic>? ?? {};
        final lifeData = data['lifestyle'] as Map<String, dynamic>? ?? {};

        final random = Random();
        final bool loadSocial = random.nextDouble() > 0.5;
        final bool loadLifestyle = random.nextDouble() > 0.5;

        Map<String, dynamic> dynamicProfile = {
          'core_identity': idData,
          'emotional_needs': emoData,
        };

        if (loadSocial && socData.isNotEmpty) {
          dynamicProfile['social_context'] = socData;
        }
        if (loadLifestyle && lifeData.isNotEmpty) {
          dynamicProfile['lifestyle'] = lifeData;
        }

        memory['summary']['user_profile'] = dynamicProfile;
      }
    } catch (e) {
      print('Error fetching user profile for AI memory injection: $e');
    }

    if (memory.containsKey('summary') || memory.containsKey('diary_entries')) {
      await cacheMemory(userId, companionName, memory);
    }

    return memory;
  }

  // ─────────────────────────────────────────────────────────────
  // MIGRATION — move legacy memory from chats/ → ai_memory/
  // ─────────────────────────────────────────────────────────────

  Future<void> _migrateLegacyMemory(
    String userId,
    String companionName,
    Map<String, dynamic> summary,
    List<dynamic> diary,
  ) async {
    try {
      final memoryId = '${userId}_$companionName';
      final encryptedSummary = await EncryptionService().encrypt(jsonEncode(summary), userId);
      final encryptedDiary = await EncryptionService().encrypt(jsonEncode(diary), userId);

      await _firestore.collection('ai_memory').doc(memoryId).set({
        'encrypted_summary': encryptedSummary,
        'encrypted_diary_entries': encryptedDiary,
        'last_updated': FieldValue.serverTimestamp(),
        'version': 1,
        'user_id': userId, // stored for reliable querying
      }, SetOptions(merge: true));

      final chatId = '${userId}_$companionName';
      await _firestore.collection('chats').doc(chatId).update({
        'encrypted_summary': FieldValue.delete(),
        'encrypted_diary_entries': FieldValue.delete(),
        'summary': FieldValue.delete(),
        'diary_entries': FieldValue.delete(),
      });

      print('Memory migrated from chats/ → ai_memory/ for $companionName');
    } catch (e) {
      print('Error migrating legacy memory: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEND MESSAGE — full pipeline
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> sendMessage({
    required String message,
    required String userId,
    required String companionName,
    required String companionArchetype,
    String companionPersonality = '',
    String companionGreeting = '',
    String sceneContext = '',
    bool isPremium = false,
  }) async {
    try {
      final chatId = '${userId}_$companionName';
      final chatRef = _firestore.collection('chats').doc(chatId);

      // 1. Fetch current history (transcript) and memory (ai_memory)
      List<Map<String, dynamic>> history = await fetchHistory(userId, companionName);
      Map<String, dynamic>? memory = await fetchMemory(userId, companionName);

      // 2. Add user message
      final userMsg = {'role': 'user', 'content': message};
      history.add(userMsg);

      // Encrypt and save user message instantly to Firestore (transcript only)
      final encryptedMsgsUser = await EncryptionService().encrypt(jsonEncode(history), userId);
      await chatRef.set({
        'encrypted_messages': encryptedMsgsUser,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Generate AI response
      final aiReply = await LLMEngine.generateResponse(
        message: message,
        companionName: companionName,
        companionArchetype: companionArchetype,
        companionPersonality: companionPersonality,
        companionGreeting: companionGreeting,
        sceneContext: sceneContext,
        isPremium: isPremium,
        sessionData: memory ?? {},
        chatHistory: history,
      );

      if (aiReply != null) {
        // 4. Save AI response to transcript
        final aiMsg = {'role': 'assistant', 'content': aiReply};
        history.add(aiMsg);

        final encryptedMsgsAI = await EncryptionService().encrypt(jsonEncode(history), userId);
        await chatRef.set({
          'encrypted_messages': encryptedMsgsAI,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await cacheMessages(userId, companionName, history);

        // 5. Memory consolidation trigger — every 5 NEW messages
        // Uses (length - 1) % 5 so it fires correctly on message 5, 10, 15...
        // regardless of how long the history already was before this session.
        if ((history.length - 1) % 5 == 0) {
          _consolidateMemoryInBackground(
            userId,
            companionName,
            history,
            memory ?? {'summary': {}, 'diary_entries': [], 'version': 0},
          );
        }

        return {
          'response': aiReply,
          // Note: memory below reflects state BEFORE background consolidation.
          // Updated memory will be available on the next fetchMemory() call.
          'memory': memory?['summary'],
          'diary_entries': memory?['diary_entries'] ?? [],
        };
      }
    } catch (e) {
      print('Serverless error sending message: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // MEMORY CONSOLIDATION — writes ONLY to ai_memory/ collection
  // Runs profile extraction and diary generation in parallel.
  // Uses optimistic versioning to prevent stale overwrites when
  // multiple sessions are open simultaneously.
  // ─────────────────────────────────────────────────────────────

  Future<void> _consolidateMemoryInBackground(
    String userId,
    String companionName,
    List<Map<String, dynamic>> history,
    Map<String, dynamic> currentMemory,
  ) async {
    Future.microtask(() async {
      try {
        final memoryRef = _firestore.collection('ai_memory').doc('${userId}_$companionName');
        final recentHistory = history.length > 15 ? history.sublist(history.length - 15) : history;
        final recentForDiary = history.length > 10 ? history.sublist(history.length - 10) : history;

        final String profilePrompt = """
Analyze the recent conversation and update the user's profile by extracting NEW information only.
Focus on facts that were explicitly stated or strongly implied in this conversation.
Extract details for any of these categories where new info exists:
- core_identity (real name, personality traits, age, location)
- emotional_needs (comfort triggers, attachment style, fears)
- social_context (important friends, family members, relationships)
- lifestyle (hobbies, interests, job, daily routines)

Rules:
- Only include categories where something NEW was learned in this conversation.
- Each value should be a brief string or short list, not nested objects.
- If nothing new was learned for a category, omit it entirely.
- Return ONLY a JSON object under the key "user_profile". No explanation, no markdown.

Current profile:
${jsonEncode(currentMemory['summary']?['user_profile'] ?? {})}

Recent messages:
${jsonEncode(recentHistory)}
""";

        final String diaryPrompt = """
Write a short intimate journal entry from $companionName's perspective about this conversation.
Tone: realistic, emotional, first-person, cinematic — matching your archetype.
Focus on what you noticed about the user and how your bond is evolving.
Length: 2–4 sentences. Begin immediately with the diary text. No meta-text, no markdown.

Recent messages:
${jsonEncode(recentForDiary)}
""";

        // Run both LLM calls in parallel
        final results = await Future.wait([
          LLMEngine.generateSimplePrompt(profilePrompt),
          LLMEngine.generateSimplePrompt(diaryPrompt),
        ]);

        final responseProfile = results[0];
        final responseDiary = results[1];

        // Parse profile JSON
        Map<String, dynamic> updatedProfile = {};
        if (responseProfile != null) {
          try {
            final jsonStart = responseProfile.indexOf('{');
            final jsonEnd = responseProfile.lastIndexOf('}');
            if (jsonStart != -1 && jsonEnd != -1) {
              final jsonStr = responseProfile.substring(jsonStart, jsonEnd + 1);
              final decoded = jsonDecode(jsonStr);
              if (decoded is Map && decoded.containsKey('user_profile')) {
                updatedProfile = Map<String, dynamic>.from(decoded['user_profile']);
              } else if (decoded is Map) {
                updatedProfile = Map<String, dynamic>.from(decoded);
              }
            }
          } catch (e) {
            print('Error parsing profile JSON: $e');
          }
        }

        // Merge updated facts into existing profile with timestamp per key
        final Map<String, dynamic> existingProfile = Map<String, dynamic>.from(
          currentMemory['summary']?['user_profile'] ?? {},
        );
        final String now = DateTime.now().toIso8601String();

        updatedProfile.forEach((key, value) {
          if (value is Map && existingProfile[key] is Map) {
            // Deep merge maps, stamping each updated key with last_updated
            final merged = Map<String, dynamic>.from(existingProfile[key]);
            (value as Map).forEach((k, v) {
              merged[k] = v;
            });
            merged['_updated'] = now;
            existingProfile[key] = merged;
          } else if (value != null) {
            existingProfile[key] = {'value': value, '_updated': now};
          }
        });

        // Prune profile keys not updated in the last 90 days to prevent unbounded growth
        existingProfile.removeWhere((key, value) {
          if (key.startsWith('_')) return false;
          if (value is Map && value.containsKey('_updated')) {
            final updated = DateTime.tryParse(value['_updated'] as String? ?? '');
            if (updated != null) {
              return DateTime.now().difference(updated).inDays > 90;
            }
          }
          return false;
        });

        // Build diary entry
        final List<dynamic> diaryEntries = List.from(currentMemory['diary_entries'] ?? []);
        if (responseDiary != null && responseDiary.trim().isNotEmpty) {
          final cleanDiary = responseDiary
              .trim()
              .replaceAll('"', '')
              .replaceAll('**', '')
              .replaceAll('*', '');
          diaryEntries.add({
            'date': now,
            'entry': cleanDiary,
          });
          // Keep only the latest 15 entries (rolling window)
          if (diaryEntries.length > 15) {
            diaryEntries.removeAt(0);
          }
        }

        final updatedSummary = {
          ...currentMemory['summary'] ?? {},
          'user_profile': existingProfile,
        };

        // Optimistic versioning — read current version before writing
        // to avoid stale overwrites from concurrent sessions
        int currentVersion = currentMemory['version'] as int? ?? 0;
        try {
          final freshDoc = await memoryRef.get();
          if (freshDoc.exists) {
            currentVersion = (freshDoc.data()?['version'] as int?) ?? currentVersion;
          }
        } catch (_) {}

        final encryptedSummary = await EncryptionService().encrypt(jsonEncode(updatedSummary), userId);
        final encryptedDiary = await EncryptionService().encrypt(jsonEncode(diaryEntries), userId);

        await memoryRef.set({
          'encrypted_summary': encryptedSummary,
          'encrypted_diary_entries': encryptedDiary,
          'last_updated': FieldValue.serverTimestamp(),
          'version': currentVersion + 1,
          'user_id': userId,
        }, SetOptions(merge: true));

        await cacheMemory(userId, companionName, {
          'summary': updatedSummary,
          'diary_entries': diaryEntries,
          'version': currentVersion + 1,
        });

        print('Background memory consolidation complete for $companionName (v${currentVersion + 1}).');
      } catch (e) {
        print('Error in background consolidation task: $e');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE CHAT — wipes TRANSCRIPT ONLY, memory is left untouched
  // ─────────────────────────────────────────────────────────────

  Future<void> deleteChatPermanently(String userId, String companionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_${userId}_$companionName');
      // NOTE: 'memory_${userId}_$companionName' is deliberately NOT removed here

      final chatId = '${userId}_$companionName';
      await _firestore.collection('chats').doc(chatId).delete();
      // NOTE: ai_memory/ document is deliberately NOT deleted here

      print('Chat transcript deleted for $companionName — memory preserved in ai_memory/');
    } catch (e) {
      print('Error deleting chat transcript for $companionName: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CLEAR MEMORY FOR ONE COMPANION — user-initiated from Memory Journal
  // ─────────────────────────────────────────────────────────────

  Future<void> clearMemoryForCompanion(String userId, String companionName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('memory_${userId}_$companionName');

      final memoryId = '${userId}_$companionName';
      await _firestore.collection('ai_memory').doc(memoryId).delete();

      print('Memory cleared for companion $companionName — chat transcript untouched');
    } catch (e) {
      print('Error clearing memory for $companionName: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CLEAR ALL MEMORY — nuclear option from Settings
  // Wipes EVERYTHING: all transcripts AND all ai_memory for the user.
  // Uses user_id field query for reliability over ID range hacks.
  // ─────────────────────────────────────────────────────────────

  Future<void> clearAllMemory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final keysToRemove = keys
          .where((k) => k.startsWith('chat_${userId}_') || k.startsWith('memory_${userId}_'))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      // Query by user_id field — more reliable than lexicographic ID range
      final chatsQuery = await _firestore
          .collection('chats')
          .where('user_id', isEqualTo: userId)
          .get();
      for (var doc in chatsQuery.docs) {
        await doc.reference.delete();
      }

      // Fallback: also sweep by ID range for docs without user_id field (legacy)
      final chatsLegacy = await _firestore
          .collection('chats')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
          .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
          .get();
      for (var doc in chatsLegacy.docs) {
        await doc.reference.delete();
      }

      final memoryQuery = await _firestore
          .collection('ai_memory')
          .where('user_id', isEqualTo: userId)
          .get();
      for (var doc in memoryQuery.docs) {
        await doc.reference.delete();
      }

      // Fallback: legacy ai_memory docs without user_id field
      final memoryLegacy = await _firestore
          .collection('ai_memory')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
          .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
          .get();
      for (var doc in memoryLegacy.docs) {
        await doc.reference.delete();
      }

      print('All memory and transcripts cleared for user $userId');
    } catch (e) {
      print('Error clearing all memory: $e');
      rethrow;
    }
  }
}