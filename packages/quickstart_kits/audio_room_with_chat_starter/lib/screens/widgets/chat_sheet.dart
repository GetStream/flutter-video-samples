import 'package:flutter/material.dart';

/// Bottom sheet that will contain the in-room chat UI.
/// For now it's a scaffolded container. You'll plug Chat widgets later.
class ChatSheet extends StatelessWidget {
  const ChatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: const Center(child: Text('TODO: Add Stream chat components here')),
    );
  }
}
