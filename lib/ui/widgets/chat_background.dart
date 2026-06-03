// lib/ui/widgets/chat_background.dart
import 'package:flutter/material.dart';

/// A simple widget that displays a full‑screen background image with a
/// dark overlay to keep foreground text readable.
class ChatBackground extends StatelessWidget {
  final String imageAsset;
  const ChatBackground({Key? key, required this.imageAsset}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        // Darken the image slightly for better text contrast.
        color: Colors.black.withOpacity(0.4),
        colorBlendMode: BlendMode.darken,
      ),
    );
  }
}
