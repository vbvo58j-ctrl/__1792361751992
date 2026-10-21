import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bluetooth_service.dart';
import '../services/local_database.dart';
import '../services/theme_controller.dart';
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
  String userName = 'مستخدم', themeMode = 'system';
  bool previewMessages = true, notificationsEnabled = true, soundEnabled = true, loading = true;
  StreamSubscription? subscription;

  @override
  void initState() {
    super.initState(); _load();
    subscription = bt.events.listen((e) async {
      if (e['type'] != 'message') return;
      final address = e['address']?.toString();
      if (address == null || address.isEmpty) return;
      await db.saveMessage(address: address, sender: e['name']?.toString() ?? 'جهة اتصال', body: e['message']?.toString() ?? '', isMine: false);
      if (mounted) _load();
    }, onError: (_) {});
  }
  @override
  void dispose() { subscription?.cancel(); super.dispose(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance(); final rows = await db.conversations();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('name') ?? 'مستخدم'; themeMode = prefs.getString('blosab_theme') ?? 'system';
      previewMessages = prefs.getBool('blosab_preview') ?? true;
      notificationsEnabled = prefs.getBool('blosab_notifications') ?? true;
      soundEnabled = prefs.getBool('blosab_sound') ?? true; chats = rows; loading = false;
    });
  }
  Future<void> _saveName(String value) async {
    final name = value.trim(); if (name.isEmpty) return;
    final prefs = await SharedPreferences.getInstance(); await prefs.setString('name', name);
    if (mounted) { setState(() => userName = name); _message('تم حفظ اسم المستخدم'); }
  }
  Future<void> _saveTheme(String v) async { await ThemeController.instance.setTheme(v); if (mounted) setState(() => themeMode = v); }
  Future<void> _setBool(String key, bool value) async { final p = await SharedPreferences.getInstance(); await p.setBool(key, value); }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> _openDevices() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesScreen())); if (mounted) _load(); }
  Future<void> _editName() async {
    final c = TextEditingController(text: userName);
    final v = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('اسم المستخدم'), content: TextField(controller: c, maxLength: 40, autofocus: true), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ')),
    ]));
    c.dispose(); if (v != null) await _saveName(v);
  }
  Future<void> _support() async {
    final uri = Uri.parse('https://wsend.co/967737414884');
    try { if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) _message('تعذر فتح رابط الدعم'); }
    catch (_) { if (mounted) _message('تعذر فتح رابط الدعم'); }
  }
  Future<void> _settings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
      userName: userName, themeMode: themeMode, preview: previewMessages,
      notifications: notificationsEnabled, sound: soundEnabled, onEditName: _editName,
      onTheme: _saveTheme,
      onPreview: (v) async { await _setBool('blosab_preview', v); if (mounted) setState(() => previewMessages = v); },
      onNotifications: (v) async { await _setBool('blosab_notifications', v); if (mounted) setState(() => notificationsEnabled = v); },
      onSound: (v) async { await _setBool('blosab_sound', v); if (mounted) setState(() => soundEnabled = v); },
      onDevices: _openDevices, onSupport: _support,
    )));
    if (mounted) _load();
  }
  void _openChat(Map<String, Object?> c) {
    final address = c['address']?.toString() ?? ''; if (address.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(address: address, peerName: c['name']?.toString() ?? 'جهة اتصال', userName: userName))).then((_) { if (mounted) _load(); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بلوساب'), actions: [
      IconButton(tooltip: 'الأجهزة', onPressed: _openDevices, icon: const Icon(Icons.bluetooth)),
      IconButton(tooltip: 'الإعدادات', onPressed: _settings, icon: const Icon(Icons.settings)),
    ]),
    body: loading ? const Center(child: CircularProgressIndicator()) : chats.isEmpty
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forum_outlined, size: 72), const SizedBox(height: 16),
          const Text('مرحباً بك في بلوساب', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), const Text('افتح الأجهزة للاتصال بجهات الاتصال المقترنة عبر البلوتوث.', textAlign: TextAlign.center),
          const SizedBox(height: 20), FilledButton.icon(onPressed: _openDevices, icon: const Icon(Icons.bluetooth), label: const Text('فتح الأجهزة')),
        ])))
      : RefreshIndicator(onRefresh: _load, child: ListView.separated(itemCount: chats.length, separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) { final c = chats[i]; final last = c['last_message']?.toString() ?? '';
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(c['name']?.toString() ?? 'جهة اتصال'),
            subtitle: Text(previewMessages ? (last.isEmpty ? 'ابدأ المحادثة' : last) : 'لديك محادثة', maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _openChat(c));
        })),
    floatingActionButton: FloatingActionButton.extended(onPressed: _openDevices, icon: const Icon(Icons.bluetooth_searching), label: const Text('الأجهزة')),
  );
}

class SettingsScreen extends StatefulWidget {
  final String userName, themeMode;
  final bool preview, notifications, sound;
  final VoidCallback onEditName, onDevices, onSupport;
  final ValueChanged<String> onTheme;
  final ValueChanged<bool> onPreview, onNotifications, onSound;
  const SettingsScreen({super.key, required this.userName, required this.themeMode, required this.preview, required this.notifications, required this.sound, required this.onEditName, required this.onDevices, required this.onSupport, required this.onTheme, required this.onPreview, required this.onNotifications, required this.onSound});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late String theme; late bool preview, notifications, sound;
  @override
  void initState() { super.initState(); theme = widget.themeMode; preview = widget.preview; notifications = widget.notifications; sound = widget.sound; }
  String _label(String v) => v == 'dark' ? 'داكن' : v == 'light' ? 'فاتح' : 'حسب إعدادات الجهاز';
  Future<void> _chooseTheme() async {
    final v = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(title: Text('مظهر التطبيق')),
      for (final option in [('system', 'حسب إعدادات الجهاز'), ('light', 'فاتح'), ('dark', 'داكن')])
        RadioListTile<String>(value: option.$1, groupValue: theme, title: Text(option.$2), onChanged: (v) => Navigator.pop(ctx, v)),
    ])));
    if (v != null && mounted) { setState(() => theme = v); widget.onTheme(v); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: ListView(children: [
    const ListTile(title: Text('الحساب الشخصي', style: TextStyle(fontWeight: FontWeight.bold))),
    ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(widget.userName), subtitle: const Text('اسم المستخدم'), onTap: widget.onEditName),
    const Divider(), const ListTile(title: Text('المظهر والتفضيلات', style: TextStyle(fontWeight: FontWeight.bold))),
    ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('المظهر'), subtitle: Text(_label(theme)), onTap: _chooseTheme),
    SwitchListTile(title: const Text('معاينة الرسائل'), value: preview, onChanged: (v) { setState(() => preview = v); widget.onPreview(v); }),
    SwitchListTile(title: const Text('الإشعارات (تفضيل فقط)'), value: notifications, onChanged: (v) { setState(() => notifications = v); widget.onNotifications(v); }),
    SwitchListTile(title: const Text('صوت الرسائل (تفضيل فقط)'), value: sound, onChanged: (v) { setState(() => sound = v); widget.onSound(v); }),
    const Divider(), ListTile(leading: const Icon(Icons.devices), title: const Text('أجهزة البلوتوث'), onTap: widget.onDevices),
    ListTile(leading: const Icon(Icons.support_agent), title: const Text('الدعم عبر واتساب'), subtitle: const Text('يفتح رابط دعم خارجي منفصل عن محادثات البلوتوث'), onTap: widget.onSupport),
    const AboutListTile(icon: Icon(Icons.info_outline), applicationName: 'بلوساب', applicationVersion: '1.0.0', applicationLegalese: 'مراسلة نصية عبر Bluetooth Classic'),
  ]));
}