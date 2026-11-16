import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Provider gérant la série (Streak) de révisions quotidiennes
/// Règle métier : la série se rompt uniquement si l'on saute 2 jours de suite (tolérance d'un jour sauté).
class StreakProvider with ChangeNotifier {
  int _currentStreak = 0;
  int _bestStreak = 0;
  DateTime? _lastReviewDate;
  bool _reviewedToday = false;
  bool _isAtRisk = false;

  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  DateTime? get lastReviewDate => _lastReviewDate;
  bool get reviewedToday => _reviewedToday;
  bool get isAtRisk => _isAtRisk;

  /// Nombre de jours écoulés depuis la dernière révision (null si aucune révision)
  int? daysSinceLastReview([DateTime? nowOverride]) {
    if (_lastReviewDate == null) return null;
    final now = nowOverride ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(_lastReviewDate!.year, _lastReviewDate!.month, _lastReviewDate!.day);
    return today.difference(last).inDays;
  }

  /// Initialise la streak depuis le stockage persistant
  Future<void> init({DateTime? nowOverride}) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/streak_data.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        importJson(data, notify: false);
      }
    } catch (e) {
      debugPrint('StreakProvider init error: $e');
    }
    checkStreakStatus(nowOverride: nowOverride);
  }

  /// Recalcule l'état de la streak par rapport à la date actuelle
  void checkStreakStatus({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastReviewDate == null) {
      _currentStreak = 0;
      _reviewedToday = false;
      _isAtRisk = false;
      notifyListeners();
      return;
    }

    final last = DateTime(_lastReviewDate!.year, _lastReviewDate!.month, _lastReviewDate!.day);
    final diff = today.difference(last).inDays;

    if (diff == 0) {
      // Déjà révisé aujourd'hui !
      _reviewedToday = true;
      _isAtRisk = false;
    } else if (diff == 1) {
      // Révisé hier : série active en attente de la révision d'aujourd'hui
      _reviewedToday = false;
      _isAtRisk = false;
    } else if (diff == 2) {
      // 1 jour sauté (hier) : la série n'est PAS encore rompue mais est en danger critique aujourd'hui !
      _reviewedToday = false;
      _isAtRisk = true;
    } else {
      // diff >= 3 : 2 jours consécutifs complets ou plus ont été sautés -> Série rompue
      _currentStreak = 0;
      _reviewedToday = false;
      _isAtRisk = false;
    }

    notifyListeners();
  }

  /// Enregistre une révision effectuée aujourd'hui
  Future<void> recordReview({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastReviewDate == null) {
      _currentStreak = 1;
    } else {
      final last = DateTime(_lastReviewDate!.year, _lastReviewDate!.month, _lastReviewDate!.day);
      final diff = today.difference(last).inDays;

      if (diff == 0) {
        // Déjà révisé aujourd'hui, ne pas ré-incrémenter
        _reviewedToday = true;
        _isAtRisk = false;
        notifyListeners();
        return;
      } else if (diff == 1 || diff == 2) {
        // Hier ou avant-hier (1 jour sauté pardonné) : la série continue !
        _currentStreak += 1;
      } else {
        // diff >= 3 : au moins 2 jours sautés, nouvelle série
        _currentStreak = 1;
      }
    }

    _lastReviewDate = today;
    _reviewedToday = true;
    _isAtRisk = false;

    if (_currentStreak > _bestStreak) {
      _bestStreak = _currentStreak;
    }

    notifyListeners();
    await _saveData();
  }

  /// Sauvegarde locale
  Future<void> _saveData() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/streak_data.json');
      await file.writeAsString(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('StreakProvider save error: $e');
    }
  }

  /// Données sérialisées pour la sauvegarde universelle JSON
  Map<String, dynamic> toJson() {
    return {
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'lastReviewDate': _lastReviewDate?.toIso8601String(),
    };
  }

  /// Importe les données d'une sauvegarde
  void importJson(Map<String, dynamic> data, {bool notify = true}) {
    if (data.containsKey('currentStreak')) {
      _currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
    }
    if (data.containsKey('bestStreak')) {
      _bestStreak = (data['bestStreak'] as num?)?.toInt() ?? 0;
    }
    if (data.containsKey('lastReviewDate') && data['lastReviewDate'] != null) {
      try {
        _lastReviewDate = DateTime.parse(data['lastReviewDate'] as String);
      } catch (_) {}
    }
    if (notify) {
      checkStreakStatus();
    }
  }

  /// Pour tests unitaires ou remise à zéro manuelle
  void resetForTest({int currentStreak = 0, int bestStreak = 0, DateTime? lastReviewDate}) {
    _currentStreak = currentStreak;
    _bestStreak = bestStreak;
    _lastReviewDate = lastReviewDate;
    checkStreakStatus();
  }
}
