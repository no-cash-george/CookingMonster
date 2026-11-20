import 'dart:convert';

import 'package:archive/archive.dart';

import '../models/recipe.dart';

class ShareCodec {
  static const String _prefix = 'cm1:';

  /// Encodes a [Recipe] into a compact, URL- and QR-safe string.
  /// Local-only progress and cook counts are stripped prior to sharing.
  static String encode(Recipe recipe) {
    final jsonString = jsonEncode(recipe.toCompactJson(includeLocalState: false));
    final utf8Bytes = utf8.encode(jsonString);
    final compressed = ZLibEncoder().encode(utf8Bytes);
    final encoded = base64UrlEncode(compressed);
    return '$_prefix$encoded';
  }

  /// Decodes a shared payload back into a [Recipe] with a fresh local ID.
  /// Throws a [FormatException] if the payload is malformed or corrupted.
  static Recipe decode(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (!trimmed.startsWith(_prefix)) {
      throw const FormatException('Not a valid Cooking Monster recipe code.');
    }

    final base64Part = trimmed.substring(_prefix.length).trim();
    if (base64Part.isEmpty) {
      throw const FormatException('Recipe payload is empty.');
    }

    try {
      final compressedBytes = base64Url.decode(base64Part);
      final decompressedBytes = ZLibDecoder().decodeBytes(compressedBytes);
      final jsonString = utf8.decode(decompressedBytes);
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;

      final freshId = DateTime.now().microsecondsSinceEpoch.toString();
      return Recipe.fromCompactJson(freshId, decodedMap);
    } catch (_) {
      throw const FormatException('Could not decode recipe data.');
    }
  }
}
