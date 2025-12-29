import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:app_location_alarm_reconecta/services/alarm_manager.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AlarmTriggeredPage extends StatefulWidget {
  final Alarm alarm;
  final bool openedFromBackground; // true si se abrió desde notificación con app cerrada

  const AlarmTriggeredPage({
    Key? key,
    required this.alarm,
    this.openedFromBackground = false,
  }) : super(key: key);

  @override
  State<AlarmTriggeredPage> createState() => _AlarmTriggeredPageState();
}

class _AlarmTriggeredPageState extends State<AlarmTriggeredPage> {
  @override
  void initState() {
    super.initState();
    // Reproducir sonido al abrir la página
    // El sonido ya se reproduce desde AlarmManager cuando se dispara
    // NO detener aquí, esperar a que el usuario presione OK
  }

  void _handleOkay() async {
    // Detener el sonido de la alarma
    AlarmManager().stopCurrentAlarm();

    // Para pruebas: apagar la alarma automáticamente para que no se vuelva a disparar
    try {
      await AlarmManager().toggleAlarm(widget.alarm.id, false); // false = apagar
      print('AlarmTriggeredPage: Alarma ${widget.alarm.name} apagada automáticamente');
    } catch (e) {
      print('AlarmTriggeredPage: Error apagando alarma: $e');
    }

    if (widget.openedFromBackground) {
      // Si se abrió desde background (app cerrada), simplemente cerrar la actividad
      // Esto devolverá al usuario a donde estaba (otra app, home screen, etc.)
      Navigator.of(context).pop();
    } else {
      // Si la app ya estaba abierta, navegar a AlarmsPage
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AlarmsPage()),
        (route) => false, // Remover todas las rutas anteriores
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Detener sonido si presiona back button
        AlarmManager().stopCurrentAlarm();
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'You’ve arrived at your destination',
                    style: KTextStyles.titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  Lottie.asset('assets/lotties/alarm.json'),
                  Text(
                    widget.alarm.address,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: _handleOkay,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(300, 60),
                      backgroundColor: KColors.mainColor,
                    ),
                    child: Text(
                      'Okay!',
                      style: KTextStyles.buttonTextStyle.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
