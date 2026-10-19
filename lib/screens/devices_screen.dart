import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../services/bluetooth_service.dart';
import '../services/local_database.dart';
import 'chat_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final bt = BluetoothService.instance;
  final db = LocalDatabase.instance;
  List<BlosabDevice> devices = [];
  bool loading = false;
  String? connecting;

  Future<void> _scan() async {
    setState(() => loading = true);
    try {
      final supported = await bt.isSupported();
      if (!supported) throw Exception('هذا الهاتف لا يدعم البلوتوث');
      if (!await bt.isEnabled()) await bt.requestEnable();
      final found = await bt.discover();
      if (mounted) setState(() => devices = found);
      if (found.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد أجهزة مقترنة. اقترن بالجهاز من إعدادات الهاتف أولاً.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر العثور على الأجهزة: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _connect(BlosabDevice d) async {
    setState(() => connecting = d.address);
    try {
      await bt.connect(d.address);
      await db.saveConversation(address: d.address, name: d.name);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        address: d.address, peerName: d.name, userName: 'مستخدم')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاتصال: $e')));
    } finally {
      if (mounted) setState(() => connecting = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أجهزة البلوتوث'), actions: [
      IconButton(onPressed: loading ? null : _scan,
        icon: const Icon(Icons.refresh)),
    ]),
    body: loading && devices.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : devices.isEmpty
        ? const Center(child: Text('لا توجد أجهزة مقترنة'))
        : ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, i) {
              final d = devices[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.bluetooth)),
                title: Text(d.name),
                subtitle: Text(d.address),
                trailing: connecting == d.address
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
                onTap: connecting == null ? () => _connect(d) : null,
              );
            },
          ),
  );
}