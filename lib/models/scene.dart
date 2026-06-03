import 'package:flutter/material.dart';

enum ParticleType { none, rain, fog, stars, neon }

class ChatScene {
  final String id;
  final String name;
  final List<Color> backgroundGradient;
  final Color accentColor;
  final ParticleType particleType;
  final String promptContext;
  final bool isPremium;

  const ChatScene({
    required this.id,
    required this.name,
    required this.backgroundGradient,
    required this.accentColor,
    required this.particleType,
    required this.promptContext,
    this.isPremium = false,
  });

  factory ChatScene.fromFirestore(Map<String, dynamic> data, String id) {
    Color parseColor(String? hexStr, Color fallback) {
      if (hexStr == null) return fallback;
      String hex = hexStr.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      try {
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        return fallback;
      }
    }

    List<Color> gradient = [const Color(0xFF09090E), const Color(0xFF151522)];
    if (data['background_colors'] != null) {
      List<dynamic> colors = data['background_colors'];
      if (colors.length >= 2) {
        gradient = [parseColor(colors[0], gradient[0]), parseColor(colors[1], gradient[1])];
      }
    }

    ParticleType pType = ParticleType.stars;
    if (data['particle_type'] != null) {
      switch (data['particle_type']) {
        case 'rain': pType = ParticleType.rain; break;
        case 'fog': pType = ParticleType.fog; break;
        case 'neon': pType = ParticleType.neon; break;
        case 'none': pType = ParticleType.none; break;
      }
    }

    return ChatScene(
      id: id,
      name: data['name'] ?? 'Unknown Scene',
      backgroundGradient: gradient,
      accentColor: parseColor(data['glow_color'], const Color(0xFF00FFCC)),
      particleType: pType,
      promptContext: data['mood'] ?? 'A dark atmospheric void.',
      isPremium: data['premium_only'] ?? false,
    );
  }
}
