import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Initialise the native cache directory and return its path.
Future<String> initCacheDir() async {
  final dir = await getTemporaryDirectory();
  final cacheDir = '${dir.path}/progression_audio';
  await Directory(cacheDir).create(recursive: true);
  return cacheDir;
}

/// Write [generator] bytes to [path] if the file doesn't already exist.
Future<void> writeFileIfMissing(String path, Uint8List Function() generator) async {
  final file = File(path);
  if (!await file.exists()) {
    final wav = generator();
    await file.writeAsBytes(wav, flush: true);
  }
}
