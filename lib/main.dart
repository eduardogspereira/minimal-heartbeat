import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _S();
}

class _S extends State<App> {
  final ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? scanSub;

  final devices = <DiscoveredDevice>[];
  final seen = <String>{};

  @override
  void initState() {
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    scanSub?.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    devices.clear();
    seen.clear();
    setState(() {});

    scanSub?.cancel();
    scanSub = ble.scanForDevices(withServices: const []).listen((d) {
      final name = d.name.trim();
      if (name.isEmpty) return;

      if (seen.add(d.id)) {
        devices.add(d);
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Selecione o dispositivo',
                  style: TextStyle(fontSize: 22),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (_, i) {
                    final d = devices[i];
                    final name = d.name.isEmpty ? '(sem nome)' : d.name;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(d.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}