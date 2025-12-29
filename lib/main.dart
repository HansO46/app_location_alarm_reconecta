import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/onboarding_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/welcome_page.dart';
import 'package:app_location_alarm_reconecta/services/background_service.dart';
import 'package:app_location_alarm_reconecta/services/geofencing_service.dart';
import 'package:app_location_alarm_reconecta/services/alarm_notification_service.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarm_triggered_page.dart'; // Importar AlarmTriggeredPage
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Para jsonDecode
import 'package:flutter/services.dart'; // Para MethodChannel
import 'dart:ui';
import 'dart:isolate';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart'; // Importar modelo Alarm
import 'package:android_intent_plus/android_intent.dart'; // Importar AndroidIntent
import 'package:android_intent_plus/flag.dart'; // Importar Flags

// IMPORTANTE: Puerto para comunicación entre isolates (Background -> UI)
const String kAlarmPortName = 'alarm_notification_port';

// NavigatorKey global para permitir navegación desde servicios
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Inicializar Flutter binding primero
  WidgetsFlutterBinding.ensureInitialized();

  // Registrar puerto de comunicación para recibir mensajes del background isolate
  // Esto permite que si la app está en foreground, navegue automáticamente
  final ReceivePort receiverPort = ReceivePort();
  IsolateNameServer.removePortNameMapping(kAlarmPortName);
  IsolateNameServer.registerPortWithName(receiverPort.sendPort, kAlarmPortName);

  receiverPort.listen((message) {
    if (message is String) {
      // Mensaje de ID de alarma recibido
      print('Main: Recibido mensaje de alarma del background isolate: $message');
      _navigateToAlarmPage(message);
    }
  });

  // MapLibre NO requiere tokens/keys - es completamente open source
  // No necesitamos configurar ningún ACCESS_TOKEN

  // Inicializar tema de forma síncrona (es rápido)
  await initThemeMode();

  // Inicializar servicio de notificaciones en MAIN isolate
  // Envolver en try-catch para no crashear si falla
  try {
    await AlarmNotificationService().initialize();
    print('Main: AlarmNotificationService inicializado correctamente');
  } catch (e) {
    print('Main: Error inicializando AlarmNotificationService: $e');
    // Continuar sin notificaciones si falla
  }

  // Iniciar la app inmediatamente
  runApp(const MyApp());

  // Diferir inicialización pesada hasta después del primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await BackgroundService().initializeService();
    // Indicar al servicio de geofencing del UI que el monitoreo lo hace el background
    GeofencingService().setUsingBackgroundService(true);
  });
}

// Flag global para evitar duplicación de páginas de alarma
bool isAlarmPageOpen = false;

/// Helper para navegar a la página de alarma desde el UI Isolate
void _navigateToAlarmPage(String alarmId) async {
  print('Main: Navegando a alarma $alarmId');

  if (isAlarmPageOpen) {
    print('Main: Alarma ya en pantalla (flag=true), ignorando navegación duplicada');

    // Si la app está en background/minimizada, igual intentamos traerla al frente
    // aunque no naveguemos de nuevo
    try {
      const platform = MethodChannel('com.example.app_location_alarm_reconecta/alarm');
      await platform.invokeMethod('bringToFront');
    } catch (e) {/* ignore */}

    return;
  }

  // 1. Intentar traer la app al frente usando Android Intent
  print('Main: Intentando traer la app al frente...');
  try {
    final intent = AndroidIntent(
      package: 'com.example.app_location_alarm_reconecta',
      componentName: 'com.example.app_location_alarm_reconecta.MainActivity',
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      flags: [
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_CLEAR_TOP,
        Flag.FLAG_ACTIVITY_SINGLE_TOP,
      ],
    );
    await intent.launch();
    print('Main: Intent lanzado para traer app al frente');
  } catch (e) {
    print('Main: Error lanzando intent: $e');
  }

  // 2. Navegar internamente en Flutter
  final context = navigatorKey.currentContext;
  if (context != null) {
    // Cargar la alarma completa desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final alarmsJson = prefs.getStringList(KConstants.alarmsKey) ?? [];

    Alarm? foundAlarm;
    for (String jsonStr in alarmsJson) {
      final alarm = Alarm.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      if (alarm.id == alarmId) {
        foundAlarm = alarm;
        break;
      }
    }

    if (foundAlarm != null) {
      isAlarmPageOpen = true; // Marcar como abierta
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => AlarmTriggeredPage(
            alarm: foundAlarm!,
            openedFromBackground: false,
          ),
        ),
      )
          .then((_) {
        // Cuando se cierra la página, liberar el flag
        isAlarmPageOpen = false;
        print('Main: AlarmTriggeredPage cerrada, flag liberado');
      });
    }
  }
}

Future<void> initThemeMode() async {
  try {
    // Obtain shared preferences.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? repeat = prefs.getBool(KConstants.themeModeKey);
    isDarkModeNotifier.value = repeat ?? true; //if the value is null, set it to true
  } catch (e) {
    // If there's an error, use the default value
    isDarkModeNotifier.value = true;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Usar el navigatorKey global
          title: 'Flutter Demo',
          theme: ThemeData(
            // This is the theme of your application.
            //
            // TRY THIS: Try running your application with "flutter run". You'll see
            // the application has a purple toolbar. Then, without quitting the app,
            // try changing the seedColor in the colorScheme below to Colors.green
            // and then invoke "hot reload" (save your changes or press the "hot
            // reload" button in a Flutter-supported IDE, or press "r" if you used
            // the command line to start the app).
            //
            // Notice that the counter didn't reset back to zero; the application
            // state is not lost during the reload. To reset the state, use hot
            // restart instead.
            //
            // This works for code too, not just values: Most code changes can be
            // tested with just a hot reload.
            colorScheme: ColorScheme.fromSeed(
              seedColor: KColors.mainColor,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          debugShowCheckedModeBanner: false,
          home: const InitialPermissionCheck(),
        );
      },
    );
  }
}

class InitialPermissionCheck extends StatefulWidget {
  const InitialPermissionCheck({super.key});

  @override
  State<InitialPermissionCheck> createState() => _InitialPermissionCheckState();
}

class _InitialPermissionCheckState extends State<InitialPermissionCheck> {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Pequeño delay para que se vea el logo o splash si hubiera
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // 1. Verificar si es la primera vez que abre la app (Welcome Page)
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenWelcome = prefs.getBool(KConstants.hasSeenWelcomeKey) ?? false;

    if (hasSeenWelcome) {
      // Primera vez -> Ir a Welcome Page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
      return;
    }

    // 2. Si ya vio la bienvenida, verificar permisos
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      // Si tiene permiso, vamos a la app principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AlarmsPage()),
      );
    } else {
      // Si no tiene permiso (pero ya vio welcome), ir a onboarding para pedirlo
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingPage(isFirstTime: false)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
