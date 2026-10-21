import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/local_database.dart';

class ChatScreen extends StatefulWidget {
  final String address, peerName, userName;
  const ChatScreen({super.key, required this.address, required this.peerName, required this.userName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final db = LocalDatabase.instance;
  final bt = BluetoothService.instance;
  final input = TextEditingController();
  List<Map<String, Object?>> messages = [];
  StreamSubscription? sub;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    sub = bt.events.listen((e) async {
      if (e['type'] == 'message' && e['address'] == widget.address) {
        await db.saveMessage(address: widget.address, sender: widget.peerName, body: '${e['message'] ?? ''}', isMine: false);
        await _load();
      }
    }, onError: (_) {});
  }
  @override
  void dispose() { sub?.cancel(); input.dispose(); super.dispose(); }
  Future<void> _load() async { final rows = await db.messages(widget.address); if (mounted) setState(() => messages = rows); }
  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await bt.sendTo(widget.address, text);
      await db.saveMessage(address: widget.address, sender: widget.userName, body: text, isMine: true);
      input.clear(); await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.peerName)),
    body: Column(children: [
      Expanded(child: messages.isEmpty ? const Center(child: Text('ابدأ المحادثة بإرسال رسالة')) :
        ListView.builder(padding: const EdgeInsets.all(12), itemCount: messages.length, itemBuilder: (_, i) {
          final m = messages[i]; final mine = m['is_mine'] == 1;
          return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
            margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: mine ? const Color(0xFFD9FDD3) : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['body'] ?? ''}'), const SizedBox(height: 3),
              Text('${m['created'] ?? ''}'.replaceFirst('T', ' '), style: Theme.of(context).textTheme.labelSmall),
            ]),
          ));
        })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(),
          decoration: InputDecoration(hintText: 'اكتب رسالة', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: sending ? null : _send, icon: const Icon(Icons.send)),
      ]))),
    ]),
  );
}