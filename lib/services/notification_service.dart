import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/flashcard.dart';
import '../providers/streak_provider.dart';
import 'fsrs_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialise le plugin de notification et les fuseaux horaires
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Ouvrir');
    const darwinSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(settings: initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init exception: $e');
    }
  }

  /// Demande proactivement toutes les permissions de notification
  Future<bool?> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      await init();
      if (!_isInitialized) return false;
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final notifGranted = await androidImpl.requestNotificationsPermission();
        try {
          await androidImpl.requestExactAlarmsPermission();
        } catch (_) {}
        return notifGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Notification requestPermissions exception: $e');
      return false;
    }
  }

  /// Affiche immédiatement une notification test et planifie un rappel à +5 secondes
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    try {
      await init();
      if (!_isInitialized) return;
      const androidDetails = AndroidNotificationDetails(
        'kawaii_streak_channel',
        'Séries & Rappels Quotidiens 🔥',
        channelDescription: 'Notifications et rappels pour maintenir ta flamme et réviser tes cartes',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: LinuxNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: 0,
        title: 'Kawaii Flashcards ⚡',
        body: '(◕‿◕) Les notifications fonctionnent à merveille !',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Notification showTestNotification exception: $e');
    }
  }

  /// Planifie les notifications fiables lorsque l'application passe en arrière-plan
  Future<void> scheduleOnAppPause({
    required List<Flashcard> allCards,
    double desiredRetention = 0.90,
    StreakProvider? streakProvider,
  }) async {
    if (kIsWeb) return;
    try {
      await init();
      if (!_isInitialized) return;

      final now = DateTime.now();

      // 1. NOTIFICATION DE STREAK / RAPPEL QUOTIDIEN (ID 2)
      await _scheduleStreakReminder(now: now, streakProvider: streakProvider);

      // 2. NOTIFICATION FSRS / CARTES EN SOUFFRANCE (ID 1)
      if (allCards.isNotEmpty) {
        await _scheduleFsrsReminder(
          now: now,
          allCards: allCards,
          desiredRetention: desiredRetention,
        );
      }
    } catch (e) {
      debugPrint('Notification scheduleOnAppPause exception: $e');
    }
  }

  /// Planifie le rappel quotidien pour sauver ou entretenir sa streak
  Future<void> _scheduleStreakReminder({
    required DateTime now,
    StreakProvider? streakProvider,
  }) async {
    DateTime targetTime;
    String title;
    String body;

    final currentStreak = streakProvider?.currentStreak ?? 0;
    final reviewedToday = streakProvider?.reviewedToday ?? false;
    final isAtRisk = streakProvider?.isAtRisk ?? false;

    if (reviewedToday) {
      // Déjà révisé aujourd'hui : planifier pour demain soir à 19h30
      final tomorrow = now.add(const Duration(days: 1));
      targetTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);
      title = 'Kawaii Flashcards 🔥';
      body = currentStreak > 0
          ? '(◕‿◕) Garde ta flamme allumée ! C\'est l\'heure de ta révision du jour ($currentStreak jours) !'
          : '(◕‿◕) C\'est l\'heure de ta révision quotidienne !';
    } else {
      // Pas encore révisé aujourd'hui !
      if (isAtRisk) {
        // En danger critique (1 jour sauté !)
        if (now.hour < 20) {
          final todayEvening = DateTime(now.year, now.month, now.day, 19, 30);
          targetTime = todayEvening.isAfter(now) ? todayEvening : now.add(const Duration(minutes: 30));
        } else {
          // Plus tard le soir : rappel dans 15 minutes
          targetTime = now.add(const Duration(minutes: 15));
        }
        title = '⚠️ Série en danger ! 🔥';
        body = "(ง'̀-'́)ง Tu as sauté hier ! Fais une révision avant minuit pour sauver ta flamme de $currentStreak jours !";
      } else {
        // Journée normale non révisée
        if (now.hour < 19) {
          targetTime = DateTime(now.year, now.month, now.day, 19, 30);
        } else {
          targetTime = now.add(const Duration(minutes: 45));
        }
        title = 'Kawaii Flashcards ⚡';
        body = currentStreak > 0
            ? '✨ Prends 2 minutes pour réviser et continuer ta série de $currentStreak jours !'
            : '(◕‿◕) 2 minutes de révision suffisent pour ancrer tes connaissances !';
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'kawaii_streak_channel',
      'Séries & Rappels Quotidiens 🔥',
      channelDescription: 'Notifications et rappels pour maintenir ta flamme',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _safeScheduleZoned(
      id: 2,
      title: title,
      body: body,
      scheduledDate: targetTime,
      androidDetails: androidDetails,
    );
  }

  /// Planifie le rappel FSRS basé sur les cartes dues ou le seuil critique
  Future<void> _scheduleFsrsReminder({
    required DateTime now,
    required List<Flashcard> allCards,
    required double desiredRetention,
  }) async {
    final dueCardsCount = allCards.where((c) => c.dueDate.isBefore(now)).length;

    DateTime? targetDate;
    String body = '';

    if (dueCardsCount > 0) {
      // Des cartes sont DÉJÀ dues quand on ferme l'appli ! Ne pas abandonner :
      // Planifier un rappel dans 2h (si journée) ou demain matin à 10h (si nuit)
      if (now.hour >= 22 || now.hour < 8) {
        final tomorrow = now.hour >= 22 ? now.add(const Duration(days: 1)) : now;
        targetDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      } else {
        targetDate = now.add(const Duration(hours: 2));
      }
      body = "(ง'̀-'́)ง $dueCardsCount cartes t'attendent ! 2 minutes de révision suffisent.";
    } else {
      // Aucune carte due maintenant : calculer la date critique FSRS
      final dueDates = allCards.map((c) => c.dueDate).toList();
      final criticalDate = FsrsService.findCriticalDueDate(
        dueDates: dueDates,
        totalCards: allCards.length,
        desiredRetention: desiredRetention,
      );

      if (criticalDate != null && criticalDate.isAfter(now)) {
        targetDate = criticalDate;
        final threshold = FsrsService.calculateCriticalThreshold(allCards.length, desiredRetention: desiredRetention);
        body = "(ง'̀-'́)ง $threshold cartes sont prêtes pour ta révision !";
      }
    }

    if (targetDate == null || body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'kawaii_critical_channel',
      'Seuil Critique FSRS ⚡',
      channelDescription: 'Notifications quand des cartes arrivent à échéance',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _safeScheduleZoned(
      id: 1,
      title: 'Kawaii Flashcards ⚡',
      body: body,
      scheduledDate: targetDate,
      androidDetails: androidDetails,
    );
  }

  /// Planifie en toute sécurité en gérant les restrictions d'alarmes exactes d'Android
  Future<void> _safeScheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required AndroidNotificationDetails androidDetails,
  }) async {
    try {
      final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

      // Tenter d'abord exactAllowWhileIdle
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // Fallback transparent vers inexact si permission alarme exacte refusée
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  /// Annule toutes les notifications programmées
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) return;
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Notification cancelAll error: $e');
    }
  }
}
