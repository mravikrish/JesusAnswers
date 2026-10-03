import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns a picture card on screen into an image, and sends it where the user chose:
/// WhatsApp (for a status), the share sheet, or the phone's gallery.
/// Every picture carries the app's name and the caption carries the Play Store link,
/// so whoever sees a status can find the app.
abstract final class PictureShare {
  static const _channel = MethodChannel('jesusanswers/share');

  /// The card under [boundary] as a PNG, [width] pixels wide — 1080 is a full-screen status.
  static Future<Uint8List> render(RenderRepaintBoundary boundary, {double width = 1080}) async {
    final image = await boundary.toImage(pixelRatio: width / boundary.size.width);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Written under cache/pictures/, which the Android FileProvider shares (res/xml/picture_paths.xml).
  static Future<File> _file(Uint8List png) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/pictures');
    await dir.create(recursive: true);
    // One file at a time: an old picture is never needed again once a new one is shared.
    for (final old in dir.listSync()) {
      old.deleteSync();
    }
    return File('${dir.path}/JesusAnswers_${DateTime.now().millisecondsSinceEpoch}.png')..writeAsBytesSync(png);
  }

  /// Opens WhatsApp with the picture, where "My status" is first in the list.
  /// Falls back to the share sheet when WhatsApp isn't installed (or on iOS).
  static Future<void> toWhatsApp(Uint8List png, String caption) async {
    final file = await _file(png);
    if (Platform.isAndroid) {
      try {
        if (await _channel.invokeMethod<bool>('whatsapp', {'path': file.path, 'text': caption}) ?? false) return;
      } on PlatformException {
        // Fall through to the share sheet.
      }
    }
    await _shareFile(file, caption);
  }

  static Future<void> share(Uint8List png, String caption) async => _shareFile(await _file(png), caption);

  static Future<void> _shareFile(File file, String caption) => SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: caption,
    ),
  );

  /// Saves into a "JesusAnswers" album. Returns false if it couldn't (e.g. permission denied).
  /// Elsewhere than Android, opens the share sheet, which has "Save Image".
  static Future<bool> save(Uint8List png, String caption) async {
    final file = await _file(png);
    if (!Platform.isAndroid) {
      await _shareFile(file, caption);
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('save', {'path': file.path}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}
