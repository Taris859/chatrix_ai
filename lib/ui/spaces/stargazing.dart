import 'package:flutter/material.dart';

class StargazingSpace extends StatelessWidget {
  const StargazingSpace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.nights_stay, size: 80, color: Colors.white70),
          SizedBox(height: 20),
          Text(
            'Stargazing',
            style: TextStyle(fontSize: 24, color: Colors.white70),
          ),
          SizedBox(height: 20),
          Text(
            'Watch the night sky together... (placeholder)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
