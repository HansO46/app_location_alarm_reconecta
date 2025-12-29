import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:app_location_alarm_reconecta/views/pages/destination_page.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';

/// Servicio eficiente de geofencing que usa polling inteligente
/// Solo verifica cuando hay alarmas activas y ajusta el intervalo según el movimiento
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  Timer? _monitoringTimer;
  List<Alarm> _activeAlarms = [];
  bool _isMonitoring = false;
  Position? _lastPosition;
  DateTime? _lastCheckTime;

  // Intervalos adaptativos (en segundos)
  static const int _fastInterval = 15; // Cuando hay movimiento reciente
  static const int _slowInterval = 60; // Cuando está quieto
  static const int _verySlowInterval = 180; // Cuando está muy quieto (3 min)

  // Callback cuando se detecta entrada en un geofence
  Function(Alarm)? onEnterGeofence;

  // Callback cuando se detecta salida de un geofence
  Function(Alarm)? onExitGeofence;

  // Flag para indicar si el monitoreo es manejado externamente (ej. BackgroundService)
  bool _useExternalMonitoring = false;

  void setUsingBackgroundService(bool value) {
    _useExternalMonitoring = value;
    if (_useExternalMonitoring) {
      stopMonitoring();
    }
  }

  /// Iniciar monitoreo de alarmas activas
  Future<void> startMonitoring(List<Alarm> alarms) async {
    // Filtrar solo alarmas activas
    _activeAlarms = alarms.where((alarm) => alarm.isActive).toList();

    if (_activeAlarms.isEmpty) {
      stopMonitoring();
      return;
    }

    // Si usamos servicio de fondo, no iniciamos el timer en este isolate (UI)
    // Pero mantenemos la lista de alarmas activas por si acaso
    if (_useExternalMonitoring) {
      print('GeofencingService: Monitoreo delegado al servicio en segundo plano');
      return;
    }

    if (_isMonitoring) {
      return; // Ya está monitoreando
    }

    _isMonitoring = true;
    print('GeofencingService: Iniciando monitoreo de ${_activeAlarms.length} alarmas activas');

    // Verificar permisos
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GeofencingService: Servicio de ubicación deshabilitado');
      _isMonitoring = false;
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('GeofencingService: Permisos de ubicación denegados');
        _isMonitoring = false;
        return;
      }
    }

    // Primera verificación inmediata
    await _checkGeofences();

    // Iniciar timer con intervalo adaptativo
    _startAdaptiveTimer();
  }

  /// Detener monitoreo
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _activeAlarms.clear();
    _lastPosition = null;
    _lastCheckTime = null;
    print('GeofencingService: Monitoreo detenido');
  }

  /// Actualizar lista de alarmas activas
  void updateAlarms(List<Alarm> alarms) {
    _activeAlarms = alarms.where((alarm) => alarm.isActive).toList();

    if (_activeAlarms.isEmpty && _isMonitoring) {
      stopMonitoring();
    } else if (_activeAlarms.isNotEmpty && !_isMonitoring) {
      startMonitoring(_activeAlarms);
    }
  }

  /// Verificar si estamos dentro de algún geofence
  Future<void> _checkGeofences() async {
    try {
      Position? currentPosition;

      try {
        // Intentar obtener ubicación actual con timeout
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, // Bajo consumo de batería
            timeLimit: Duration(seconds: 5), // Timeout de 5 segundos
          ),
        ).timeout(
          const Duration(seconds: 5),
        );
      } on TimeoutException {
        print('GeofencingService: Timeout obteniendo ubicación');
        if (_lastPosition != null) {
          currentPosition = _lastPosition; // Usar última posición conocida
        } else {
          return; // No hay ubicación disponible
        }
      } catch (e) {
        print('GeofencingService: Error obteniendo ubicación: $e');
        if (_lastPosition != null) {
          currentPosition = _lastPosition;
        } else {
          return; // No hay ubicación disponible
        }
      }

      if (currentPosition == null) return;

      // Calcular distancia a cada alarma activa
      for (Alarm alarm in _activeAlarms) {
        double distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          alarm.latitude,
          alarm.longitude,
        );

        // Verificar si estamos dentro del radio
        if (distance <= alarm.radius) {
          // Estamos dentro del geofence
          if (onEnterGeofence != null) {
            onEnterGeofence!(alarm);
          }
        }
      }

      // Actualizar última posición y tiempo
      _lastPosition = currentPosition;
      _lastCheckTime = DateTime.now();
    } catch (e) {
      print('GeofencingService: Error en _checkGeofences: $e');
    }
  }

  /// Iniciar timer con intervalo adaptativo
  void _startAdaptiveTimer() {
    _monitoringTimer?.cancel();

    int interval = _calculateAdaptiveInterval();

    _monitoringTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      if (!_isMonitoring || _activeAlarms.isEmpty) {
        timer.cancel();
        return;
      }

      await _checkGeofences();

      // Recalcular intervalo para el próximo ciclo
      int newInterval = _calculateAdaptiveInterval();
      if (newInterval != interval) {
        interval = newInterval;
        timer.cancel();
        _startAdaptiveTimer(); // Reiniciar con nuevo intervalo
      }
    });
  }

  /// Calcular intervalo adaptativo basado en movimiento
  int _calculateAdaptiveInterval() {
    if (_lastPosition == null || _lastCheckTime == null) {
      return _fastInterval; // Primera vez, verificar rápido
    }

    // Si pasó mucho tiempo desde la última verificación, usar intervalo rápido
    Duration timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
    if (timeSinceLastCheck.inSeconds > _verySlowInterval) {
      return _fastInterval;
    }

    // Por ahora usar intervalo medio (se puede mejorar detectando movimiento real)
    // En una implementación más avanzada, se podría usar acelerómetro o cambios significativos de posición
    return _slowInterval;
  }

  /// Verificar si está monitoreando
  bool get isMonitoring => _isMonitoring;

  /// Obtener número de alarmas activas
  int get activeAlarmsCount => _activeAlarms.length;
}
