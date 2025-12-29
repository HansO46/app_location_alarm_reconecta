import 'dart:convert';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarm_triggered_page.dart';
import 'package:app_location_alarm_reconecta/main.dart'; // Para navigatorKey
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar notificaciones de alarmas
/// Incluye soporte para full-screen intent en Android
class AlarmNotificationService {
  static final AlarmNotificationService _instance = AlarmNotificationService._internal();
  factory AlarmNotificationService() => _instance;
  AlarmNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canal de notificaciones de alta prioridad
    // Android usa automáticamente el sonido de alarma por la categoría ALARM
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'alarm_triggered_channel',
      'Alarm Notifications',
      description: 'Notifications when you arrive at your destination',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
    print('AlarmNotificationService: Inicializado');
  }

  /// Callback cuando se toca la notificación
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    print('AlarmNotificationService: Notificación tocada');

    if (response.payload != null) {
      try {
        final String alarmId = response.payload!;
        final alarm = await _loadAlarmById(alarmId);
        if (alarm != null) {
          _navigateToAlarmPage(alarm, openedFromBackground: true);
        }
      } catch (e) {
        print('Error procesando payload de notificación: $e');
      }
    }
  }

  /// Cargar alarma por ID desde SharedPreferences
  Future<Alarm?> _loadAlarmById(String alarmId) async {
    print('AlarmNotificationService: Intentando cargar alarma ID: $alarmId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? alarmsJson = prefs.getStringList(KConstants.alarmsKey);

      print('AlarmNotificationService: Alarmas en SharedPreferences: ${alarmsJson?.length ?? 0}');

      if (alarmsJson == null || alarmsJson.isEmpty) {
        print('AlarmNotificationService: No hay alarmas guardadas');
        return null;
      }

      for (String jsonString in alarmsJson) {
        Map<String, dynamic> json = jsonDecode(jsonString);
        Alarm alarm = Alarm.fromJson(json);
        if (alarm.id == alarmId) {
          print('AlarmNotificationService: Alarma encontrada: ${alarm.name}');
          return alarm;
        }
      }

      print('AlarmNotificationService: Alarma $alarmId no encontrada');
      return null;
    } catch (e) {
      print('Error cargando alarma: $e');
      return null;
    }
  }

  /// Navegar a la página de alarma
  void _navigateToAlarmPage(Alarm alarm, {bool openedFromBackground = false}) {
    print('AlarmNotificationService: Intentando navegar para ${alarm.name}');
    try {
      final context = navigatorKey.currentContext;
      print('AlarmNotificationService: navigatorKey.currentContext = $context');

      if (context != null) {
        // Verificar flag global para evitar duplicados
        if (isAlarmPageOpen) {
          print('AlarmNotificationService: Alarma ya en pantalla, ignorando navegación duplicada');
          return;
        }

        print('AlarmNotificationService: Navegando...');
        isAlarmPageOpen = true; // Bloquear

        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => AlarmTriggeredPage(
              alarm: alarm,
              openedFromBackground: openedFromBackground,
            ),
          ),
        )
            .then((_) {
          isAlarmPageOpen = false; // Liberar al volver
          print('AlarmNotificationService: AlarmTriggeredPage cerrada, flag liberado');
        });
        print('AlarmNotificationService: Navegación iniciada para ${alarm.name}');
      } else {
        print('AlarmNotificationService: No hay contexto disponible para navegar');
      }
    } catch (e) {
      print('AlarmNotificationService: Error navegando: $e');
    }
  }

  /// Mostrar notificación de alarma disparada
  Future<void> showAlarmTriggeredNotification(Alarm alarm) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Solo enviar el ID de la alarma en el payload (no la imagen base64 que es muy grande)
    final String alarmPayload = alarm.id; // ✅ Solo el ID, no todo el objeto

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_triggered_channel',
      'Alarm Notifications',
      channelDescription: 'Notifications when you arrive at your destination',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: Color(0xFF2196F3),
      // Full-screen intent para mostrar incluso con pantalla bloqueada
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '¡Llegaste a tu destino!',
      styleInformation: BigTextStyleInformation(
        'Has llegado a: ${alarm.address}',
        contentTitle: '¡Llegaste a ${alarm.name}!',
        summaryText: 'Toca para ver detalles',
      ),
      // Hacer que el sonido se repita
      timeoutAfter: 60000, // 60 segundos
      ongoing: false, // Puede ser descartada
      autoCancel: true, // Se cancela al tocar
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      alarm.id.hashCode, // ID único basado en el ID de la alarma
      'You have reached your destination',
      alarm.name,
      notificationDetails,
      payload: alarmPayload,
    );

    print('AlarmNotificationService: Notificación mostrada para ${alarm.name}');
  }

  /// Cancelar notificación específica
  Future<void> cancelNotification(String alarmId) async {
    await _notificationsPlugin.cancel(alarmId.hashCode);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
