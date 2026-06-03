import 'package:flutter/material.dart';

class MusicRoomSpace extends StatelessWidget {
  const MusicRoomSpace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.music_note, size: 80, color: Colors.white70),
          SizedBox(height: 20),
          Text(
            'Shared Music Room',
            style: TextStyle(fontSize: 24, color: Colors.white70),
          ),
          SizedBox(height: 20),
          Text(
            'Play a soft jazz playlist together... (placeholder)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
