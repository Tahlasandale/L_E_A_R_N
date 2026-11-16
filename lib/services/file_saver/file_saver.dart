import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart';

class FileSaverService {
  static Future<String?> saveCsv(String fileName, String content) =>
      saveCsvToDownloads(fileName, content);

  static Future<String?> saveFile(String fileName, String content) =>
      saveCsvToDownloads(fileName, content);

  /// Permet à l'utilisateur de choisir où enregistrer le fichier (sur Android / PC / Web)
  static Future<String?> pickAndSaveFile(
    String fileName,
    String content, {
    String mimeType = 'text/plain',
  }) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Choisir l\'emplacement de sauvegarde...',
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (uri != null) {
        return uri.path.isNotEmpty ? uri.path : fileName;
      }
      return null;
    } catch (_) {
      // Fallback automatique vers le dossier Téléchargements standard
      return saveCsvToDownloads(fileName, content);
    }
  }

  /// Partage en tant que véritable pièce jointe fichier (.csv ou .json)
  static Future<void> shareAsFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    final xfile = await createShareXFile(fileName, content, mimeType);
    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        fileNameOverrides: [fileName],
        subject: subject ?? fileName,
        title: subject ?? fileName,
      ),
    );
  }
}
