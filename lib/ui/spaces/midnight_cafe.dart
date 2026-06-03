import 'package:flutter/material.dart';

class MidnightCafeSpace extends StatelessWidget {
  const MidnightCafeSpace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.coffee, size: 80, color: Colors.white70),
          SizedBox(height: 20),
          Text(
            'Midnight Café',
            style: TextStyle(fontSize: 24, color: Colors.white70),
          ),
          SizedBox(height: 20),
          Text(
            'Bake pastries together in the quiet night... (placeholder)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
