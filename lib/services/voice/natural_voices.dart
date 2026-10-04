import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Who is speaking: His words take the male voice, everything else the female one.
enum VoiceRole { jesus, verse }

/// A free Piper voice that runs on the phone (via sherpa-onnx), downloaded once.
/// Every voice here is licensed for use in an app; [credit] is shown in About.
class NaturalVoice {
  const NaturalVoice({
    required this.id,
    required this.lang,
    required this.role,
    required this.name,
    required this.megabytes,
    required this.lengthScale,
    required this.credit,
  });

  /// Piper voice id, e.g. "de_DE-thorsten-high".
  final String id;
  final String lang;
  final VoiceRole role;
  final String name;

  /// Download size, for the "Download (64 MB)" button.
  final int megabytes;

  /// How much slower than its natural pace to read, for a calm voice (1 = as trained).
  final double lengthScale;
  final String credit;

  /// Ready-converted for sherpa-onnx and hosted by its authors on Hugging Face.
  String get repo => 'csukuangfj/vits-piper-$id';

  Uri file(String name) => Uri.parse('https://huggingface.co/$repo/resolve/main/$name');
}

/// The chosen voices. Languages and roles not listed use the phone's own voice.
const naturalVoices = [
  NaturalVoice(id: 'en_GB-northern_english_male-medium', lang: 'en', role: VoiceRole.jesus, name: 'Northern English',
      megabytes: 64, lengthScale: 1.6, credit: 'Piper “northern_english_male” voice, CC BY-SA 4.0'),
  NaturalVoice(id: 'en_GB-cori-high', lang: 'en', role: VoiceRole.verse, name: 'Cori',
      megabytes: 110, lengthScale: 1.2, credit: 'Piper “cori” voice, from LibriVox recordings, public domain'),
  NaturalVoice(id: 'es_MX-ald-medium', lang: 'es', role: VoiceRole.jesus, name: 'Ald',
      megabytes: 64, lengthScale: 1.35, credit: 'Piper “ald” voice, Unlicense (public domain)'),
  NaturalVoice(id: 'es_AR-daniela-high', lang: 'es', role: VoiceRole.verse, name: 'Daniela',
      megabytes: 110, lengthScale: 1.2, credit: 'Piper “daniela” voice, from Google’s Argentine Spanish corpus (OpenSLR 61), CC BY-SA 4.0'),
  NaturalVoice(id: 'pt_BR-faber-medium', lang: 'pt', role: VoiceRole.jesus, name: 'Faber',
      megabytes: 64, lengthScale: 1.6, credit: 'Piper “faber” voice, CC0'),
  NaturalVoice(id: 'fr_FR-gilles-low', lang: 'fr', role: VoiceRole.jesus, name: 'Gilles',
      megabytes: 63, lengthScale: 1.45, credit: 'Piper “gilles” voice, CC0'),
  NaturalVoice(id: 'fr_FR-siwis-medium', lang: 'fr', role: VoiceRole.verse, name: 'Siwis',
      megabytes: 64, lengthScale: 1.25, credit: 'Piper “siwis” voice, from the SIWIS French Speech Synthesis Database, CC BY 4.0'),
  NaturalVoice(id: 'de_DE-thorsten-high', lang: 'de', role: VoiceRole.jesus, name: 'Thorsten',
      megabytes: 110, lengthScale: 1.6, credit: 'Piper “thorsten” voice by Thorsten Müller, CC0'),
  NaturalVoice(id: 'de_DE-kerstin-low', lang: 'de', role: VoiceRole.verse, name: 'Kerstin',
      megabytes: 63, lengthScale: 1.2, credit: 'Piper “kerstin” voice, CC0'),
  NaturalVoice(id: 'pl_PL-darkman-medium', lang: 'pl', role: VoiceRole.jesus, name: 'Darkman',
      megabytes: 64, lengthScale: 1.6, credit: 'Piper “darkman” voice, CC0'),
  NaturalVoice(id: 'pl_PL-gosia-medium', lang: 'pl', role: VoiceRole.verse, name: 'Gosia',
      megabytes: 64, lengthScale: 1.25, credit: 'Piper “gosia” voice, CC0'),
  NaturalVoice(id: 'ru_RU-denis-medium', lang: 'ru', role: VoiceRole.jesus, name: 'Denis',
      megabytes: 64, lengthScale: 1.4, credit: 'Piper “denis” voice, CC0'),
  NaturalVoice(id: 'uk_UA-lada-x_low', lang: 'uk', role: VoiceRole.verse, name: 'Lada',
      megabytes: 25, lengthScale: 1.1, credit: 'Piper “lada” voice, Apache 2.0'),
];

/// Voice engine credit, shown with the voices.
const naturalVoicesCredit = 'Voices by the Piper project (rhasspy), run on the phone with sherpa-onnx (k2-fsa, Apache 2.0).';

NaturalVoice? naturalVoiceFor(String lang, VoiceRole role) =>
    naturalVoices.where((v) => v.lang == lang && v.role == role).firstOrNull;

/// Downloads and removes natural voices, and says which are ready. Files come
/// straight from Hugging Face, uncompressed, so nothing is unpacked on the phone:
/// one shared pronunciation folder (espeak-ng-data, 17 MB, the same for every
/// voice) and, per voice, its model and tokens.
class NaturalVoiceStore extends ChangeNotifier {
  NaturalVoiceStore({Future<Directory> Function()? root, http.Client? client})
      : _root = root ?? getApplicationSupportDirectory,
        _client = client ?? http.Client();

  final Future<Directory> Function() _root;
  final http.Client _client;
  final _installed = <String>{};
  bool _scanned = false;

  /// Voice id → download progress 0–1, while downloading.
  final downloading = <String, double>{};

  Future<String> _voices() async => '${(await _root()).path}/voices';
  Future<Directory> _dir(NaturalVoice v) async => Directory('${await _voices()}/${v.id}');

  /// The files the engine needs, or null if [v] isn't downloaded.
  Future<({String model, String tokens, String dataDir})?> files(NaturalVoice v) async {
    if (!await isInstalled(v)) return null;
    final dir = (await _dir(v)).path;
    return (model: '$dir/${v.id}.onnx', tokens: '$dir/tokens.txt', dataDir: '${await _voices()}/espeak-ng-data');
  }

  Future<bool> isInstalled(NaturalVoice v) async {
    if (!_scanned) {
      _scanned = true;
      final shared = await File('${await _voices()}/espeak-ng-data/.ready').exists();
      for (final voice in naturalVoices) {
        if (shared && await File('${(await _dir(voice)).path}/.ready').exists()) _installed.add(voice.id);
      }
    }
    return _installed.contains(v.id);
  }

  bool installedNow(NaturalVoice v) => _installed.contains(v.id);

  /// Downloads [v] (and the shared pronunciation files, the first time).
  /// Throws if the download fails; a voice only counts once every file is in.
  Future<void> download(NaturalVoice v) async {
    if (downloading.containsKey(v.id) || await isInstalled(v)) return;
    downloading[v.id] = 0;
    notifyListeners();
    void progress(double p) {
      downloading[v.id] = p.clamp(0.0, 0.99);
      notifyListeners();
    }

    try {
      final voices = await _voices();
      final listing = jsonDecode((await _get(Uri.parse('https://huggingface.co/api/models/${v.repo}'))).body);
      final names = [for (final f in listing['siblings'] as List) f['rfilename'] as String];

      // Shared pronunciation files: about a sixth of a first download.
      final shared = Directory('$voices/espeak-ng-data');
      final sharedFirst = !await File('${shared.path}/.ready').exists();
      if (sharedFirst) {
        final espeak = [for (final n in names) if (n.startsWith('espeak-ng-data/')) n];
        var done = 0;
        await _inBatches(espeak, 8, (name) async {
          await _save(v.file(name), File('$voices/$name'));
          progress(0.15 * ++done / espeak.length);
        });
        await File('${shared.path}/.ready').writeAsString('ok');
      }

      final dir = await _dir(v);
      await _save(v.file('tokens.txt'), File('${dir.path}/tokens.txt'));
      final from = sharedFirst ? 0.15 : 0.0;
      await _save(v.file('${v.id}.onnx'), File('${dir.path}/${v.id}.onnx'),
          onProgress: (p) => progress(from + (1 - from) * p));
      await File('${dir.path}/.ready').writeAsString(v.id);
      _installed.add(v.id);
    } finally {
      downloading.remove(v.id);
      notifyListeners();
    }
  }

  Future<void> remove(NaturalVoice v) async {
    final dir = await _dir(v);
    if (await dir.exists()) await dir.delete(recursive: true);
    _installed.remove(v.id);
    notifyListeners();
  }

  Future<http.Response> _get(Uri url) async {
    final r = await _client.get(url);
    if (r.statusCode != 200) throw HttpException('${r.statusCode}', uri: url);
    return r;
  }

  /// Streams [url] to [file] through a temporary name, so a broken download never looks finished.
  Future<void> _save(Uri url, File file, {void Function(double)? onProgress}) async {
    final response = await _client.send(http.Request('GET', url));
    if (response.statusCode != 200) throw HttpException('${response.statusCode}', uri: url);
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    final sink = part.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    await part.rename(file.path);
  }

  static Future<void> _inBatches(List<String> items, int size, Future<void> Function(String) each) async {
    for (var i = 0; i < items.length; i += size) {
      await Future.wait(items.skip(i).take(size).map(each));
    }
  }
}
