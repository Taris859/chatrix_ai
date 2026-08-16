import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Gender classification for companion filtering
enum CompanionGender { male, female, nonBinary }

class Companion {
  final String id;
  final String name;
  final String archetype;
  final String personality;
  final String greeting;
  final Color themeColor;
  final bool isPremium;
  final CompanionGender gender;
  final List<String> tags;
  final String? creatorId;
  final String? voiceId;
  final String? avatarName;
  final bool isPublic;
  final String? customImageUrl;

  // New character specific metadata fields
  final String? sleepingHours;
  final String? favoriteDrink;
  final String? favoriteSongs;
  final String? favoriteBooks;
  final String? birthday;
  final String? petPeeves;
  final String? loveLanguage;
  final String? randomHabits;
  final String? favoriteFood;
  final String? comfortItem;
  final String? personalGoals;
  final String? hiddenFear;
  final String? trustSecret;

  /// Automatically resolves asset image path if one exists
  String? get imagePath {
    const allowedImages = [
      'Alistair', 'Aria', 'Arthur', 'Aarav', 'Bella', 'Damien',
      'Dante', 'Dimitri', 'Ethan', 'Evelyn', 'Haru', 'Iris',
      'Jade', 'Julian', 'Kaelen', 'Lana', 'Leo', 'Lucas',
      'Ryker', 'Seraphina', 'Valentina',
      'Kabir', 'Vihaan', 'Devansh', 'Rohan', 'Arjun', 'Samarth',
      'Aditya', 'Ishaan', 'Reyansh', 'Aryan',
      'Lyra', 'Noah', 'Kael', 'Airi', 'Zero', 'Elise', 'Mira', 'Atlas', 'Kai', 'Ely'
    ];

    String? lookupName = avatarName;
    if (lookupName == null || lookupName.isEmpty) {
      var parts = name.split(' ');
      var cleanName = parts.first;
      if (cleanName.toLowerCase() == 'dr.' || cleanName.toLowerCase() == 'professor') {
        if (parts.length > 1) {
          cleanName = parts[1];
        }
      }
      lookupName = cleanName.replaceAll("'", "").replaceAll('"', '');
    }

    for (final img in allowedImages) {
      if (img.toLowerCase() == lookupName.toLowerCase()) {
        return 'assets/images/$img.png';
      }
    }
    
    if (avatarName != null && avatarName!.isNotEmpty) {
      return 'assets/images/$avatarName.png';
    }
    return null;
  }

  /// Returns initials for fallback avatar (first letter of first + last name)
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// A gradient for fallback avatars based on theme color
  LinearGradient get fallbackGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        themeColor.withOpacity(0.35),
        themeColor.withOpacity(0.10),
      ],
    );
  }

  /// Renders either custom image (Base64/Network) or fallback assets/initials
  Widget buildAvatar({double radius = 24, Color? fallbackColor}) {
    if (customImageUrl != null && customImageUrl!.isNotEmpty) {
      if (customImageUrl!.startsWith('data:image')) {
        try {
          final String base64Str = customImageUrl!.split(',').last;
          final bytes = base64.decode(base64Str);
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
            backgroundColor: Colors.grey[900],
          );
        } catch (e) {
          debugLog("Error parsing base64 avatar: $e", tag: "Companion");
        }
      } else if (customImageUrl!.startsWith('http')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(customImageUrl!),
          backgroundColor: Colors.grey[900],
        );
      }
    }
    
    final path = imagePath;
    if (path != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(path),
        backgroundColor: Colors.grey[900],
      );
    }
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: (fallbackColor ?? themeColor).withOpacity(0.2),
      child: Text(
        initials, 
        style: TextStyle(
          color: fallbackColor ?? themeColor, 
          fontWeight: FontWeight.bold, 
          fontSize: radius * 0.7
        )
      ),
    );
  }

  Companion({
    required this.id,
    required this.name,
    required this.archetype,
    required this.personality,
    required this.greeting,
    required this.themeColor,
    required this.isPremium,
    this.gender = CompanionGender.male,
    this.tags = const [],
    this.creatorId,
    this.voiceId,
    this.avatarName,
    this.isPublic = true,
    this.customImageUrl,
    this.sleepingHours,
    this.favoriteDrink,
    this.favoriteSongs,
    this.favoriteBooks,
    this.birthday,
    this.petPeeves,
    this.loveLanguage,
    this.randomHabits,
    this.favoriteFood,
    this.comfortItem,
    this.personalGoals,
    this.hiddenFear,
    this.trustSecret,
  });

  factory Companion.fromFirestore(Map<String, dynamic> data, String id, {Companion? fallback}) {
    debugLog("Companion.fromFirestore [id=$id]", tag: "Companion");
    Color color = fallback?.themeColor ?? Colors.deepPurpleAccent;
    final rawThemeColor = data['theme_color'] ?? data['ThemeColor'] ?? data['themeColor'];
    if (rawThemeColor != null) {
      String hex = rawThemeColor.toString().replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      try {
        color = Color(int.parse(hex, radix: 16));
      } catch (e) {
        // Keep default color
      }
    }

    CompanionGender gender = fallback?.gender ?? CompanionGender.male;
    final rawGender = data['gender'] ?? data['Gender'];
    if (rawGender != null) {
      switch (rawGender.toString().toLowerCase()) {
        case 'female':
          gender = CompanionGender.female;
          break;
        case 'non_binary':
        case 'nonbinary':
        case 'non-binary':
          gender = CompanionGender.nonBinary;
          break;
        default:
          gender = CompanionGender.male;
      }
    }

    List<String> tags = fallback?.tags ?? [];
    final rawTags = data['tags'] ?? data['Tags'];
    if (rawTags != null && rawTags is List) {
      tags = List<String>.from(rawTags);
    }

    return Companion(
      id: id,
      name: data['name'] ?? data['Name'] ?? data['displayName'] ?? data['full_name'] ?? data['character_name'] ?? fallback?.name ?? 'Unknown',
      archetype: data['archetype'] ?? data['Archetype'] ?? data['role'] ?? fallback?.archetype ?? 'Companion',
      personality: data['personality'] ?? data['Personality'] ?? fallback?.personality ?? '',
      greeting: data['greeting'] ?? data['Greeting'] ?? fallback?.greeting ?? 'I was waiting for you.',
      themeColor: color,
      isPremium: data['premium_only'] ?? data['premiumOnly'] ?? data['isPremium'] ?? fallback?.isPremium ?? false,
      gender: gender,
      tags: tags,
      creatorId: data['creatorId'] ?? data['created_by'] ?? data['creator_id'] ?? fallback?.creatorId,
      voiceId: data['voice_id'] ?? data['voiceId'] ?? fallback?.voiceId,
      avatarName: data['avatar_name'] ?? data['avatarName'] ?? data['image_name'] ?? fallback?.avatarName,
      isPublic: data['is_public'] ?? data['isPublic'] ?? fallback?.isPublic ?? true,
      customImageUrl: data['custom_image_url'] ?? data['customImageUrl'] ?? fallback?.customImageUrl,
      sleepingHours: data['sleeping_hours'] ?? data['sleepingHours'] ?? fallback?.sleepingHours,
      favoriteDrink: data['favorite_drink'] ?? data['favoriteDrink'] ?? fallback?.favoriteDrink,
      favoriteSongs: data['favorite_songs'] ?? data['favoriteSongs'] ?? fallback?.favoriteSongs,
      favoriteBooks: data['favorite_books'] ?? data['favoriteBooks'] ?? fallback?.favoriteBooks,
      birthday: data['birthday'] ?? fallback?.birthday,
      petPeeves: data['pet_peeves'] ?? data['petPeeves'] ?? fallback?.petPeeves,
      loveLanguage: data['love_language'] ?? data['loveLanguage'] ?? fallback?.loveLanguage,
      randomHabits: data['random_habits'] ?? data['randomHabits'] ?? fallback?.randomHabits,
      favoriteFood: data['favorite_food'] ?? data['favoriteFood'] ?? fallback?.favoriteFood,
      comfortItem: data['comfort_item'] ?? data['comfortItem'] ?? fallback?.comfortItem,
      personalGoals: data['personal_goals'] ?? data['personalGoals'] ?? fallback?.personalGoals,
      hiddenFear: data['hidden_fear'] ?? data['hiddenFear'] ?? fallback?.hiddenFear,
      trustSecret: data['trust_secret'] ?? data['trustSecret'] ?? fallback?.trustSecret,
    );
  }
}
