import 'package:flutter/material.dart';

class EmotionalSpace {
  final String id;
  final String title;
  final WidgetBuilder builder;
  final Color themeColor;
  final String ambientAudioAsset;

  const EmotionalSpace({
    required this.id,
    required this.title,
    required this.builder,
    required this.themeColor,
    required this.ambientAudioAsset,
  });
}
