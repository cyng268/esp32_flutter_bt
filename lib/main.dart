import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final _bluetoothClassicPlugin = BluetoothClassic();
  List<Device> _devices = [];
  List<Device> _discoveredDevices = [];
  bool _scanning = false;
  int _deviceStatus = Device.disconnected;
  Device? _connectedDevice;
  Uint8List _data = Uint8List(0);

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _setupListeners();
  }

  Future<void> _initBluetooth() async {
    await _bluetoothClassicPlugin.initPermissions();
    await _getDevices();
  }

  void _setupListeners() {
    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((event) {
      setState(() {
        _deviceStatus = event;
        if (event == Device.disconnected) {
          _connectedDevice = null;
        }
      });
    });

    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      setState(() {
        _data = Uint8List.fromList([..._data, ...event]);
      });
    });
  }

  Future<void> _getDevices() async {
    var res = await _bluetoothClassicPlugin.getPairedDevices();
    setState(() {
      _devices = res;
    });
  }

  Future<void> _scan() async {
    if (_scanning) {
      await _bluetoothClassicPlugin.stopScan();
      setState(() {
        _scanning = false;
      });
    } else {
      setState(() {
        _discoveredDevices = [];
      });

      await _bluetoothClassicPlugin.startScan();
      _bluetoothClassicPlugin.onDeviceDiscovered().listen(
        (event) {
          setState(() {
            if (!_discoveredDevices
                .any((device) => device.address == event.address)) {
              _discoveredDevices = [..._discoveredDevices, event];
            }
          });
        },
      );

      setState(() {
        _scanning = true;
      });
    }
  }

  Future<void> _connectToDevice(Device device) async {
    try {
      await _bluetoothClassicPlugin.connect(
        device.address,
        "00001101-0000-1000-8000-00805f9b34fb", // Standard SerialPort service UUID
      );
      setState(() {
        _connectedDevice = device;
        _discoveredDevices = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Connected to ${device.name ?? device.address}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pingDevice() async {
    if (_deviceStatus == Device.connected) {
      try {
        await _bluetoothClassicPlugin.write("ping");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ping sent')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send ping: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Status: ${_deviceStatus == Device.connected ? "Connected" : "Disconnected"}'),
                if (_connectedDevice != null)
                  Text(
                      'Connected to: ${_connectedDevice?.name ?? _connectedDevice?.address}'),
              ],
            ),
          ),
  
          // Scan Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _scan,
              icon: Icon(_scanning ? Icons.stop : Icons.search),
              label: Text(_scanning ? "Stop Scan" : "Start Scan"),
            ),
          ),

          // Device Lists
          Expanded(
            child: ListView(
              children: [
                if (_devices.isNotEmpty) ...[
                  const ListTile(
                    title: Text('Paired Devices',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._devices.map((device) => ListTile(
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: _deviceStatus == Device.connected &&
                                _connectedDevice?.address == device.address
                            ? const Icon(Icons.bluetooth_connected,
                                color: Colors.blue)
                            : const Icon(Icons.bluetooth),
                        onTap: () => _connectToDevice(device),
                      )),
                ],
                if (_discoveredDevices.isNotEmpty) ...[
                  const ListTile(
                    title: Text('Discovered Devices',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._discoveredDevices.map((device) => ListTile(
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: const Icon(Icons.bluetooth_searching),
                        onTap: () => _connectToDevice(device),
                      )),
                ],
              ],
            ),
          ),

          // Connected Device Controls
          if (_deviceStatus == Device.connected)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _pingDevice,
                    child: const Text('Ping Device'),
                  ),
                  ElevatedButton(
                    onPressed: () => _bluetoothClassicPlugin.disconnect(),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),

          // Received Data Display
          if (_data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Received Data:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(String.fromCharCodes(_data)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
