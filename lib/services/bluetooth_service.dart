import '../models/bluetooth_device.dart';
import 'bluetooth_classic_service.dart';

class BluetoothService {
  BluetoothService._();
  static final instance = BluetoothService._();
  final BluetoothClassicService _classic = BluetoothClassicService.instance;
  Stream<Map<String, dynamic>> get events => _classic.events.map((e) => {
    'type': e.type, if (e.address != null) 'address': e.address,
    if (e.name != null) 'name': e.name, if (e.message != null) 'message': e.message,
  });
  Future<bool> isSupported() => _classic.isSupported();
  Future<bool> isEnabled() => _classic.isEnabled();
  Future<void> requestEnable() => _classic.requestEnable();
  Future<void> startServer() => _classic.startServer();
  Future<void> disconnect() => _classic.disconnect();
  Future<List<BlosabDevice>> discover() async => (await _classic.getPairedDevices())
      .map((d) => BlosabDevice(name: d.name, address: d.address)).toList();
  Future<void> connect(String address) => _classic.connect(address);
  Future<void> sendTo(String address, String text) => _classic.sendMessage(address: address, message: text);
}