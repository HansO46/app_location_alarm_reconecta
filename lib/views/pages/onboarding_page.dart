import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/category_selection_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingPage extends StatefulWidget {
  final bool isFirstTime;
  const OnboardingPage({super.key, this.isFirstTime = true});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 100),
            child: Text(
              'Reconnecta utiliza tu ubicación',
              style: KTextStyles.titleStyle,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          Lottie.asset('assets/lotties/location.json'),
          SizedBox(
            height: 150,
          ),
          FilledButton(
            onPressed: () async {
              // 1. Pedir permiso de ubicación
              final locationStatus = await Permission.locationWhenInUse.request();

              if (locationStatus.isGranted) {
                // 2. Pedir permiso de notificaciones (Android 13+)
                if (await Permission.notification.isDenied) {
                  await Permission.notification.request();
                }

                // 3. Navegar según si es la primera vez o recuperación de permisos
                if (widget.isFirstTime) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => CategorySelectionPage()),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AlarmsPage()),
                  );
                }
              } else {
                // Mostrar mensaje si fue denegado
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Necesitamos tu ubicación para avisarte cuando llegues.'),
                    action: SnackBarAction(
                      label: 'Configuración',
                      onPressed: () => openAppSettings(),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Bordes ligeramente redondeados
              ),
              minimumSize: Size(300, 50), // Ancho y alto iguales
            ),
            child: Text(
              'Permitir acceso',
              style: KTextStyles.buttonTextStyle,
            ),
          )
        ],
      ),
    );
  }
}
