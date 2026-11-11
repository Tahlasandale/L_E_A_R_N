import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/flashcard.dart';
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

  /// Demande les permissions de notification
  Future<bool?> requestPermissions() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission();
    }
    return true;
  }

  /// Affiche immédiatement une notification test
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    await init();
    const androidDetails = AndroidNotificationDetails(
      'kawaii_channel',
      'Rappels Flashcards',
      channelDescription: 'Notifications quand le seuil critique de cartes est atteint',
      importance: Importance.max,
      priority: Priority.high,
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
  }

  /// Planifie une notification prédictive calculée d'après le seuil FSRS
  Future<void> scheduleOnAppPause({
    required List<Flashcard> allCards,
    double desiredRetention = 0.90,
  }) async {
    if (kIsWeb || allCards.isEmpty) return;
    await init();

    final dueDates = allCards.map((c) => c.dueDate).toList();
    final criticalDate = FsrsService.findCriticalDueDate(
      dueDates: dueDates,
      totalCards: allCards.length,
      desiredRetention: desiredRetention,
    );

    if (criticalDate == null) return;

    final threshold = FsrsService.calculateCriticalThreshold(allCards.length, desiredRetention: desiredRetention);
    final now = DateTime.now();

    // Si le seuil est déjà dépassé maintenant, ou si la date est passée
    if (criticalDate.isBefore(now)) {
      return;
    }

    try {
      final scheduledTz = tz.TZDateTime.from(criticalDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'kawaii_critical_channel',
        'Seuil Critique FSRS',
        channelDescription: 'Notification prédictive sans batterie',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notificationsPlugin.zonedSchedule(
        id: 1,
        title: 'Kawaii Flashcards ⚡',
        body: "(ง'̀-'́)ง $threshold cartes sont prêtes pour ta révision !",
        scheduledDate: scheduledTz,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  /// Annule toutes les notifications programmées
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
