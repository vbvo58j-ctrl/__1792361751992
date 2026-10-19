class BlosabDevice {
  final String name;
  final String address;

  const BlosabDevice({required this.name, required this.address});

  factory BlosabDevice.fromMap(Map<dynamic, dynamic> map) => BlosabDevice(
    name: map['name']?.toString() ?? 'جهاز',
    address: map['address']?.toString() ?? '',
  );
}