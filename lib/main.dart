
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/bluetooth_classic_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaslApp());
}

class WaslApp extends StatelessWidget {
  const WaslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087F8C),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const BluetoothHome(),
    );
  }
}

class BluetoothHome extends StatefulWidget {
  const BluetoothHome({super.key});

  @override
  State<BluetoothHome> createState() => _BluetoothHomeState();
}

class _BluetoothHomeState extends State<BluetoothHome> {
  final service = BluetoothClassicService.instance;
  final messageController = TextEditingController();

  StreamSubscription<WaslEvent>? subscription;
  List<WaslDevice> devices = [];
  final List<String> logs = [];

  String? selectedAddress;
  bool supported = false;
  bool enabled = false;
  bool busy = false;
  bool connected = false;
  bool serverStarted = false;

  @override
  void initState() {
    super.initState();
    subscription = service.events.listen(
      _onEvent,
      onError: (Object error) => _log('خطأ بالأحداث: $error'),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      supported = await service.isSupported();
      if (!supported) {
        _log('هذا الجهاز لا يدعم Bluetooth');
      } else {
        enabled = await service.isEnabled();
        if (!enabled) {
          _log('شغّل البلوتوث للمتابعة');
        } else {
          await _refreshDevices();
        }
      }
    } catch (e) {
      _log('تعذر التهيئة: $e');
    }
    if (mounted) setState(() {});
  }

  void _onEvent(WaslEvent event) {
    switch (event.type) {
      case 'serverStarted':
        serverStarted = true;
        _log('بدأ خادم RFCOMM');
        break;
      case 'serverStopped':
        serverStarted = false;
        _log('توقف الخادم');
        break;
      case 'connected':
        connected = true;
        selectedAddress = event.address;
        _log('اتصل الجهاز: ${event.name ?? event.address}');
        break;
      case 'disconnected':
        connected = false;
        _log('انقطع الاتصال: ${event.address ?? ""}');
        break;
      case 'message':
        _log('${event.name ?? event.address}: ${event.message ?? ""}');
        break;
      case 'connectionError':
      case 'serverError':
        _log('خطأ اتصال: ${event.message ?? event.type}');
        break;
    }
    if (mounted) setState(() {});
  }

  void _log(String message) {
    logs.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)}  $message');
    if (logs.length > 100) logs.removeLast();
    if (mounted) setState(() {});
  }

  Future<void> _refreshDevices() async {
    try {
      devices = await service.getPairedDevices();
      _log('الأجهزة المقترنة: ${devices.length}');
    } catch (e) {
      _log('تعذر قراءة الأجهزة: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _enableBluetooth() async {
    try {
      if (!await service.requestPermissions()) {
        _log('لم يتم منح صلاحية البلوتوث');
        return;
      }
      await service.requestEnable();
      _log('وافق على تشغيل البلوتوث من نافذة النظام');
    } catch (e) {
      _log('تعذر تشغيل البلوتوث: $e');
    }
  }

  Future<void> _startServer() async {
    setState(() => busy = true);
    try {
      await service.startServer();
      _log('طلب تشغيل الخادم تم');
    } catch (e) {
      _log('فشل تشغيل الخادم: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _connect() async {
    if (selectedAddress == null) {
      _log('اختر جهازاً مقترناً أولاً');
      return;
    }
    setState(() => busy = true);
    try {
      await service.connect(selectedAddress!);
      _log('اكتمل طلب الاتصال');
    } catch (e) {
      _log('فشل الاتصال: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || selectedAddress == null || !connected) {
      _log('اتصل بجهاز واكتب رسالة أولاً');
      return;
    }
    try {
      await service.sendMessage(
        address: selectedAddress!,
        message: text,
      );
      _log('أرسلت محلياً: $text');
      messageController.clear();
    } catch (e) {
      _log('تعذر الإرسال: $e');
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وصل | اختبار Bluetooth'),
        actions: [
          IconButton(
            tooltip: 'تحديث الأجهزة',
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('دعم البلوتوث: ${supported ? "متوفر" : "غير معروف"}'),
                  Text('حالة البلوتوث: ${enabled ? "يعمل" : "متوقف أو غير متحقق"}'),
                  Text('الخادم: ${serverStarted ? "يعمل" : "متوقف"}'),
                  Text('الاتصال: ${connected ? "متصل" : "غير متصل"}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _enableBluetooth,
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('تشغيل البلوتوث'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refreshDevices,
                    icon: const Icon(Icons.devices),
                    label: const Text('عرض الأجهزة المقترنة'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : _startServer,
                    child: const Text('تشغيل خادم الاستقبال'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('الأجهزة المقترنة', style: Theme.of(context).textTheme.titleMedium),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد أجهزة مقترنة ظاهرة. اقترن بالهاتف الآخر من إعدادات Android أولاً.'),
            ),
          ...devices.map((device) {
            return RadioListTile<String>(
              value: device.address,
              groupValue: selectedAddress,
              title: Text(device.name),
              subtitle: Text(device.address),
              onChanged: (value) {
                setState(() => selectedAddress = value);
              },
            );
          }),
          FilledButton.icon(
            onPressed: busy ? null : _connect,
            icon: const Icon(Icons.link),
            label: const Text('الاتصال بالجهاز المحدد'),
          ),
          const Divider(height: 32),
          TextField(
            controller: messageController,
            decoration: InputDecoration(
              labelText: 'اكتب رسالة',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send),
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 16),
          Text('سجل الأحداث', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: logs.isEmpty
                ? const Text('ستظهر أحداث الاتصال هنا.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: logs.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(line),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}