import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

/// Servicio para reproducir sonidos y vibraciones de alarmas
class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  bool _isPlaying = false;
  String? _currentAlarmId;

  /// Reproducir alarma (sonido + vibración)
  Future<void> playAlarm(Alarm alarm) async {
    if (_isPlaying && _currentAlarmId == alarm.id) {
      return; // Ya está sonando esta alarma
    }

    _isPlaying = true;
    _currentAlarmId = alarm.id;

    print('AlarmSoundService: Reproduciendo alarma: ${alarm.name}');

    try {
      // Reproducir sonido de alarma del sistema en loop y vibrar
      // Usamos la instancia por defecto del plugin
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true, // Importante: sonar hasta que se detenga
        volume: 1.0, // Volumen máximo
        asAlarm: true, // Usar canal de alarma
      );

      // 2. Iniciar vibración con patrón (loop)
      // Patrón: espera 0ms, vibra 1000ms, espera 500ms, repite...
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(
          pattern: [0, 1000, 500],
          repeat: 0, // Repetir desde el índice 0 (loop infinito)
        );
      }
    } catch (e) {
      print('AlarmSoundService: Error reproduciendo sonido: $e');
    }
  }

  /// Detener alarma
  void stopAlarm() {
    _isPlaying = false;
    _currentAlarmId = null;
    print('AlarmSoundService: Deteniendo alarma...');

    try {
      FlutterRingtonePlayer().stop();
      Vibration.cancel(); // Detener vibración
    } catch (e) {
      print('AlarmSoundService: Error deteniendo sonido/vibración: $e');
    }
  }

  /// Verificar si está reproduciendo
  bool get isPlaying => _isPlaying;

  /// Obtener ID de alarma actual
  String? get currentAlarmId => _currentAlarmId;
}
