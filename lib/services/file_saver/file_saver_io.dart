import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> saveCsvToDownloads(String fileName, String content) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}

  if (dir == null && Platform.isAndroid) {
    final androidDownload = Directory('/storage/emulated/0/Download');
    if (await androidDownload.exists()) {
      dir = androidDownload;
    }
  }

  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  return file.path;
}
