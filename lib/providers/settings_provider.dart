import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SettingsProvider with ChangeNotifier {
  double _desiredRetention = 0.90; // Valeur par défaut standard FSRS (90%)

  double get desiredRetention => _desiredRetention;
  int get desiredRetentionPercent => (_desiredRetention * 100).round();

  /// Charge les réglages sauvegardés
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data.containsKey('desiredRetention')) {
          final val = (data['desiredRetention'] as num).toDouble();
          if (val >= 0.70 && val <= 0.98) {
            _desiredRetention = val;
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  /// Met à jour le taux de rétention cible (entre 70% et 98%)
  Future<void> setDesiredRetention(double value) async {
    final clamped = value.clamp(0.70, 0.98);
    _desiredRetention = double.parse(clamped.toStringAsFixed(2));
    notifyListeners();

    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      final data = {
        'desiredRetention': _desiredRetention,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}
