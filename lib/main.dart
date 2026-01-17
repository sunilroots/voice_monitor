import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

void main() => runApp(const VoiceMonitorApp());

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
  final NoiseMeter _meter = NoiseMeter();
  StreamSubscription<NoiseReading>? _sub;

  bool listening = false;
  double currentDb = 0;
  String status = "Idle";

  /// Custom logic
  bool wasSpeaking = false;
  int segments = 0;
  int fastLimit = 18;    // bursts per 10 seconds
  double loudLimit = 75; // dB
  Timer? resetTimer;

  /// Start listening
  Future<void> start() async {
    if (!await Permission.microphone.request().isGranted) {
      setState(() => status = "Mic permission denied");
      return;
    }

    // Reset bursts every 10 seconds
    resetTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() => segments = 0);
    });

    await _meter.start();

    _sub = _meter.noise.listen((reading) {
      final db = reading.meanDecibel.isFinite ? reading.meanDecibel : 0.0;

      // speech detection
      final speaking = db > 55;
      if (speaking && !wasSpeaking) segments++;
      wasSpeaking = speaking;

      // Determine status
      String s = "Calm";
      if (db >= loudLimit) s = "LOUD";
      else if (segments >= fastLimit) s = "FAST";

      setState(() {
        currentDb = db;
        status = s;
      });

      if (s != "Calm") {
        Vibration.vibrate(duration: 200);
      }
    });

    setState(() {
      listening = true;
      status = "Listening";
    });
  }

  /// Stop listening
  void stop() {
    _sub?.cancel();
    _meter.stop();
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
  void dispose() {
    _sub?.cancel();
    _meter.stop();
    resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meterValue = ((currentDb - 40) / 50).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text("🎤 Voice Monitor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 20),

            LinearProgressIndicator(value: meterValue),
            const SizedBox(height: 12),
            Text("${currentDb.toStringAsFixed(1)} dB",
                style: const TextStyle(fontSize: 18)),

            const SizedBox(height: 12),
            Text("Speech bursts (10 sec): $segments"),

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
          ],
        ),
      ),
    );
  }
}
