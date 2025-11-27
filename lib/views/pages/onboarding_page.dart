import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/category_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

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
                final status = await Permission.locationWhenInUse.request();

                if (status.isGranted) {
                  // Solo navegar si el permiso fue otorgado
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CategorySelectionPage()),
                  );
                } else {
                  // Mostrar mensaje si fue denegado
                  // o pedir que vaya a configuración
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
              ))
        ],
      ),
    );
  }
}
