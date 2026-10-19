import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/local_database.dart';
import 'chat_screen.dart';
import 'devices_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = LocalDatabase.instance;
  final bt = BluetoothService.instance;
  List<Map<String, Object?>> chats = [];
  String userName = 'مستخدم';
  StreamSubscription? subscription;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = bt.events.listen((e) async {
      if (e['type'] == 'message' && e['address'] != null) {
        final address = '${e['address']}';
        final body = '${e['message'] ?? ''}';
        await db.saveMessage(
          address: address,
          sender: '${e['name'] ?? 'جهة اتصال'}',
          body: body,
          isMine: false,
        );
        if (mounted) _load();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final rows = await db.conversations();
    if (!mounted) return;
    setState(() {
      userName = p.getString('name') ?? 'مستخدم';
      chats = rows;
    });
  }

  Future<void> _settings() async {
    final p = await SharedPreferences.getInstance();
    final controller = TextEditingController(text: userName);
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: const Text('الإعدادات'),
      content: TextField(controller: controller,
        decoration: const InputDecoration(labelText: 'اسم المستخدم')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c),
          child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          final value = controller.text.trim();
          if (value.isNotEmpty) await p.setString('name', value);
          if (c.mounted) Navigator.pop(c);
          await _load();
        }, child: const Text('حفظ')),
      ],
    ));
    controller.dispose();
  }

  Future<void> _openDevices() async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => const DevicesScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلوساب'),
        actions: [
          IconButton(tooltip: 'الأجهزة', onPressed: _openDevices,
            icon: const Icon(Icons.bluetooth_searching)),
          IconButton(tooltip: 'الإعدادات', onPressed: _settings,
            icon: const Icon(Icons.settings)),
        ],
      ),
      body: chats.isEmpty
        ? Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline, size: 72,
                color: Colors.grey),
              const SizedBox(height: 12),
              const Text('لا توجد محادثات بعد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('افتح الأجهزة المقترنة لبدء محادثة عبر البلوتوث.',
                textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _openDevices,
                icon: const Icon(Icons.bluetooth),
                label: const Text('العثور على الأجهزة')),
            ]),
          ))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
              itemBuilder: (context, i) {
                final c = chats[i];
                final address = '${c['address']}';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  leading: CircleAvatar(
                    radius: 27,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.person),
                  ),
                  title: Text('${c['name'] ?? 'جهة اتصال'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${c['last_message'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        address: address,
                        peerName: '${c['name'] ?? 'جهة اتصال'}',
                        userName: userName,
                      )));
                    await _load();
                  },
                );
              },
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDevices,
        child: const Icon(Icons.message),
      ),
    );
  }
}