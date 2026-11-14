import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../constants.dart';

/// Stores pin images as files in `<app support>/PinImages/`.
class ImageStorage {
  ImageStorage(String supportDirectory)
    : directory = Directory(
        p.join(supportDirectory, AppConstants.imageDirectoryName),
      );

  final Directory directory;

  File fileFor(String filename) => File(p.join(directory.path, filename));

  /// Decodes, downsizes and re-encodes [data] as JPEG. Returns the filename
  /// and aspect ratio, or null when the data isn't a decodable image.
  Future<({String filename, double aspectRatio})?> saveImage(
    Uint8List data,
    String pinId,
  ) async {
    final processed = await Isolate.run(() => _processImage(data));
    if (processed == null) return null;
    await directory.create(recursive: true);
    // A fresh name per save lets Flutter's image cache pick up replacements.
    final filename = '$pinId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await fileFor(filename).writeAsBytes(processed.jpeg, flush: true);
    return (filename: filename, aspectRatio: processed.aspectRatio);
  }

  /// Saves favicon bytes as-is after checking they decode.
  Future<String?> saveFavicon(Uint8List data, String pinId) async {
    final valid = await Isolate.run(() => img.decodeImage(data) != null);
    if (!valid) return null;
    await directory.create(recursive: true);
    final filename = '$pinId-favicon.png';
    await fileFor(filename).writeAsBytes(data, flush: true);
    return filename;
  }

  /// Writes bytes that are already processed (e.g. from another device).
  Future<String> writeFile(Uint8List data, String pinId, String suffix) async {
    await directory.create(recursive: true);
    final filename = '$pinId-$suffix-${DateTime.now().millisecondsSinceEpoch}';
    await fileFor(filename).writeAsBytes(data, flush: true);
    return filename;
  }

  Future<Uint8List?> read(String? filename) async {
    if (filename == null) return null;
    final file = fileFor(filename);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> delete(String? filename) async {
    if (filename == null) return;
    final file = fileFor(filename);
    if (await file.exists()) await file.delete();
  }
}

({Uint8List jpeg, double aspectRatio})? _processImage(Uint8List data) {
  final decoded = img.decodeImage(data);
  if (decoded == null || decoded.height == 0) return null;
  final resized = decoded.width > AppConstants.maxImageWidth
      ? img.copyResize(decoded, width: AppConstants.maxImageWidth)
      : decoded;
  return (
    jpeg: img.encodeJpg(resized, quality: AppConstants.imageJpegQuality),
    aspectRatio: decoded.width / decoded.height,
  );
}
