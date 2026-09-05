import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../audio/pitch_detector.dart';
import '../audio/ring_buffer.dart';

class PitchService {
  PitchService({
    this.sampleRate = 44100,
    int analysisWindowSamples = 4096,
    this.minHz = 70,
    this.maxHz = 4200,
  }) : _ringBuffer = RingBuffer (analysisWindowSamples);

  final int sampleRate;
  final double minHz;
  final double maxHz;

  final AudioRecorder _recorder = AudioRecorder();
  final RingBuffer _ringBuffer;
  StreamSubscription<Uint8List>? _audioSub;

  final _hzController = StreamController<double>.broadcast();

  Stream<double> get hzStream => _hzController.stream;

  bool get isRecording => _audioSub != null;

  Future<bool> start() async {
  
    if (isRecording) return true;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    final stream = await _recorder.startStream(
      RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      ),
    );

    _ringBuffer.clear();

    _audioSub = stream.listen((Uint8List chunk) {
      final samples = _pcm16ToDoubles(chunk);
      _ringBuffer.addAll(samples);

      if (!_ringBuffer.isFull) return;

      final hz = detectPitch(
        _ringBuffer.snapshot(),
        sampleRate.toDouble(),
        minHz: minHz,
        maxHz: maxHz,
      );
      if (hz != null && !_hzController.isClosed) {
        _hzController.add(hz);
      }
    });

    return true;
  }

  Future<void> stop() async {
    await _audioSub?.cancel();
    _audioSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _hzController.close();
  }

  List<double> _pcm16ToDoubles(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    final out = List<double>.filled(sampleCount, 0.0);
    for (int i = 0; i < sampleCount; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

}