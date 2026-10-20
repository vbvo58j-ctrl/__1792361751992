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
  final BluetoothService bt = BluetoothService.instance;
  final LocalDatabase db = LocalDatabase.instance;

  List<BlosabDevice> devices = [];

  bool loading = false;
  bool bluetoothEnabled = false;
  bool bluetoothSupported = true;
  String? connecting;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    if (loading) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final supported = await bt.isSupported();

      if (!mounted) return;

      setState(() => bluetoothSupported = supported);

      if (!supported) {
        throw Exception('هذا الهاتف لا يدعم البلوتوث');
      }

      var enabled = await bt.isEnabled();

      if (!enabled) {
        await bt.requestEnable();

        // إعادة الفحص بعد طلب تشغيل البلوتوث.
        // إذا لم يفعّله المستخدم، نبقي الشاشة جاهزة لإعادة المحاولة.
        enabled = await bt.isEnabled();
      }

      if (!mounted) return;

      setState(() => bluetoothEnabled = enabled);

      if (!enabled) {
        setState(() {
          errorMessage = 'شغّل البلوتوث ثم اضغط زر التحديث.';
          devices = [];
        });
        return;
      }

      final found = await bt.discover();

      if (!mounted) return;

      setState(() {
        devices = found;
        errorMessage = found.isEmpty
            ? 'لا توجد أجهزة مقترنة. اقترن بالجهاز الآخر من إعدادات الهاتف، ثم اضغط تحديث.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      setState(() {
        errorMessage = message.contains('MissingPluginException')
            ? 'تعذر الاتصال بخدمة البلوتوث في Android. أعد بناء APK وثبّت النسخة الجديدة. إذا استمر الخطأ، نحتاج إلى فحص تسجيل MainActivity.'
            : 'تعذر العثور على الأجهزة: $message';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _connect(BlosabDevice device) async {
    if (connecting != null) return;

    setState(() {
      connecting = device.address;
      errorMessage = null;
    });

    try {
      await bt.connect(device.address);

      await db.saveConversation(
        address: device.address,
        name: device.name,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            address: device.address,
            peerName: device.name,
            userName: 'مستخدم',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاتصال: $e')),
      );
    } finally {
      if (mounted) setState(() => connecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلوساب - أجهزة البلوتوث'),
        actions: [
          IconButton(
            tooltip: 'تحديث الأجهزة',
            onPressed: loading ? null : _scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (bluetoothSupported)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : _scan,
                  icon: Icon(
                    bluetoothEnabled
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                  ),
                  label: Text(
                    loading
                        ? 'جارٍ الفحص...'
                        : bluetoothEnabled
                            ? 'تحديث الأجهزة'
                            : 'تشغيل / فحص البلوتوث',
                  ),
                ),
              ),
            ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: loading && devices.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : devices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bluetooth_searching,
                                size: 64,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                errorMessage ??
                                    'لا توجد أجهزة مقترنة',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: loading ? null : _scan,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _scan,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];

                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.bluetooth),
                              ),
                              title: Text(device.name),
                              subtitle: Text(device.address),
                              trailing: connecting == device.address
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: connecting == null
                                  ? () => _connect(device)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}