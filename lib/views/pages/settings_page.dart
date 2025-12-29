import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedUnit = 'meters'; // Unidad predeterminada

  @override
  void initState() {
    super.initState();
    _loadPreferredUnit();
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

  // Guardar unidad preferida en SharedPreferences
  Future<void> _savePreferredUnit(String unit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KConstants.preferredUnitKey, unit);
      setState(() {
        _selectedUnit = unit;
      });
    } catch (e) {
      print('Error guardando unidad preferida: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text('General', style: KTextStyles.titlesStyle),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('App Theme', style: KTextStyles.settingsTextStyle),
                          ValueListenableBuilder(
                            valueListenable: isDarkModeNotifier,
                            builder: (context, isDarkMode, child) {
                              return IconButton(
                                onPressed: () async {
                                  isDarkModeNotifier.value = !isDarkModeNotifier.value;
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool(
                                      KConstants.themeModeKey, isDarkModeNotifier.value);
                                },
                                icon: isDarkModeNotifier.value
                                    ? Icon(Icons.light_mode)
                                    : Icon(Icons.dark_mode),
                              );
                            },
                          )
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Language', style: KTextStyles.settingsTextStyle),
                          IconButton(onPressed: () {}, icon: Icon(Icons.language))
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Appareance', style: KTextStyles.settingsTextStyle),
                          IconButton(onPressed: () {}, icon: Icon(Icons.color_lens)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Preferred unit', style: KTextStyles.settingsTextStyle),
                          DropdownButton<String>(
                              value: _selectedUnit,
                              isDense: true,
                              underline: SizedBox.shrink(),
                              iconSize: 16,
                              items: [
                                DropdownMenuItem(value: 'meters', child: Text('m')),
                                DropdownMenuItem(value: 'kilometers', child: Text('km')),
                                DropdownMenuItem(value: 'miles', child: Text('mi')),
                                DropdownMenuItem(value: 'feet', child: Text('ft')),
                                DropdownMenuItem(value: 'yards', child: Text('yd')),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  _savePreferredUnit(newValue);
                                }
                              }),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning,
                            size: 10, // Aproximadamente adecuado para fontsize 8 de texto
                            color: Colors
                                .deepOrange, // naranja oscuro. Puedes ajustar si hay un color específico de la paleta.
                          ),
                          SizedBox(width: 4),
                          Text('It will be necessary to restart the app to apply the changes.',
                              style: TextStyle(fontSize: 10, color: Colors.grey))
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text('Alarm', style: KTextStyles.titlesStyle),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Sound', style: KTextStyles.settingsTextStyle),
                        PopupMenuButton<String>(
                          onSelected: (value) {},
                          itemBuilder: (context) => [
                            PopupMenuItem(value: '1', child: Text('Opción 1')),
                          ],
                        ),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Vibration', style: KTextStyles.settingsTextStyle),
                        IconButton(onPressed: () {}, icon: Icon(Icons.vibration))
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Output sound', style: KTextStyles.settingsTextStyle),
                        IconButton(onPressed: () {}, icon: Icon(Icons.headphones))
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
