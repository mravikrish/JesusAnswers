import 'dart:async';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Speaks with a downloaded natural voice: turns text into a WAV file in a
/// background isolate (the engine is heavy, the UI must never wait on it).
class NaturalSpeech {
  SendPort? _worker;
  Future<SendPort>? _starting;
  final _pending = <int, Completer<double>>{};
  int _next = 0;

  Future<SendPort> _start() => _starting ??= () async {
        final inbox = ReceivePort();
        await Isolate.spawn(_work, inbox.sendPort);
        final ready = Completer<SendPort>();
        inbox.listen((message) {
          if (message is SendPort) {
            ready.complete(message);
          } else if (message case (int id, double seconds)) {
            _pending.remove(id)?.complete(seconds);
          } else if (message case (int id, String error)) {
            _pending.remove(id)?.completeError(StateError(error));
          }
        });
        return _worker = await ready.future;
      }();

  /// Writes [text] spoken by the voice in [model]/[tokens]/[dataDir] to [wavPath];
  /// returns its length in seconds. [lengthScale] above 1 reads more slowly.
  Future<double> synthesize({
    required String model,
    required String tokens,
    required String dataDir,
    required String text,
    required double lengthScale,
    required String wavPath,
  }) async {
    final worker = _worker ?? await _start();
    final id = _next++;
    final done = Completer<double>();
    _pending[id] = done;
    worker.send((id, model, tokens, dataDir, text, 1 / lengthScale, wavPath));
    return done.future;
  }
}

/// The background isolate: one engine at a time, kept loaded between requests.
void _work(SendPort main) {
  final inbox = ReceivePort();
  main.send(inbox.sendPort);
  String? broken;
  try {
    sherpa.initBindings();
  } catch (e) {
    broken = '$e';
  }
  sherpa.OfflineTts? tts;
  String? loaded;
  inbox.listen((message) {
    final (int id, String model, String tokens, String dataDir, String text, double speed, String wavPath) =
        message as (int, String, String, String, String, double, String);
    if (broken != null) {
      main.send((id, broken));
      return;
    }
    try {
      if (loaded != model) {
        tts?.free();
        tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(model: model, tokens: tokens, dataDir: dataDir),
            numThreads: 2,
            debug: false,
          ),
        ));
        loaded = model;
      }
      final audio = tts!.generate(text: text, speed: speed);
      sherpa.writeWave(filename: wavPath, samples: audio.samples, sampleRate: audio.sampleRate);
      main.send((id, audio.samples.length / audio.sampleRate));
    } catch (e) {
      main.send((id, '$e'));
    }
  });
}
