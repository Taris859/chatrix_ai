import 'package:flutter/material.dart';

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

  /// Automatically resolves asset image path if one exists
  String? get imagePath {
    var parts = name.split(' ');
    var cleanName = parts.first;
    if (cleanName.toLowerCase() == 'dr.' || cleanName.toLowerCase() == 'professor') {
      if (parts.length > 1) {
        cleanName = parts[1];
      }
    }
    // Also handle names with quotes like Evelyn 'Evie'
    final normalizedName = cleanName.replaceAll("'", "").replaceAll('"', '');
    const allowedImages = [
      'Alistair', 'Aria', 'Arthur', 'Aarav', 'Bella', 'Damien',
      'Dante', 'Dimitri', 'Ethan', 'Evelyn', 'Haru', 'Iris',
      'Jade', 'Julian', 'Kaelen', 'Lana', 'Leo', 'Lucas',
      'Ryker', 'Seraphina', 'Valentina',
      'Kabir', 'Vihaan', 'Devansh', 'Rohan', 'Arjun', 'Samarth',
      'Aditya', 'Ishaan', 'Reyansh', 'Aryan',
    ];
    for (final img in allowedImages) {
      if (img.toLowerCase() == normalizedName.toLowerCase()) {
        return 'assets/images/$img.png';
      }
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
  });

  factory Companion.fromFirestore(Map<String, dynamic> data, String id, {Companion? fallback}) {
    print("Companion.fromFirestore [id=$id] - RAW DATA: $data");
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
    );
  }
}
