import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test bootstrap for the whole suite.
///
/// The app bundles its fonts as binary TTF assets and disables runtime
/// fetching (see app_theme.dart). In checkouts where those binaries are
/// absent (e.g. CI, where only text files are mirrored), google_fonts
/// can neither load the fonts from assets nor fetch them, and throws —
/// failing otherwise-good widget tests.
///
/// This config intercepts the 'flutter/assets' channel: it serves an
/// asset manifest that lists the bundled font files, and serves real
/// (decoded) font bytes for every font path — decoded from a base64
/// fixture because the TTF itself is a binary that cannot live in
/// every checkout. Glyph fidelity is irrelevant to the assertions;
/// what matters is that a valid font registers under each family name.
/// All other asset keys are served from disk when present, matching
/// what the tool would do, and report "not found" otherwise.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fontBytes = base64Decode(
    File('test/fixtures/test_font.ttf.b64')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s'), ''),
  );

  const fontAssetPaths = [
    'assets/fonts/Inter-Black.ttf',
    'assets/fonts/Inter-Bold.ttf',
    'assets/fonts/Inter-ExtraBold.ttf',
    'assets/fonts/Inter-Light.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-SemiBold.ttf',
    'assets/fonts/PlayfairDisplay-Bold.ttf',
    'assets/fonts/Poppins-ExtraBold.ttf',
  ];

  // Modern manifest format: each key maps to a list of variant maps
  // ({"asset": path, "dpr": ratio}); a single self-variant per asset.
  Map<String, List<Map<String, Object>>> buildManifest() {
    List<Map<String, Object>> selfVariant(String path) => [
          {'asset': path},
        ];
    final manifest = <String, List<Map<String, Object>>>{};
    for (final path in fontAssetPaths) {
      manifest[path] = selfVariant(path);
    }
    // Include whatever real assets exist on disk (text assets, .gitkeep).
    for (final entity in Directory('assets').listSync(recursive: true)) {
      if (entity is File) {
        final path = entity.path.replaceAll(r'\', '/');
        manifest.putIfAbsent(path, () => selfVariant(path));
      }
    }
    return manifest;
  }

  final manifest = buildManifest();
  final manifestJson =
      Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
  final manifestBinData =
      const StandardMessageCodec().encodeMessage(manifest)!;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final key = utf8.decode(message.buffer.asUint8List());
    if (key == 'AssetManifest.json') return ByteData.view(manifestJson.buffer);
    if (key == 'AssetManifest.bin') return manifestBinData;
    // Real files (full local checkout) are served from disk, exactly as
    // the tool would serve them.
    final file = File(key);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }
    // In text-only checkouts the binary fonts are absent: serve the
    // decoded fixture font for every bundled font path.
    if (fontAssetPaths.contains(key)) {
      return ByteData.view(Uint8List.fromList(fontBytes).buffer);
    }
    // Binary images (avatars, onboarding art) are likewise absent;
    // serve a valid 1x1 PNG so image widgets can resolve their codec.
    // Assertions never inspect the pixels.
    if (key.endsWith('.png') ||
        key.endsWith('.jpg') ||
        key.endsWith('.jpeg') ||
        key.endsWith('.webp')) {
      return ByteData.view(Uint8List.fromList(_placeholderPng).buffer);
    }
    return null;
  });

  await testMain();
}

/// A valid 1x1 transparent PNG.
final List<int> _placeholderPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
