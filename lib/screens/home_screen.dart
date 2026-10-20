
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String themeMode = 'system';

  bool previewMessages = true;
  bool notificationsEnabled = true;
  bool soundEnabled = true;
  bool loading = true;

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

        if (mounted) await _load();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final rows = await db.conversations();

      if (!mounted) return;

      setState(() {
        userName = p.getString('name') ?? 'مستخدم';
        themeMode = p.getString('blosab_theme') ?? 'system';
        previewMessages = p.getBool('blosab_preview') ?? true;
        notificationsEnabled =
            p.getBool('blosab_notifications') ?? true;
        soundEnabled = p.getBool('blosab_sound') ?? true;
        chats = rows;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
      _showMessage('تعذر تحميل البيانات المحلية');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveName(String value) async {
    final name = value.trim();
    if (name.isEmpty) {
      _showMessage('اكتب اسمًا صحيحًا');
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);

    if (!mounted) return;
    setState(() => userName = name);
    _showMessage('تم حفظ اسم المستخدم');
  }

  Future<void> _saveTheme(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('blosab_theme', value);
    if (!mounted) return;
    setState(() => themeMode = value);

    _showMessage(
      value == 'dark'
          ? 'تم حفظ اختيار الوضع الداكن'
          : value == 'light'
              ? 'تم حفظ اختيار الوضع الفاتح'
              : 'تم حفظ اختيار مظهر الهاتف',
    );
  }

  Future<void> _setPreference(
    String key,
    bool value,
    void Function(bool) update,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
    if (!mounted) return;
    setState(() => update(value));
  }

  Future<void> _openDevices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DevicesScreen()),
    );
    await _load();
  }

  Future<void> _bluetoothStatus() async {
    try {
      final supported = await bt.isSupported();
      if (!supported) {
        _showMessage('هذا الهاتف لا يدعم البلوتوث');
        return;
      }

      final enabled = await bt.isEnabled();
      if (!enabled) {
        await bt.requestEnable();
        _showMessage('وافق على تشغيل البلوتوث إذا ظهرت نافذة النظام');
      } else {
        _showMessage('البلوتوث يعمل');
      }
    } catch (_) {
      _showMessage(
        'تعذر الوصول إلى البلوتوث. تحقق من الصلاحيات وأعد بناء APK.',
      );
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://wsend.co/967737414884');

    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _showMessage('تعذر فتح رابط الدعم');
    } catch (_) {
      _showMessage('تعذر فتح رابط الدعم');
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: userName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسم المستخدم'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'الاسم الظاهر',
            hintText: 'اكتب اسمك',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text;
              if (value.trim().isEmpty) return;
              await _saveName(value);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _showSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BlosabSettingsScreen(
          userName: userName,
          themeMode: themeMode,
          previewMessages: previewMessages,
          notificationsEnabled: notificationsEnabled,
          soundEnabled: soundEnabled,
          onEditName: _editName,
          onThemeChanged: _saveTheme,
          onPreviewChanged: (v) => _setPreference(
            'blosab_preview',
            v,
            (value) => previewMessages = value,
          ),
          onNotificationsChanged: (v) => _setPreference(
            'blosab_notifications',
            v,
            (value) => notificationsEnabled = value,
          ),
          onSoundChanged: (v) => _setPreference(
            'blosab_sound',
            v,
            (value) => soundEnabled = value,
          ),
          onBluetooth: _bluetoothStatus,
          onDevices: _openDevices,
          onSupport: _openSupport,
        ),
      ),
    );

    await _load();
  }

  Future<void> _confirmClearLocalView() async {
    _showMessage(
      'لم يُحذف شيء. حذف الرسائل يتطلب إضافة دالة حذف إلى قاعدة البيانات.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'بلوساب',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'أجهزة البلوتوث',
            onPressed: _openDevices,
            icon: const Icon(Icons.bluetooth_searching),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
              ? _emptyView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 82),
                    itemBuilder: (context, i) {
                      final c = chats[i];
                      final address = '${c['address'] ?? ''}';
                      final name = '${c['name'] ?? 'جهة اتصال'}';
                      final lastMessage =
                          '${c['last_message'] ?? ''}';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        leading: CircleAvatar(
                          radius: 27,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          previewMessages
                              ? lastMessage
                              : 'لديك محادثة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                address: address,
                                peerName: name,
                                userName: userName,
                              ),
                            ),
                          );
                          await _load();
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openDevices,
        icon: const Icon(Icons.message),
        label: const Text('محادثة جديدة'),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 76,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'مرحبًا بك في بلوساب',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'ابدأ محادثة مع جهاز مقترن عبر البلوتوث.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openDevices,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('العثور على الأجهزة'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('إعدادات بلوساب'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlosabSettingsScreen extends StatelessWidget {
  const _BlosabSettingsScreen({
    required this.userName,
    required this.themeMode,
    required this.previewMessages,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.onEditName,
    required this.onThemeChanged,
    required this.onPreviewChanged,
    required this.onNotificationsChanged,
    required this.onSoundChanged,
    required this.onBluetooth,
    required this.onDevices,
    required this.onSupport,
  });

  final String userName;
  final String themeMode;
  final bool previewMessages;
  final bool notificationsEnabled;
  final bool soundEnabled;

  final VoidCallback onEditName;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onPreviewChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onBluetooth;
  final VoidCallback onDevices;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final themeLabel = switch (themeMode) {
      'dark' => 'داكن',
      'light' => 'فاتح',
      _ => 'حسب إعداد الهاتف',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات بلوساب')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: CircleAvatar(
              radius: 28,
              child: const Icon(Icons.person, size: 30),
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('الحساب الشخصي'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: onEditName,
          ),
          const Divider(height: 28),
          _sectionTitle(context, 'المظهر'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('المظهر'),
            subtitle: Text(themeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseTheme(context),
          ),
          const Divider(height: 28),
          _sectionTitle(context, 'المحادثات'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('معاينة الرسائل'),
            subtitle: const Text('إظهار نص آخر رسالة في قائمة المحادثات'),
            value: previewMessages,
            onChanged: onPreviewChanged,
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('أجهزة البلوتوث'),
            subtitle: const Text('الاتصال بالأجهزة المقترنة'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onDevices,
          ),
          const Divider(height: 28),
          _sectionTitle(context, 'الإشعارات والأصوات'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('الإشعارات'),
            subtitle: const Text('حفظ تفضيل الإشعارات داخل التطبيق'),
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('الأصوات'),
            subtitle: const Text('حفظ تفضيل أصوات التطبيق'),
            value: soundEnabled,
            onChanged: onSoundChanged,
          ),
          const Divider(height: 28),
          _sectionTitle(context, 'الاتصال والخصوصية'),
          ListTile(
            leading: const Icon(Icons.bluetooth_searching),
            title: const Text('حالة البلوتوث'),
            subtitle: const Text('التحقق من الحالة أو طلب التشغيل'),
            onTap: onBluetooth,
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('الخصوصية'),
            subtitle: Text(
              'تتم الاتصالات عبر البلوتوث. لا تشارك رمز الاقتران مع أشخاص غير موثوقين.',
            ),
          ),
          const Divider(height: 28),
          _sectionTitle(context, 'الدعم ومعلومات التطبيق'),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('التواصل مع الدعم عبر واتساب'),
            subtitle: const Text('يفتح رابطًا خارجيًا'),
            trailing: const Icon(Icons.open_in_new),
            onTap: onSupport,
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('حول بلوساب'),
            subtitle: Text('بلوساب - محادثات عبر البلوتوث'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'بلوساب',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Future<void> _chooseTheme(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'اختيار المظهر',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String>(
              value: 'system',
              groupValue: themeMode,
              title: const Text('حسب إعداد الهاتف'),
              onChanged: (v) {
                if (v != null) {
                  Navigator.pop(sheetContext);
                  onThemeChanged(v);
                }
              },
            ),
            RadioListTile<String>(
              value: 'light',
              groupValue: themeMode,
              title: const Text('فاتح'),
              onChanged: (v) {
                if (v != null) {
                  Navigator.pop(sheetContext);
                  onThemeChanged(v);
                }
              },
            ),
            RadioListTile<String>(
              value: 'dark',
              groupValue: themeMode,
              title: const Text('داكن'),
              onChanged: (v) {
                if (v != null) {
                  Navigator.pop(sheetContext);
                  onThemeChanged(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
