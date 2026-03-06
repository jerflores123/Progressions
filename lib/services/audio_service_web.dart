import 'dart:typed_data';

/// No-op on web – cache directory is not used.
Future<String> initCacheDir() async => '';

/// No-op on web – files are not written to disk.
Future<void> writeFileIfMissing(String path, Uint8List Function() generator) async {}
