import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

Future<String?> saveCsvToDownloads(String fileName, String content) async {
  return null;
}

Future<XFile> createShareXFile(String fileName, String content, String mimeType) async {
  return XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    name: fileName,
    mimeType: mimeType,
  );
}
