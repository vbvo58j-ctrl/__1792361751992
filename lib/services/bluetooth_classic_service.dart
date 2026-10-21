import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WaslDevice {
  final String name, address;
  const WaslDevice({required this.name, required this.address});
  factory WaslDevice.fromMap(Map<dynamic, dynamic> m) =>
      WaslDevice(name: m['name']?.toString() ?? 'جهاز', address: m['address']?.toString() ?? '');
}
class WaslEvent {
  final String type;
  final String? address, name, message;
  const WaslEvent({required this.type, this.address, this.name, this.message});
  factory WaslEvent.fromMap(Map<dynamic, dynamic> m) => WaslEvent(
    type: m['type']?.toString() ?? 'unknown',
    address: m['address']?.toString(), name: m['name']?.toString(), message: m['message']?.toString(),
  );
}
class BluetoothClassicService {
  BluetoothClassicService._();
  static final instance = BluetoothClassicService._();
  static const _methods = MethodChannel('com.plosap.myapp/bluetooth');
  static const _events = EventChannel('com.plosap.myapp/events');
  Stream<WaslEvent>? _stream;
  Stream<WaslEvent> get events => _stream ??= _events.receiveBroadcastStream()
      .map((e) => WaslEvent.fromMap(Map<dynamic, dynamic>.from(e as Map))).asBroadcastStream();

  Future<void> _permissions() async {
    if (!await Permission.bluetoothConnect.request().isGranted ||
        !await Permission.bluetoothScan.request().isGranted) {
      throw PlatformException(code: 'PERMISSION_DENIED', message: 'امنح صلاحيات البلوتوث من إعدادات التطبيق.');
    }
  }
  Future<bool> isSupported() async => await _methods.invokeMethod<bool>('isSupported') ?? false;
  Future<bool> isEnabled() async { await _permissions(); return await _methods.invokeMethod<bool>('isEnabled') ?? false; }
  Future<void> requestEnable() async { await _permissions(); await _methods.invokeMethod('requestEnable'); }
  Future<List<WaslDevice>> getPairedDevices() async {
    await _permissions();
    final list = await _methods.invokeMethod<List<dynamic>>('getPairedDevices');
    return (list ?? []).map((e) => WaslDevice.fromMap(Map<dynamic, dynamic>.from(e as Map))).toList();
  }
  Future<void> startServer() async { await _permissions(); await _methods.invokeMethod('startServer'); }
  Future<void> connect(String address) async { await _permissions(); await _methods.invokeMethod('connect', {'address': address}); }
  Future<void> sendMessage({required String address, required String message}) async {
    await _permissions();
    final ok = await _methods.invokeMethod<bool>('sendMessage', {'address': address, 'message': message});
    if (ok != true) throw PlatformException(code: 'SEND_FAILED', message: 'فشل إرسال الرسالة');
  }
  Future<void> disconnect([String? address]) async => _methods.invokeMethod('disconnect', {if (address != null) 'address': address});
  Future<void> stopServer() async => _methods.invokeMethod('stopServer');
}