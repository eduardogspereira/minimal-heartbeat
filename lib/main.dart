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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Select a device',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: devices.length + 1,
                  itemBuilder: (_, i) {
                    if (i == devices.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final d = devices[i];
                    final name = d.name.trim();
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ListTile(
                          title: Text(name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(d.id, style: const TextStyle(color: Colors.white70)),
                        ),
                      ),
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