import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'emotional_space.dart';
import '../models/companion.dart';

class EmotionalSpaceScreen extends StatefulWidget {
  final EmotionalSpace space;
  final Companion companion;

  const EmotionalSpaceScreen({Key? key, required this.space, required this.companion}) : super(key: key);

  @override
  State<EmotionalSpaceScreen> createState() => _EmotionalSpaceScreenState();
}

class _EmotionalSpaceScreenState extends State<EmotionalSpaceScreen> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playAmbient();
  }

  Future<void> _playAmbient() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource(widget.space.ambientAudioAsset.replaceFirst('assets/', '')));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: widget.space.themeColor,
        title: Text(widget.space.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: widget.space.builder(context),
    );
  }
}
