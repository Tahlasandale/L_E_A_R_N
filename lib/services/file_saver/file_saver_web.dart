// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

Future<String?> saveCsvToDownloads(String fileName, String content) async {
  final blob = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Téléchargements ($fileName)';
}

Future<XFile> createShareXFile(String fileName, String content, String mimeType) async {
  return XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    name: fileName,
    mimeType: mimeType,
  );
}
