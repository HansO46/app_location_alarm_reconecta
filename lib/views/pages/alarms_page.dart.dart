import 'dart:convert';
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:app_location_alarm_reconecta/views/pages/destination_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  List<Alarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  // Eliminar una alarma por ID
  Future<void> _deleteAlarm(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Usar la lista actual de alarmas (_alarms)
      List<Alarm> alarms = List.from(_alarms);

      // Filtrar la alarma a eliminar
      alarms.removeWhere((alarm) => alarm.id == alarmId);

      // Guardar lista actualizada
      List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(KConstants.alarmsKey, alarmsJson);

      // Recargar las alarmas para actualizar la UI
      await _loadAlarms();

      print('Alarma eliminada: $alarmId');
    } catch (e) {
      print('Error eliminando alarma: $e');
    }
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => DestinationPage()));
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? Center(
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
                                  Text(
                                    alarm.name,
                                    style: KTextStyles.alarmTextStyle,
                                  ),
                                  Row(
                                    children: [
                                      IconButton(onPressed: () {}, icon: Icon(Icons.edit)),
                                      IconButton(
                                          color: Colors.red.shade200,
                                          onPressed: () async {
                                            await _deleteAlarm(alarm.id);
                                          },
                                          icon: Icon(Icons.delete)),
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
                                SizedBox(height: 4),
                              ],
                            ),
                          ),
                          // Imagen previa del mapa
                          if (alarm.previewImageBase64 != null)
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              child: Image.memory(
                                base64Decode(alarm.previewImageBase64!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
