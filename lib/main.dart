import 'dart:io';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

final hrService = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
final hrChar = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

void main() => runApp(const _App());

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _S();
}

class _S extends State<_App> {
  final ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? connSub;
  StreamSubscription<List<int>>? hrSub;

  String? id;
  int bpm = 0;
  String status = 'tap';

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
    id = null;
    status = 'scan';
    setState(() {});

    scanSub?.cancel();
    scanSub = ble.scanForDevices(withServices: [hrService]).listen((d) {
      if (id != null) return;
      id = d.id;
      scanSub?.cancel();
      status = 'conn';
      setState(() {});

      connSub?.cancel();
      connSub = ble.connectToDevice(id: d.id).listen((u) {
        if (u.connectionState == DeviceConnectionState.connected) {
          status = 'ok';
          setState(() {});
          final q = QualifiedCharacteristic(
            characteristicId: hrChar,
            serviceId: hrService,
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
          status = 'disc';
          id = null;
          setState(() {});
        }
      });
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (id == null) {
        scanSub?.cancel();
        status = 'none';
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
