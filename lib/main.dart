import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

final heartRateService = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
final heartRateCharacteristic = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _S();
}

class _S extends State<App> {
  final ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? connSub;
  StreamSubscription<List<int>>? hrSub;

  String? deviceId;
  int bpm = 0;

  @override
  void dispose() {
    hrSub?.cancel();
    connSub?.cancel();
    scanSub?.cancel();
    super.dispose();
  }

  Future<void> go() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    bpm = 0;
    deviceId = null;
    setState(() {});

    scanSub?.cancel();
    scanSub = ble.scanForDevices(withServices: [heartRateService]).listen((d) {
      if (deviceId != null) return;
      deviceId = d.id;
      scanSub?.cancel();
      setState(() {});

      connSub?.cancel();
      connSub = ble.connectToDevice(id: d.id).listen((u) {
        if (u.connectionState == DeviceConnectionState.connected) {
          final q = QualifiedCharacteristic(
            characteristicId: heartRateCharacteristic,
            serviceId: heartRateService,
            deviceId: d.id,
          );

          hrSub?.cancel();
          hrSub = ble.subscribeToCharacteristic(q).listen((data) {
            final f = data.isNotEmpty ? data[0] : 0;
            final is16 = (f & 0x01) == 1;
            if (!is16 && data.length >= 2) bpm = data[1];
            if (is16 && data.length >= 3) bpm = data[1] | (data[2] << 8);
            setState(() {});
          });
        }
        if (u.connectionState == DeviceConnectionState.disconnected) {
          deviceId = null;
          bpm = 0;
          setState(() {});
        }
      });
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (deviceId == null) {
        scanSub?.cancel();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: go,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: Text(
            bpm == 0 ? '--' : '$bpm',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 120, color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}
