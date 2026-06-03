import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/llm_engine.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local caching for instant loading (Hybrid approach)
  Future<void> cacheMessages(String userId, String companionName, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${userId}_$companionName';
    await prefs.setString(key, jsonEncode(messages));
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String userId, String companionName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${userId}_$companionName';
    final cached = prefs.getString(key);
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> cacheMemory(String userId, String companionName, Map<String, dynamic> memoryData) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'memory_${userId}_$companionName';
    await prefs.setString(key, jsonEncode(memoryData));
  }

  Future<Map<String, dynamic>?> getCachedMemory(String userId, String companionName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'memory_${userId}_$companionName';
    final cached = prefs.getString(key);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  // Fetch History from Firestore, fallback to Cache
  Future<List<Map<String, dynamic>>> fetchHistory(String userId, String companionName) async {
    try {
      final chatId = '${userId}_$companionName';
      final doc = await _firestore.collection('chats').doc(chatId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final List<dynamic> messages = data['messages'] ?? [];
        final parsedMessages = messages.map((e) => Map<String, dynamic>.from(e)).toList();
        await cacheMessages(userId, companionName, parsedMessages);
        return parsedMessages;
      }
    } catch (e) {
      print('Firestore error fetching history: $e');
    }
    return await getCachedMessages(userId, companionName);
  }

  // Fetch Memory from Firestore, fallback to Cache
  Future<Map<String, dynamic>?> fetchMemory(String userId, String companionName) async {
    Map<String, dynamic>? memory;
    try {
      final chatId = '${userId}_$companionName';
      final doc = await _firestore.collection('chats').doc(chatId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        memory = {
          'summary': data['summary'] ?? <String, dynamic>{},
          'diary_entries': data['diary_entries'] ?? []
        };
      }
    } catch (e) {
      print('Firestore error fetching memory: $e');
    }

    if (memory == null) {
      memory = await getCachedMemory(userId, companionName) ?? {'summary': <String, dynamic>{}, 'diary_entries': []};
    }

    // 1.5 Fetch User Profile for absolute memory injection (Tiered Priority System)
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
        final bool loadSocial = random.nextDouble() > 0.3; // 70% chance to load
        final bool loadLifestyle = random.nextDouble() > 0.5; // 50% chance to load

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

  // Serverless Chat Message Sending
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
      
      // 1. Fetch current history and memory
      List<Map<String, dynamic>> history = await fetchHistory(userId, companionName);
      Map<String, dynamic>? memory = await fetchMemory(userId, companionName);
      
      // 2. Add User Message
      final userMsg = {'role': 'user', 'content': message};
      history.add(userMsg);
      
      // Save user message to Firestore instantly
      await chatRef.set({
        'messages': history,
        'last_updated': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      // 3. Generate AI Response directly from device using LLMEngine
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
        // 4. Save AI Response
        final aiMsg = {'role': 'assistant', 'content': aiReply};
        history.add(aiMsg);
        
        await chatRef.set({
          'messages': history,
          'last_updated': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        
        await cacheMessages(userId, companionName, history);

        return {
          'response': aiReply,
          'memory': memory?['summary'],
          'diary_entries': memory?['diary_entries'] ?? []
        };
      }
    } catch (e) {
      print('Serverless error sending message: $e');
    }
    return null;
  }
}
