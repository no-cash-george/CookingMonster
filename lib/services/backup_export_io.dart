import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> exportCmonuFileImpl({required String fileName, required String jsonContent}) async {
  if (Platform.isAndroid) {
    final publicDownloads = Directory('/storage/emulated/0/Download');
    try {
      if (await publicDownloads.exists()) {
        final publicPath = p.join(publicDownloads.path, fileName);
        await File(publicPath).writeAsString(jsonContent, flush: true);
        return publicPath;
      }
    } catch (_) {
      // Fall back to app-scoped storage if public Downloads write is restricted.
    }

    final fallbackDir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    final fallbackPath = p.join(fallbackDir.path, fileName);
    await File(fallbackPath).writeAsString(jsonContent, flush: true);
    return fallbackPath;
  }

  final Directory targetDir;
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    targetDir = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
  } else {
    targetDir = await getApplicationDocumentsDirectory();
  }

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final filePath = p.join(targetDir.path, fileName);
  await File(filePath).writeAsString(jsonContent, flush: true);
  return filePath;
}

Future<String> readCmonuFileFromPathImpl(String filePath) async {
  return File(filePath).readAsString();
}
