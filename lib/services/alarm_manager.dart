import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // Para IsolateNameServer
import 'dart:isolate'; // Para SendPort
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/services/geofencing_service.dart';
import 'package:app_location_alarm_reconecta/services/alarm_sound_service.dart';
import 'package:app_location_alarm_reconecta/services/alarm_notification_service.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarm_triggered_page.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_location_alarm_reconecta/main.dart'; // Para acceder al navigatorKey
import 'package:flutter/material.dart';

/// Orquestador principal del sistema de alarmas
/// Gestiona el ciclo de vida de las alarmas y coordina los servicios
class AlarmManager {
  static final AlarmManager _instance = AlarmManager._internal();
  factory AlarmManager() => _instance;
  AlarmManager._internal() {
    _initializeServices();
  }

  final GeofencingService _geofencingService = GeofencingService();
  final AlarmSoundService _soundService = AlarmSoundService();
  final AlarmNotificationService _notificationService = AlarmNotificationService();

  /// Inicializar servicios
  void _initializeServices() {
    // Configurar callbacks del servicio de geofencing
    _geofencingService.onEnterGeofence = (Alarm alarm) {
      _handleAlarmTriggered(alarm);
    };
  }

  /// Cargar todas las alarmas desde SharedPreferences
  Future<List<Alarm>> loadAllAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // CRÍTICO: Reload para forzar sincronización en background isolate
      // Sin esto, el background service no ve las alarmas guardadas desde el main isolate
      await prefs.reload();

      final List<String>? alarmsJson = prefs.getStringList(KConstants.alarmsKey);

      if (alarmsJson == null || alarmsJson.isEmpty) {
        return [];
      }

      return alarmsJson.map((jsonString) {
        Map<String, dynamic> json = jsonDecode(jsonString);
        return Alarm.fromJson(json);
      }).toList();
    } catch (e) {
      print('AlarmManager: Error cargando alarmas: $e');
      return [];
    }
  }

  /// Guardar alarmas en SharedPreferences
  Future<void> saveAlarms(List<Alarm> alarms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(KConstants.alarmsKey, alarmsJson);
    } catch (e) {
      print('AlarmManager: Error guardando alarmas: $e');
    }
  }

  /// Iniciar monitoreo de todas las alarmas activas
  Future<void> startMonitoring() async {
    List<Alarm> alarms = await loadAllAlarms();
    await _geofencingService.startMonitoring(alarms);
  }

  /// Detener monitoreo
  void stopMonitoring() {
    _geofencingService.stopMonitoring();
  }

  /// Activar/desactivar una alarma específica
  Future<void> toggleAlarm(String alarmId, bool isActive) async {
    List<Alarm> alarms = await loadAllAlarms();

    int index = alarms.indexWhere((a) => a.id == alarmId);
    if (index == -1) {
      print('AlarmManager: Alarma no encontrada: $alarmId');
      return;
    }

    // Actualizar estado de la alarma
    alarms[index] = alarms[index].copyWith(isActive: isActive);

    // Guardar cambios
    await saveAlarms(alarms);

    // Actualizar monitoreo
    _geofencingService.updateAlarms(alarms);

    print('AlarmManager: Alarma ${isActive ? "activada" : "desactivada"}: ${alarms[index].name}');
  }

  /// Manejar cuando se dispara una alarma
  void _handleAlarmTriggered(Alarm alarm) async {
    print('AlarmManager: ¡ALARMA DISPARADA! ${alarm.name}');

    // Reproducir sonido y vibración
    _soundService.playAlarm(alarm);

    // Mostrar notificación con full-screen intent
    // IMPORTANTE: Como el geofencing corre en background isolate,
    // navigatorKey.currentContext SIEMPRE es null.
    // Por eso SIEMPRE usamos la notificación para abrir la app.
    _notificationService.showAlarmTriggeredNotification(alarm);

    // Intentar navegar si la app está en foreground (comunicación entre isolates)
    try {
      final SendPort? uiSendPort = IsolateNameServer.lookupPortByName('alarm_notification_port');
      if (uiSendPort != null) {
        print('AlarmManager: Enviando mensaje al UI Isolate para navegar');
        uiSendPort.send(alarm.id);
      } else {
        print('AlarmManager: No se encontró puerto UI (probablemente app cerrada/suspenda)');
      }
    } catch (e) {
      print('AlarmManager: Error comunicando con UI Isolate: $e');
    }

    print('AlarmManager: Notificación mostrada - la app debería abrirse automáticamente');
  }

  /// Detener alarma actual
  void stopCurrentAlarm() {
    print('AlarmManager: Deteniendo alarma (local y background)...');

    // 1. Detener localmente (si está sonando en este isolate)
    _soundService.stopAlarm();

    // 2. Limpiar notificación
    _notificationService.cancelAllNotifications();

    // 3. Enviar orden de detención al background isolate
    try {
      final SendPort? backgroundStopPort =
          IsolateNameServer.lookupPortByName('alarm_background_stop_port');
      if (backgroundStopPort != null) {
        backgroundStopPort.send('stop_alarm');
        print('AlarmManager: Orden de stop enviada al background');
      }
    } catch (e) {
      print('AlarmManager: Error enviando stop al background: $e');
    }
  }

  /// Actualizar lista de alarmas (cuando se crean/editan/eliminan)
  Future<void> refreshAlarms() async {
    List<Alarm> alarms = await loadAllAlarms();
    _geofencingService.updateAlarms(alarms);
  }

  /// Verificar si está monitoreando
  bool get isMonitoring => _geofencingService.isMonitoring;

  /// Obtener número de alarmas activas
  int get activeAlarmsCount => _geofencingService.activeAlarmsCount;
}
