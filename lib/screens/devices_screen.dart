import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool loading = false, bluetoothEnabled = false, bluetoothSupported = true;
  String? connecting, errorMessage;

  @override
  void initState() { super.initState(); _scan(); }

  Future<void> _scan() async {
    if (loading) return;
    setState(() { loading = true; errorMessage = null; });
    try {
      final supported = await bt.isSupported();
      if (!mounted) return;
      setState(() => bluetoothSupported = supported);
      if (!supported) throw Exception('هذا الهاتف لا يدعم البلوتوث');
      var enabled = await bt.isEnabled();
      if (!enabled) { await bt.requestEnable(); enabled = await bt.isEnabled(); }
      if (!mounted) return;
      setState(() => bluetoothEnabled = enabled);
      if (!enabled) { setState(() { errorMessage = 'شغّل البلوتوث ثم اضغط تحديث.'; devices = []; }); return; }
      await bt.startServer();
      final found = await bt.discover();
      if (!mounted) return;
      setState(() { devices = found; errorMessage = found.isEmpty ? 'لا توجد أجهزة مقترنة. اقترن بالهاتف الآخر من إعدادات Android.' : null; });
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'تعذر العثور على الأجهزة: $e');
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _connect(BlosabDevice device) async {
    if (connecting != null) return;
    setState(() { connecting = device.address; errorMessage = null; });
    try {
      await bt.connect(device.address);
      await db.saveConversation(address: device.address, name: device.name);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        address: device.address, peerName: device.name, userName: prefs.getString('name') ?? 'مستخدم')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاتصال: $e')));
    } finally { if (mounted) setState(() => connecting = null); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بلوساب - أجهزة البلوتوث'), actions: [
      IconButton(onPressed: loading ? null : _scan, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
    ]),
    body: Column(children: [
      if (bluetoothSupported) Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity,
        child: FilledButton.icon(onPressed: loading ? null : _scan,
          icon: Icon(bluetoothEnabled ? Icons.bluetooth_connected : Icons.bluetooth),
          label: Text(loading ? 'جارٍ الفحص...' : 'تحديث الأجهزة')))),
      if (errorMessage != null) Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      Expanded(child: loading && devices.isEmpty ? const Center(child: CircularProgressIndicator()) :
        devices.isEmpty ? const Center(child: Text('لا توجد أجهزة لعرضها')) :
        RefreshIndicator(onRefresh: _scan, child: ListView.builder(itemCount: devices.length, itemBuilder: (context, i) {
          final d = devices[i];
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.bluetooth)), title: Text(d.name), subtitle: Text(d.address),
            trailing: connecting == d.address ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
            onTap: connecting == null ? () => _connect(d) : null);
        }))),
    ]),
  );
}