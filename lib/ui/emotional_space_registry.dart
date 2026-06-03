import 'package:flutter/material.dart';
import 'emotional_space.dart';
import '../models/companion.dart';
import 'spaces/quiet_chess.dart';
import 'spaces/music_room.dart';
import 'spaces/sketchbook.dart';
import 'spaces/midnight_cafe.dart';
import 'spaces/stargazing.dart';

class EmotionalSpaceRegistry {
  // Define all spaces
  static final List<EmotionalSpace> _spaces = [
    EmotionalSpace(
      id: 'quiet_chess',
      title: 'Quiet Chess',
      builder: (context) => const QuietChessSpace(),
      themeColor: const Color(0xFF8FBC8F), // Arthur soft green
      ambientAudioAsset: 'assets/audio/rain_jazz.mp3',
    ),
    EmotionalSpace(
      id: 'music_room',
      title: 'Shared Music Room',
      builder: (context) => const MusicRoomSpace(),
      themeColor: const Color(0xFF8B0000), // Dante dark
      ambientAudioAsset: 'assets/audio/soft_jazz.mp3',
    ),
    EmotionalSpace(
      id: 'sketchbook',
      title: 'Sketchbook',
      builder: (context) => const SketchbookSpace(),
      themeColor: const Color(0xFFC71585), // Valentina pink
      ambientAudioAsset: 'assets/audio/pencil_soft.mp3',
    ),
    EmotionalSpace(
      id: 'midnight_cafe',
      title: 'Midnight Café',
      builder: (context) => const MidnightCafeSpace(),
      themeColor: const Color(0xFFFFB300), // Kaelen warm
      ambientAudioAsset: 'assets/audio/cafe_ambient.mp3',
    ),
    EmotionalSpace(
      id: 'stargazing',
      title: 'Stargazing',
      builder: (context) => const StargazingSpace(),
      themeColor: const Color(0xFF4682B4), // generic blue
      ambientAudioAsset: 'assets/audio/night_crickets.mp3',
    ),
  ];

  // Mapping of companion IDs to space IDs (adjust as needed)
  static final Map<String, String> _companionToSpaceId = {
    'arthur': 'quiet_chess',
    'dante': 'music_room',
    'leo': 'sketchbook',
    'haru': 'music_room', // fallback, can be customized later
    'valentina': 'sketchbook',
    'dimitri': 'stargazing',
    'oliver': 'midnight_cafe',
    'maya': 'stargazing',
  };

  static EmotionalSpace? getSpaceForCompanion(String companionId) {
    final spaceId = _companionToSpaceId[companionId.toLowerCase()];
    if (spaceId == null) return null;
    return _spaces.firstWhere((s) => s.id == spaceId, orElse: () => _spaces.first);
  }
}


