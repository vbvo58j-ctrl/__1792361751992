import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool mine;
  const MessageBubble({super.key, required this.text, required this.mine});

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFD9FDD3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    ),
  );
}