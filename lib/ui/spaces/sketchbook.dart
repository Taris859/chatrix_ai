import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SketchbookSpace extends StatefulWidget {
  const SketchbookSpace({Key? key}) : super(key: key);

  @override
  State<SketchbookSpace> createState() => _SketchbookSpaceState();
}

class _SketchbookSpaceState extends State<SketchbookSpace> {
  final SignatureController _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.white70);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sketchbook', style: TextStyle(fontSize: 24, color: Colors.white70)),
          const SizedBox(height: 20),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
            onPressed: () => setState(() => _controller.clear()),
            icon: const Icon(Icons.clear, color: Colors.white),
            label: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
