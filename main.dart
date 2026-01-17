import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const VoiceMonitorApp());
}

class VoiceMonitorApp extends StatelessWidget {
  const VoiceMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final NoiseMeter _noiseMeter = NoiseMeter();
  StreamSubscription<NoiseReading>? _sub;

  double loudDb = 75;
  int fastSegments = 18;

  double currentDb = 0;
  int segments = 0;
  bool wasSpeaking = false;
  bool listening = false;
  String status = "Idle";

  Timer? resetTimer;

  Future<void> start() async {
    if (!await Permission.microphone.request().isGranted) {
      setState(() => status = "Mic permission denied");
      return;
    }

    resetTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() => segments = 0);
    });

    _sub = _noiseMeter.noiseStream.listen((event) {
      final db = event.meanDecibel.isFinite ? event.meanDecibel : 0.0;
      final speaking = db > 55;

      if (speaking && !wasSpeaking) segments++;
      wasSpeaking = speaking;

      String newStatus = "Calm";
      if (db >= loudDb) newStatus = "LOUD";
      else if (segments >= fastSegments) newStatus = "FAST";

      setState(() {
        currentDb = db;
        status = newStatus;
      });

      if (newStatus != "Calm") {
        Vibration.vibrate(duration: 200);
      }
    });

    setState(() {
      listening = true;
      status = "Listening";
    });
  }

  void stop() {
    _sub?.cancel();
    resetTimer?.cancel();
    setState(() {
      listening = false;
      status = "Stopped";
      currentDb = 0;
      segments = 0;
      wasSpeaking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meter = ((currentDb - 40) / 50).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text("🎤 Voice Monitor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: meter),
            const SizedBox(height: 8),
            Text("${currentDb.toStringAsFixed(1)} dB"),
            const SizedBox(height: 8),
            Text("Speech bursts: $segments"),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: listening ? null : start,
                    child: const Text("Start"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: listening ? stop : null,
                    child: const Text("Stop"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Foreground only — stops when app is closed or screen is off.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}
