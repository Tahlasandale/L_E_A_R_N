import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart';

class FileSaverService {
  static Future<String?> saveCsv(String fileName, String content) =>
      saveCsvToDownloads(fileName, content);

  static Future<String?> saveFile(String fileName, String content) =>
      saveCsvToDownloads(fileName, content);
}
