import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

final heartRateService = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
final heartRateCharacteristic = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

void main() => runApp(const App());

class Settings {
  int? age;
  Settings({this.age});
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? scanSub;

  final devices = <DiscoveredDevice>[];
  final seen = <String>{};

  final settings = Settings();

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
    if (mounted) setState(() {});

    scanSub?.cancel();
    scanSub = ble.scanForDevices(withServices: const []).listen((d) {
      final name = d.name.trim();
      if (name.isEmpty) return;

      if (seen.add(d.id)) {
        devices.add(d);
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> stopScan() async {
    await scanSub?.cancel();
    scanSub = null;
  }

  Future<void> _showError(String msg) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _connectAndOpen(DiscoveredDevice d) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BlockingDialog(
        title: 'Connecting...',
        subtitle: 'Please wait',
      ),
    );

    StreamSubscription<ConnectionStateUpdate>? connSub;
    try {
      final completer = Completer<void>();

      connSub = ble.connectToDevice(
        id: d.id,
        connectionTimeout: const Duration(seconds: 10),
      ).listen((u) async {
        if (u.connectionState == DeviceConnectionState.connected) {
          if (!completer.isCompleted) completer.complete();
        }
        if (u.connectionState == DeviceConnectionState.disconnected) {
          if (!completer.isCompleted) completer.completeError('Disconnected');
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      await completer.future;

      final services = await ble.discoverServices(d.id);
      final hr = services.where((s) => s.serviceId == heartRateService);
      final hasHr = hr.isNotEmpty &&
          hr.any((s) => s.characteristicIds.contains(heartRateCharacteristic));

      if (!hasHr) {
        if (mounted) Navigator.pop(context);
        await connSub.cancel();
        await _showError('Heart monitor not compatible.');
        return;
      }

      if (mounted) Navigator.pop(context);

      await stopScan();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HeartRateScreen(
            deviceId: d.id,
            deviceName: d.name.trim(),
            settings: settings,
          ),
        ),
      );

      await startScan();
    } catch (_) {
      if (mounted) Navigator.pop(context);
      await connSub?.cancel();
      await _showError('Failed to connect.');
    } finally {
      await connSub?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Select a heart rate monitor',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                  textAlign: TextAlign.center,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Scanning for devices...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final d = devices[i];
                  final name = d.name.trim();

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _connectAndOpen(d),
                          child: ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              d.id,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartRateScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final Settings settings;

  const HeartRateScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.settings,
  });

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  final ble = FlutterReactiveBle();

  StreamSubscription<ConnectionStateUpdate>? connSub;
  StreamSubscription<List<int>>? hrSub;

  int bpm = 0;
  bool connected = false;

  bool _disconnectDialogShown = false;

  @override
  void initState() {
    super.initState();
    _connectAndSubscribe();
  }

  @override
  void dispose() {
    hrSub?.cancel();
    connSub?.cancel();
    super.dispose();
  }

  void _connectAndSubscribe() {
    connSub?.cancel();
    connSub = ble.connectToDevice(
      id: widget.deviceId,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((u) {
      if (u.connectionState == DeviceConnectionState.connected) {
        connected = true;
        if (mounted) setState(() {});
        _subscribeHr();
      }

      if (u.connectionState == DeviceConnectionState.disconnected) {
        connected = false;
        bpm = 0;
        if (mounted) setState(() {});
        _handleDisconnected();
      }
    }, onError: (_) {
      _handleDisconnected();
    });
  }

  void _subscribeHr() {
    final q = QualifiedCharacteristic(
      deviceId: widget.deviceId,
      serviceId: heartRateService,
      characteristicId: heartRateCharacteristic,
    );

    hrSub?.cancel();
    hrSub = ble.subscribeToCharacteristic(q).listen((data) {
      if (data.length < 2) return;
      final f = data[0];
      final is16 = (f & 0x01) == 1;
      bpm = is16 && data.length >= 3
          ? (data[1] | (data[2] << 8))
          : data[1];

      if (mounted) setState(() {});
    }, onError: (_) {
      _handleDisconnected();
    });
  }

  Future<void> _handleDisconnected() async {
    if (!mounted) return;
    if (_disconnectDialogShown) return;
    _disconnectDialogShown = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BlockingDialog(
        title: 'Heart monitor disconnected',
        subtitle: 'Returning to device list',
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text(
            connected ? (bpm == 0 ? '--' : '$bpm') : '--',
            style: const TextStyle(
              fontSize: 120,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockingDialog extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BlockingDialog({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121212), // destaca do fundo preto
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}