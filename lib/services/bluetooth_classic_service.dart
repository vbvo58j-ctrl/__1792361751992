
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WaslDevice {
  final String name;
  final String address;

  const WaslDevice({required this.name, required this.address});

  factory WaslDevice.fromMap(Map<dynamic, dynamic> map) {
    return WaslDevice(
      name: map['name']?.toString() ?? 'جهاز',
      address: map['address']?.toString() ?? '',
    );
  }
}

class WaslEvent {
  final String type;
  final String? address;
  final String? name;
  final String? message;

  const WaslEvent({
    required this.type,
    this.address,
    this.name,
    this.message,
  });

  factory WaslEvent.fromMap(Map<dynamic, dynamic> map) {
    return WaslEvent(
      type: map['type']?.toString() ?? 'unknown',
      address: map['address']?.toString(),
      name: map['name']?.toString(),
      message: map['message']?.toString(),
    );
  }
}

class BluetoothClassicService {
  BluetoothClassicService._();

  static final BluetoothClassicService instance =
      BluetoothClassicService._();

  static const MethodChannel _methods =
      MethodChannel('com.wasl.messenger/bluetooth');

  static const EventChannel _events =
      EventChannel('com.wasl.messenger/events');

  Stream<WaslEvent>? _stream;

  Stream<WaslEvent> get events {
    return _stream ??= _events.receiveBroadcastStream().map((event) {
      return WaslEvent.fromMap(
        Map<dynamic, dynamic>.from(event as Map),
      );
    }).asBroadcastStream();
  }

  Future<bool> requestPermissions() async {
    final connect = await Permission.bluetoothConnect.request();

    if (!connect.isGranted) return false;

    // نحتاج هذه الصلاحية لأن كود Android يستدعي cancelDiscovery().
    final scan = await Permission.bluetoothScan.request();

    return scan.isGranted;
  }

  Future<void> _ensurePermission() async {
    if (!await requestPermissions()) {
      throw PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'امنح صلاحيات البلوتوث من إعدادات التطبيق.',
      );
    }
  }

  Future<bool> isSupported() async {
    return await _methods.invokeMethod<bool>('isSupported') ?? false;
  }

  Future<bool> isEnabled() async {
    await _ensurePermission();
    return await _methods.invokeMethod<bool>('isEnabled') ?? false;
  }

  Future<void> requestEnable() async {
    await _ensurePermission();
    await _methods.invokeMethod<bool>('requestEnable');
  }

  Future<List<WaslDevice>> getPairedDevices() async {
    await _ensurePermission();

    final list = await _methods.invokeMethod<List<dynamic>>(
      'getPairedDevices',
    );

    return (list ?? []).map((item) {
      return WaslDevice.fromMap(
        Map<dynamic, dynamic>.from(item as Map),
      );
    }).toList();
  }

  Future<void> startServer() async {
    await _ensurePermission();
    await _methods.invokeMethod<bool>('startServer');
  }

  Future<void> connect(String address) async {
    await _ensurePermission();

    await _methods.invokeMethod<bool>(
      'connect',
      {'address': address},
    );
  }

  Future<void> sendMessage({
    required String address,
    required String message,
  }) async {
    await _ensurePermission();

    final success = await _methods.invokeMethod<bool>(
      'sendMessage',
      {'address': address, 'message': message},
    );

    if (success != true) {
      throw PlatformException(
        code: 'SEND_FAILED',
        message: 'لم يؤكد البلوتوث إرسال الرسالة.',
      );
    }
  }

  Future<void> disconnect([String? address]) async {
    await _methods.invokeMethod<bool>(
      'disconnect',
      {if (address != null) 'address': address},
    );
  }

  Future<void> stopServer() async {
    await _methods.invokeMethod<bool>('stopServer');
  }
}