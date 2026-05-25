/// Common model for Bluetooth devices to avoid ambiguous imports 
/// between native flutter_bluetooth_serial and web stub.
class BluetoothDevice {
  final String address;
  final String? name;
  
  BluetoothDevice({required this.address, this.name});
}
