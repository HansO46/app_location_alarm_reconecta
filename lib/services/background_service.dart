import 'dart:async';
import 'dart:ui';
import 'dart:isolate'; // Necesario para ReceivePort
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_location_alarm_reconecta/services/geofencing_service.dart';
import 'package:app_location_alarm_reconecta/services/alarm_manager.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:app_location_alarm_reconecta/services/alarm_sound_service.dart'; // Necesario para AlarmSoundService

/// Servicio para manejar la ejecución en segundo plano
@pragma('vm:entry-point')
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  /// Inicializar el servicio de fondo
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configura notificaciones locales para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_alarm_channel', // id
      'Location Alarm Service', // title
      description: 'Used for important notifications.', // description
      importance: Importance.low, // Low para no hacer ruido/vibrar en cada actualización
      playSound: false, // No reproducir sonido
      enableVibration: false, // No vibrar
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    /*if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }
    */
    // Icono debe estar en android/app/src/main/res/drawable/
    // Usaremos el de launcher por defecto si no existe uno específico
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Se ejecuta cuando el servicio inicia
        onStart: onStart,

        // Se auto inicia al bootear dispositivos si es true
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId: 'location_alarm_channel',
        initialNotificationTitle: 'Tracking route',
        initialNotificationContent: 'Monitoring your position...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // Para iOS se requieren configuraciones adicionales en Info.plist
    // y usar BGTaskScheduler, pero este plugin ayuda con el fetch básico
    return true;
  }

  /// Entry point para el isolate en background
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Asegurar binding de Flutter en el background isolate
    DartPluginRegistrant.ensureInitialized();

    // Inicializar dependencias necesarias en este isolate
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Instancia de GeofencingService para este isolate
    // Nota: GeofencingService es singleton, pero en un nuevo isolate es una nueva instancia
    final geofencingService = GeofencingService();
    final alarmManager = AlarmManager(); // Para cargar alarmas

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Cargar alarmas y comenzar monitoreo
    print("BackgroundService: Iniciando monitoreo en segundo plano");

    // Aquí necesitamos lógica para monitorear periódicamente
    // Como GeofencingService ya tiene lógica de Timer, podemos aprovecharla
    // Pero necesitamos cargar las alarmas primero

    // Escuchar actualizaciones de alarmas desde el UI isolate si fuera necesario,
    // pero por ahora cargamos de SharedPreferences cada cierto tiempo o al iniciar

    await _startMonitoringLogic(service, geofencingService, alarmManager);
  }

  static Future<void> _startMonitoringLogic(ServiceInstance service,
      GeofencingService geofencingService, AlarmManager alarmManager) async {
    // Función auxiliar para actualizar notificación
    void updateNotification(List<Alarm> alarms) {
      if (service is AndroidServiceInstance) {
        int activeAlarms = alarms.where((a) => a.isActive).length;
        String title = 'Reconecta';
        String content = '';

        print(
            'BackgroundService: updateNotification - Total alarms: ${alarms.length}, Active: $activeAlarms');

        if (alarms.isEmpty) {
          // Sin alarmas: mostrar que el servicio está listo
          content = 'Location monitoring service ready';
        } else if (activeAlarms > 0) {
          content = 'Monitoring $activeAlarms ${activeAlarms == 1 ? 'alarm' : 'alarms'}';
        } else {
          content = 'All alarms are paused';
        }

        print('BackgroundService: Notification content: $content');

        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    }

    // Cargar alarmas iniciales
    List<Alarm> alarms = await alarmManager.loadAllAlarms();
    print("BackgroundService: Cargadas ${alarms.length} alarmas");

    // Actualizar notificación inicial
    updateNotification(alarms);

    if (alarms.isNotEmpty) {
      // Iniciar el monitoreo solo si hay alarmas (activas o no, GeofencingService filtra las activas)
      geofencingService.startMonitoring(alarms);
    }

    // Configurar un timer periódico para recargar alarmas y actualizar notificación
    // Solo actualiza si hay cambios para evitar ruido/vibración constante
    int lastAlarmCount = alarms.length;
    // Registrar puerto para recibir orden de detener alarma desde UI
    final stopPort = ReceivePort();
    IsolateNameServer.removePortNameMapping('alarm_background_stop_port');
    IsolateNameServer.registerPortWithName(stopPort.sendPort, 'alarm_background_stop_port');

    stopPort.listen((message) {
      if (message == 'stop_alarm') {
        print('BackgroundService: Recibida orden de detener alarma');
        AlarmSoundService().stopAlarm();
      }
    });

    // Iniciar timer de geofencing
    // Usamos un Timer periódico para chequear ubicación
    int lastActiveCount = alarms.where((a) => a.isActive).length;

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      List<Alarm> updatedAlarms = await alarmManager.loadAllAlarms();
      int currentAlarmCount = updatedAlarms.length;
      int currentActiveCount = updatedAlarms.where((a) => a.isActive).length;

      // Solo actualizar si cambió el número de alarmas o alarmas activas
      if (currentAlarmCount != lastAlarmCount || currentActiveCount != lastActiveCount) {
        geofencingService.updateAlarms(updatedAlarms);
        updateNotification(updatedAlarms);
        lastAlarmCount = currentAlarmCount;
        lastActiveCount = currentActiveCount;
        print(
            'BackgroundService: Alarmas actualizadas - Total: $currentAlarmCount, Activas: $currentActiveCount');
      }
    });
  }
}
