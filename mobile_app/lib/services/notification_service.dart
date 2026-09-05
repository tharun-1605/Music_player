import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    _isInitialized = true;
  }

  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return true;
    await init();

    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission() ?? false;
      return granted;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
      return granted;
    }
    return true;
  }

  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
    int maxProgress = 100,
  }) async {
    if (kIsWeb) return;
    await init();

    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download Progress',
      channelDescription: 'Notifications for song and playlist downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
      icon: '@mipmap/launcher_icon',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }

  Future<void> showDownloadCompleted({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download Progress',
      channelDescription: 'Notifications for song and playlist downloads',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showProgress: false,
      ongoing: false,
      icon: '@mipmap/launcher_icon',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }
}
