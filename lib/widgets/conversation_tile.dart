import 'package:flutter/material.dart';

class ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final VoidCallback onTap;
  const ConversationTile({
    super.key, required this.name, required this.lastMessage, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.person)),
    title: Text(name),
    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}