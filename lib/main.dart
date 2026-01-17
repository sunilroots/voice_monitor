import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const VoiceMonitorApp());
}

class VoiceMonitorApp extends StatelessWidget {
  const VoiceMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Voice Monitor",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  final RecorderStream _recorder = RecorderStream();
  StreamSubscription<List<int>>? _sub;

  bool listening = false;
  double currentDb = 0;
  String status = "Idle";

  bool wasSpeaking = false;
  int bursts = 0;
  int burstLimit = 18;
  double loudLimit = 75;

  Timer? resetTimer;

  Future<void> start() async {
    if (!await Permission.microphone.request().isGranted) {
      setState(() => status = "Mic permission denied");
      return;
    }

    // Reset speaking bursts
    resetTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() => bursts = 0);
    });

    _recorder.initialize();

    _sub = _recorder.audioStream.listen((samples) {
      double rms = sqrt(samples
          .map((s) => s * s)
          .reduce((a, b) => a + b)
          .toDouble() /
          samples.length);

      final db = 20 * log(max(rms, 1)) / ln10;

      final speaking = db > 50;
      if (speaking && !wasSpeaking) bursts++;
      wasSpeaking = speaking;

      String newStatus = "Calm";
      if (db >= loudLimit) newStatus = "LOUD";
      else if (bursts >= burstLimit) newStatus = "FAST";

      setState(() {
        currentDb = db;
        status = newStatus;
      });

      if (newStatus != "Calm") {
        Vibration.vibrate(duration: 200);
      }
    });

    await _recorder.start();
    setState(() {
      listening = true;
      status = "Listening";
    });
  }

  void stop() async {
    _sub?.cancel();
    await _recorder.stop();
    resetTimer?.cancel();

    setState(() {
      listening = false;
      status = "Stopped";
      currentDb = 0;
      bursts = 0;
      wasSpeaking = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.stop();
    resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meterValue = ((currentDb - 40) / 50).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎤 Voice Monitor"),
      ),
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

            Text("Bursts (10 sec): $bursts",
                style: const TextStyle(fontSize: 16)),

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
