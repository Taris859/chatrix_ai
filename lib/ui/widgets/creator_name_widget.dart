import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/creator_profile_screen.dart';

class CreatorNameWidget extends StatefulWidget {
  final String creatorId;
  final TextStyle? style;

  const CreatorNameWidget({
    Key? key,
    required this.creatorId,
    this.style,
  }) : super(key: key);

  @override
  State<CreatorNameWidget> createState() => _CreatorNameWidgetState();
}

class _CreatorNameWidgetState extends State<CreatorNameWidget> {
  static final Map<String, String> _nameCache = {};
  String _displayName = "Loading...";

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  @override
  void didUpdateWidget(CreatorNameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creatorId != widget.creatorId) {
      _resolveName();
    }
  }

  Future<void> _resolveName() async {
    if (_nameCache.containsKey(widget.creatorId)) {
      if (mounted) {
        setState(() {
          _displayName = _nameCache[widget.creatorId]!;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorId)
          .get();
      
      String name = "Official Companion";
      if (doc.exists && doc.data() != null) {
        name = doc.data()?['username'] ?? 'Wanderer';
      }
      
      _nameCache[widget.creatorId] = name;
      
      if (mounted) {
        setState(() {
          _displayName = name;
        });
      }
    } catch (e) {
      print("Error resolving creator name: $e");
      if (mounted) {
        setState(() {
          _displayName = "Custom Companion";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorProfileScreen(creatorId: widget.creatorId),
          ),
        );
      },
      child: Text(
        _displayName,
        style: widget.style ?? const TextStyle(
          color: Colors.white70,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
