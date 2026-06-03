import 'package:flutter/material.dart';
import '../models/scene.dart';

class SceneManager {
  static const List<ChatScene> scenes = [
    ChatScene(
      id: 'default',
      name: 'Midnight Bioluminescence',
      backgroundGradient: [Color(0xFF09090E), Color(0xFF151522)],
      accentColor: Color(0xFF00FFCC), // Bioluminescence
      particleType: ParticleType.stars,
      promptContext: 'A dark, atmospheric void with subtle glowing bioluminescence.',
      isPremium: false,
    ),
    ChatScene(
      id: 'rainy_apartment',
      name: 'Rainy Apartment',
      backgroundGradient: [Color(0xFF12141A), Color(0xFF1E242B)],
      accentColor: Color(0xFF6B8FB5),
      particleType: ParticleType.rain,
      promptContext: 'You are in a high-rise apartment at night. Heavy rain is hitting the glass windows.',
      isPremium: false,
    ),
    ChatScene(
      id: 'midnight_drive',
      name: 'Midnight Drive',
      backgroundGradient: [Color(0xFF050505), Color(0xFF1B0A26)],
      accentColor: Color(0xFFFF2A6D), // Neon Pink
      particleType: ParticleType.neon,
      promptContext: 'You are driving a car late at night through a cyberpunk city. Neon lights flash by.',
      isPremium: true,
    ),
    ChatScene(
      id: 'vampire_castle',
      name: 'Vampire Castle',
      backgroundGradient: [Color(0xFF14080A), Color(0xFF2E0911)],
      accentColor: Color(0xFFD91636), // Blood Red
      particleType: ParticleType.fog,
      promptContext: 'You are in an ancient, candlelit vampire castle. Shadows dance on the stone walls.',
      isPremium: true,
    ),
  ];

  static ChatScene getSceneById(String id) {
    return scenes.firstWhere((s) => s.id == id, orElse: () => scenes[0]);
  }
}
