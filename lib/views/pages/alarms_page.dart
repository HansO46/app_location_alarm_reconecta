import 'dart:convert';
import 'dart:typed_data';
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:app_location_alarm_reconecta/views/pages/category_selection_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/editing_alarm_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/settings_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/tutorial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  List<Alarm> _alarms = [];
  bool _isLoading = true;
  String _selectedUnit = 'meters'; // Unidad predeterminada para mostrar el radio

  @override
  void initState() {
    super.initState();
    _loadPreferredUnit();
    _loadAlarms();
  }

  // Cargar unidad preferida desde SharedPreferences
  Future<void> _loadPreferredUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUnit = prefs.getString(KConstants.preferredUnitKey);
      if (savedUnit != null) {
        setState(() {
          _selectedUnit = savedUnit;
        });
      }
    } catch (e) {
      print('Error cargando unidad preferida: $e');
    }
  }

  // Obtener icono según la categoría
  IconData? _getCategoryIcon(String? category) {
    switch (category) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'train':
        return Icons.train;
      case 'other':
        return Icons.location_city;
      default:
        return null;
    }
  }

  // Convertir de metros a otra unidad
  double _convertFromMeters(double meters, String unit) {
    switch (unit) {
      case 'meters':
        return meters;
      case 'kilometers':
        return meters / 1000.0;
      case 'miles':
        return meters / 1609.34;
      case 'feet':
        return meters / 0.3048;
      case 'yards':
        return meters / 0.9144;
      default:
        return meters;
    }
  }

  // Obtener el símbolo de la unidad
  String _getUnitSymbol(String unit) {
    switch (unit) {
      case 'meters':
        return 'm';
      case 'kilometers':
        return 'km';
      case 'miles':
        return 'mi';
      case 'feet':
        return 'ft';
      case 'yards':
        return 'yd';
      default:
        return 'm';
    }
  }

  // Formatear el valor según la unidad
  String _formatRadius(double meters, String unit) {
    double value = _convertFromMeters(meters, unit);
    String symbol = _getUnitSymbol(unit);
    // Mostrar 0 decimales para metros, 2 para el resto
    int decimals = unit == 'meters' ? 0 : 2;
    return '${value.toStringAsFixed(decimals)} $symbol';
  }

  // Decodificar imagen base64 de forma asíncrona para no bloquear el main thread
  Future<Uint8List?> _decodeImageAsync(String base64String) async {
    try {
      return await compute(_decodeBase64, base64String);
    } catch (e) {
      print('Error decodificando imagen: $e');
      return null;
    }
  }

  // Función estática para usar con compute
  static Uint8List _decodeBase64(String base64String) {
    return base64Decode(base64String);
  }

  Future<void> _loadAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? alarmsJson = prefs.getStringList(KConstants.alarmsKey);

      if (alarmsJson == null || alarmsJson.isEmpty) {
        setState(() {
          _alarms = [];
          _isLoading = false;
        });
        return;
      }

      List<Alarm> alarms = alarmsJson.map((jsonString) {
        Map<String, dynamic> json = jsonDecode(jsonString);
        return Alarm.fromJson(json);
      }).toList();

      setState(() {
        _alarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando alarmas: $e');
      setState(() {
        _alarms = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text('Alarms'),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(context, _createRoute());
              },
              icon: Icon(Icons.settings)),
          IconButton(
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (context) => CategorySelectionPage()));
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? KConstants.hasSeenWelcome
                  ? HomePage()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alarm_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No alarmas added yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Press + button to add a new alarm',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información de la alarma
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(
                                    children: [
                                      if (_getCategoryIcon(alarm.category) != null)
                                        Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(_getCategoryIcon(alarm.category), size: 20),
                                        ),
                                      Text(
                                        alarm.name,
                                        style: KTextStyles.alarmTextStyle,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditingAlarmPage(alarm: alarm)));
                                            // Recargar alarmas si se guardaron cambios o se eliminó
                                            if (result == true) {
                                              await _loadAlarms();
                                            }
                                          },
                                          icon: Icon(Icons.edit)),
                                    ],
                                  )
                                ]),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        alarm.address,
                                        style: KTextStyles.alarmDetailsTextStyle,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.radio_button_checked, size: 16, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      'Radius: ${_formatRadius(alarm.radius, _selectedUnit)}',
                                      style: KTextStyles.alarmDetailsTextStyle,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                              ],
                            ),
                          ),
                          // Imagen previa del mapa (decodificada de forma asíncrona)
                          if (alarm.previewImageBase64 != null)
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              child: FutureBuilder<Uint8List?>(
                                future: _decodeImageAsync(alarm.previewImageBase64!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Image.memory(
                                      snapshot.data!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: Center(
                                            child: Icon(Icons.image_not_supported,
                                                size: 48, color: Colors.grey[600]),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: Icon(Icons.image_not_supported,
                                          size: 48, color: Colors.grey[600]),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
    transitionDuration: const Duration(milliseconds: 1000),
    reverseTransitionDuration: const Duration(microseconds: 1000),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.bounceOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}
