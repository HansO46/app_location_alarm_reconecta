import 'dart:convert';
import 'dart:typed_data'; // Import necesario para Uint8List
import 'package:flutter/material.dart';
import 'package:app_location_alarm_reconecta/views/pages/category_selection_page.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditingAlarmPage extends StatefulWidget {
  final Alarm alarm; // Alarma a editar

  const EditingAlarmPage({super.key, required this.alarm});

  @override
  State<EditingAlarmPage> createState() => _EditingAlarmPageState();
}

class _EditingAlarmPageState extends State<EditingAlarmPage> {
  late TextEditingController _alarmNameController;
  late TextEditingController _radiusController;

  Set<String> _selectedRepeatOption = {'once'}; // Estado para Daily/Once/Custom
  Set<String> _selectedSoundOption = {'enter'}; // Estado para Enter/Exit/Staying
  Set<String> _selectedTimeOption = {'any'}; // Estado para From/From to/Any time
  String _selectedValue =
      'meters'; // Valor inicial debe coincidir con uno de los items del dropdown
  String _selectedFromTime = '0'; // Hora inicial para el dropdown "From"
  String _selectedToTime = '0'; // Hora final para el dropdown "To"
  bool _isRepeatable = false;
  double _radius = 100.0; // Radio en metros

  bool _isSelectedSunday = false;
  bool _isSelectedMonday = false;
  bool _isSelectedTuesday = false;
  bool _isSelectedWednesday = false;
  bool _isSelectedThursday = false;
  bool _isSelectedFriday = false;
  bool _isSelectedSaturday = false;

  bool _isActive = true;
  Uint8List? _decodedImage; // Cache para la imagen decodificada

  @override
  void initState() {
    super.initState();
    // Cargar datos de la alarma
    _alarmNameController = TextEditingController(text: widget.alarm.name);
    _isActive = widget.alarm.isActive;

    // Decodificar imagen una sola vez al inicio
    if (widget.alarm.previewImageBase64 != null && widget.alarm.previewImageBase64!.isNotEmpty) {
      try {
        _decodedImage = base64Decode(widget.alarm.previewImageBase64!);
      } catch (e) {
        print('Error decodificando imagen inicial: $e');
        _decodedImage = null;
      }
    }

    // El radio siempre se guarda en metros, así que lo cargamos directamente
    _radius = widget.alarm.radius;
    // Inicializar el controller inmediatamente con el valor en metros (por defecto)
    _radiusController = TextEditingController(text: widget.alarm.radius.toStringAsFixed(0));
    // Cargar unidad preferida y actualizar el radio en esa unidad
    _loadPreferredUnit();
  }

  // Cargar unidad preferida desde SharedPreferences
  Future<void> _loadPreferredUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUnit = prefs.getString(KConstants.preferredUnitKey);
      if (savedUnit != null && savedUnit != 'meters') {
        setState(() {
          _selectedValue = savedUnit;
          // Convertir el radio a la unidad preferida para mostrar
          double radiusInPreferredUnit = _convertFromMeters(_radius, savedUnit);
          _radiusController.text =
              radiusInPreferredUnit.toStringAsFixed(savedUnit == 'meters' ? 0 : 2);
        });
      } else {
        // Si no hay unidad guardada o es metros, ya está inicializado correctamente
        setState(() {
          _selectedValue = 'meters';
        });
      }
    } catch (e) {
      print('Error cargando unidad preferida: $e');
      // Fallback a metros si hay error (ya está inicializado)
      setState(() {
        _selectedValue = 'meters';
      });
    }
  }

  @override
  void dispose() {
    _alarmNameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  // Cargar alarmas desde SharedPreferences
  Future<List<Alarm>> _loadAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? alarmsJson = prefs.getStringList(KConstants.alarmsKey);

      if (alarmsJson == null || alarmsJson.isEmpty) {
        return [];
      }

      return alarmsJson.map((jsonString) {
        Map<String, dynamic> json = jsonDecode(jsonString);
        return Alarm.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error cargando alarmas: $e');
      return [];
    }
  }

  // Guardar cambios de la alarma
  Future<void> _saveChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Alarm> alarms = await _loadAlarms();

      // Buscar y actualizar la alarma
      int index = alarms.indexWhere((a) => a.id == widget.alarm.id);
      if (index != -1) {
        // Crear alarma actualizada
        final updatedAlarm = Alarm(
          id: widget.alarm.id,
          name: _alarmNameController.text.trim(),
          latitude: widget.alarm.latitude,
          longitude: widget.alarm.longitude,
          address: widget.alarm.address,
          radius: _radius,
          createdAt: widget.alarm.createdAt,
          previewImageBase64: widget.alarm.previewImageBase64,
          category: widget.alarm.category,
          isActive: _isActive, // Usar el estado actualizado
        );

        // Verificar si hubo cambios
        bool hasChanges = widget.alarm.name != updatedAlarm.name ||
            widget.alarm.radius != updatedAlarm.radius ||
            widget.alarm.category != updatedAlarm.category ||
            widget.alarm.isActive != updatedAlarm.isActive; // Incluir isActive en la comparación

        if (hasChanges) {
          alarms[index] = updatedAlarm;

          // Guardar lista actualizada
          List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();
          await prefs.setStringList(KConstants.alarmsKey, alarmsJson);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alarm updated successfully'),
              backgroundColor: KColors.mainColor,
            ),
          );
        }

        // Verificar si hay una ruta anterior, si no, navegar a alarms_page
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true); // Retornar true para indicar que se guardó
        } else {
          // No hay ruta anterior, navegar a alarms_page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AlarmsPage()),
          );
        }
      }
    } catch (e) {
      print('Error guardando cambios: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar los cambios: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  // Convertir de otra unidad a metros
  double _convertToMeters(double value, String unit) {
    switch (unit) {
      case 'meters':
        return value;
      case 'kilometers':
        return value * 1000.0;
      case 'miles':
        return value * 1609.34;
      case 'feet':
        return value * 0.3048;
      case 'yards':
        return value * 0.9144;
      default:
        return value;
    }
  }

  // Obtener el valor mínimo y máximo para el slider según la unidad
  double _getMinValue(String unit) {
    switch (unit) {
      case 'meters':
        return 10.0;
      case 'kilometers':
        return 0.01; // 10 metros = 0.01 km
      case 'miles':
        return 0.006; // ~10 metros
      case 'feet':
        return 33.0; // ~10 metros
      case 'yards':
        return 11.0; // ~10 metros
      default:
        return 10.0;
    }
  }

  double _getMaxValue(String unit) {
    switch (unit) {
      case 'meters':
        return 1000.0;
      case 'kilometers':
        return 1.0; // 1000 metros = 1 km
      case 'miles':
        return 0.62; // ~1000 metros
      case 'feet':
        return 3281.0; // ~1000 metros
      case 'yards':
        return 1094.0; // ~1000 metros
      default:
        return 1000.0;
    }
  }

  // Eliminar alarma
  Future<void> _deleteAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Alarm> alarms = await _loadAlarms();

      // Filtrar la alarma a eliminar
      alarms.removeWhere((a) => a.id == widget.alarm.id);

      // Guardar lista actualizada
      List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(KConstants.alarmsKey, alarmsJson);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarma eliminada'),
          backgroundColor: Colors.orange,
        ),
      );

      // Verificar si hay una ruta anterior, si no, navegar a alarms_page
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true); // Retornar true para indicar que se eliminó
      } else {
        // No hay ruta anterior, navegar a alarms_page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AlarmsPage()),
        );
      }
    } catch (e) {
      print('Error eliminando alarma: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la alarma: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Guardar cambios automáticamente al retroceder
          await _saveChanges();

          // Verificar si hay una ruta anterior, si no, navegar a alarms_page
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            // No hay ruta anterior, navegar a alarms_page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AlarmsPage()),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyActions: true,
          title: Row(
            children: [
              Expanded(
                child: Text(_alarmNameController.text),
              ),
              if (_getCategoryIcon(widget.alarm.category) != null)
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(_getCategoryIcon(widget.alarm.category), size: 20),
                ),
            ],
          ),
          actions: [
            Switch(
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            IconButton(
              onPressed: () async {
                // Mostrar diálogo de confirmación
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete alarm'),
                    content: Text('Are you sure you want to delete this alarm?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _deleteAlarm();
                }
              },
              icon: Icon(Icons.delete),
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'daily', label: Text('Daily')),
                      ButtonSegment(value: 'once', label: Text('Once')),
                      ButtonSegment(value: 'custom', label: Text('Custom')),
                    ],
                    selected: _selectedRepeatOption, // Usa el estado específico
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedRepeatOption = newSelection; // Actualiza el estado
                      });
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text('S'),
                          selected: _isSelectedSunday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedSunday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('M'),
                          selected: _isSelectedMonday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedMonday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('T'),
                          selected: _isSelectedTuesday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedTuesday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('W'),
                          selected: _isSelectedWednesday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedWednesday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('T'),
                          selected: _isSelectedThursday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedThursday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('F'),
                          selected: _isSelectedFriday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedFriday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text('S'),
                          selected: _isSelectedSaturday,
                          onSelected: (bool selected) {
                            setState(() {
                              _isSelectedSaturday = selected;
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          showCheckmark: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    padding: EdgeInsets.all(16),
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text("Destination address: ${widget.alarm.address}",
                              style: KTextStyles.alarmDetailsTextStyle, softWrap: true),
                        ),
                        IconButton(
                          onPressed: () async {
                            // Navegar a category_selection_page para editar ubicación
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategorySelectionPage(
                                  alarmToEdit: widget.alarm,
                                ),
                              ),
                            );
                            // Si se guardó la ubicación, recargar la alarma y volver a la página
                            if (result == true) {
                              // Recargar la alarma desde preferences
                              final prefs = await SharedPreferences.getInstance();
                              final List<String>? alarmsJson =
                                  prefs.getStringList(KConstants.alarmsKey);
                              if (alarmsJson != null) {
                                final alarms = alarmsJson.map((jsonString) {
                                  Map<String, dynamic> json = jsonDecode(jsonString);
                                  return Alarm.fromJson(json);
                                }).toList();
                                final updatedAlarm = alarms.firstWhere(
                                  (a) => a.id == widget.alarm.id,
                                  orElse: () => widget.alarm,
                                );
                                // Recargar la página con la alarma actualizada
                                // Usar pushReplacement directamente sin pop para mantener la pila
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditingAlarmPage(alarm: updatedAlarm),
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.edit),
                        ),
                      ],
                    )),
                // Mostrar imagen del mapa si está disponible
                if (widget.alarm.previewImageBase64 != null &&
                    widget.alarm.previewImageBase64!.isNotEmpty)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _decodedImage != null
                          ? Image.memory(
                              _decodedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
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
                            )
                          : Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey[600]),
                              ),
                            ),
                    ),
                  ),
                Text("Radius", style: KTextStyles.alarmDetailsTextStyle),
                Row(
                  children: [
                    // Slider ocupa 60% del espacio (flex: 6)
                    Expanded(
                      flex: 6,
                      child: Builder(
                        builder: (context) {
                          // Convertir el radio de metros a la unidad seleccionada para el slider
                          double radiusInSelectedUnit = _convertFromMeters(_radius, _selectedValue);
                          double minValue = _getMinValue(_selectedValue);
                          double maxValue = _getMaxValue(_selectedValue);

                          return Slider(
                            value: radiusInSelectedUnit.clamp(minValue, maxValue),
                            min: minValue,
                            max: maxValue,
                            divisions: 99,
                            onChanged: (value) {
                              setState(() {
                                // Convertir el valor seleccionado de vuelta a metros
                                _radius = _convertToMeters(value, _selectedValue);
                                // Actualizar el TextField con el valor en la unidad seleccionada
                                _radiusController.text =
                                    value.toStringAsFixed(_selectedValue == 'meters' ? 0 : 2);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 8), // Espacio entre elementos
                    // TextField ocupa 20% del espacio (flex: 2)
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _radiusController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) {
                            double minValue = _getMinValue(_selectedValue);
                            if (parsed >= minValue) {
                              setState(() {
                                // Convertir el valor ingresado a metros
                                _radius = _convertToMeters(parsed, _selectedValue);
                              });
                            }
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8), // Espacio entre elementos
                    // Dropdown ocupa 20% del espacio (flex: 2)
                    Expanded(
                      flex: 2,
                      child: DropdownButton<String>(
                        value: _selectedValue,
                        isExpanded: true, // Para que el dropdown use todo el ancho disponible
                        items: [
                          DropdownMenuItem(value: 'meters', child: Text('m')),
                          DropdownMenuItem(value: 'kilometers', child: Text('km')),
                          DropdownMenuItem(value: 'miles', child: Text('mi')),
                          DropdownMenuItem(value: 'feet', child: Text('ft')),
                          DropdownMenuItem(value: 'yards', child: Text('yd')),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedValue) {
                            setState(() {
                              // Convertir el valor actual de la unidad anterior a la nueva unidad
                              double radiusInNewUnit = _convertFromMeters(_radius, newValue);
                              _selectedValue = newValue;
                              // Actualizar el TextField con el valor en la nueva unidad
                              _radiusController.text =
                                  radiusInNewUnit.toStringAsFixed(newValue == 'meters' ? 0 : 2);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Text("Will sound when:"),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'enter', label: Text('Enter')),
                      ButtonSegment(value: 'exit', label: Text('Exit')),
                    ],
                    selected: _selectedSoundOption, // Usa el estado específico
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedSoundOption = newSelection; // Actualiza el estado
                      });
                    },
                  ),
                ),
                CheckboxListTile(
                  title: Text('Set alarm schedule hours'),
                  value: _isRepeatable, // Usa la variable de estado
                  onChanged: (value) {
                    setState(
                      () {
                        _isRepeatable = value ?? false; // Actualiza el estado
                        // O simplemente: _isRepeatable = !_isRepeatable;
                      },
                    );
                  },
                ),
                if (_isRepeatable)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'from', label: Text('From')),
                        ButtonSegment(value: 'from_to', label: Text('From to')),
                      ],
                      selected: _selectedTimeOption, // Usa el estado específico
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedTimeOption = newSelection; // Actualiza el estado
                          print(_selectedTimeOption);
                        });
                      },
                    ),
                  ),
                if (_isRepeatable && _selectedTimeOption.contains('from_to'))
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: 150,
                          child: DropdownButton<String>(
                            padding: EdgeInsets.all(16),
                            value: _selectedFromTime,
                            isExpanded: true, // Para que el dropdown use todo el ancho disponible
                            items: [
                              DropdownMenuItem(value: '0', child: Text('00:00')),
                              DropdownMenuItem(value: '1', child: Text('01:00')),
                              DropdownMenuItem(value: '2', child: Text('02:00')),
                              DropdownMenuItem(value: '3', child: Text('03:00')),
                              DropdownMenuItem(value: '4', child: Text('04:00')),
                              DropdownMenuItem(value: '5', child: Text('05:00')),
                              DropdownMenuItem(value: '6', child: Text('06:00')),
                              DropdownMenuItem(value: '7', child: Text('07:00')),
                              DropdownMenuItem(value: '8', child: Text('08:00')),
                              DropdownMenuItem(value: '9', child: Text('09:00')),
                              DropdownMenuItem(value: '10', child: Text('10:00')),
                              DropdownMenuItem(value: '11', child: Text('11:00')),
                              DropdownMenuItem(value: '12', child: Text('12:00')),
                              DropdownMenuItem(value: '13', child: Text('13:00')),
                              DropdownMenuItem(value: '14', child: Text('14:00')),
                              DropdownMenuItem(value: '15', child: Text('15:00')),
                              DropdownMenuItem(value: '16', child: Text('16:00')),
                              DropdownMenuItem(value: '17', child: Text('17:00')),
                              DropdownMenuItem(value: '18', child: Text('18:00')),
                              DropdownMenuItem(value: '19', child: Text('19:00')),
                              DropdownMenuItem(value: '20', child: Text('20:00')),
                              DropdownMenuItem(value: '21', child: Text('21:00')),
                              DropdownMenuItem(value: '22', child: Text('22:00')),
                              DropdownMenuItem(value: '23', child: Text('23:00')),
                              DropdownMenuItem(value: '24', child: Text('24:00')),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedFromTime = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        Text('to'),
                        SizedBox(
                          width: 150,
                          child: DropdownButton<String>(
                            value: _selectedToTime,
                            padding: EdgeInsets.all(16),
                            isExpanded: true, // Para que el dropdown use todo el ancho disponible
                            items: [
                              DropdownMenuItem(value: '0', child: Text('00:00')),
                              DropdownMenuItem(value: '1', child: Text('01:00')),
                              DropdownMenuItem(value: '2', child: Text('02:00')),
                              DropdownMenuItem(value: '3', child: Text('03:00')),
                              DropdownMenuItem(value: '4', child: Text('04:00')),
                              DropdownMenuItem(value: '5', child: Text('05:00')),
                              DropdownMenuItem(value: '6', child: Text('06:00')),
                              DropdownMenuItem(value: '7', child: Text('07:00')),
                              DropdownMenuItem(value: '8', child: Text('08:00')),
                              DropdownMenuItem(value: '9', child: Text('09:00')),
                              DropdownMenuItem(value: '10', child: Text('10:00')),
                              DropdownMenuItem(value: '11', child: Text('11:00')),
                              DropdownMenuItem(value: '12', child: Text('12:00')),
                              DropdownMenuItem(value: '13', child: Text('13:00')),
                              DropdownMenuItem(value: '14', child: Text('14:00')),
                              DropdownMenuItem(value: '15', child: Text('15:00')),
                              DropdownMenuItem(value: '16', child: Text('16:00')),
                              DropdownMenuItem(value: '17', child: Text('17:00')),
                              DropdownMenuItem(value: '18', child: Text('18:00')),
                              DropdownMenuItem(value: '19', child: Text('19:00')),
                              DropdownMenuItem(value: '20', child: Text('20:00')),
                              DropdownMenuItem(value: '21', child: Text('21:00')),
                              DropdownMenuItem(value: '22', child: Text('22:00')),
                              DropdownMenuItem(value: '23', child: Text('23:00')),
                              DropdownMenuItem(value: '24', child: Text('24:00')),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedToTime = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isRepeatable && _selectedTimeOption.contains('from'))
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: 150,
                          child: DropdownButton<String>(
                            padding: EdgeInsets.all(16),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: '0', child: Text('00:00')),
                              DropdownMenuItem(value: '1', child: Text('01:00')),
                              DropdownMenuItem(value: '2', child: Text('02:00')),
                              DropdownMenuItem(value: '3', child: Text('03:00')),
                              DropdownMenuItem(value: '4', child: Text('04:00')),
                              DropdownMenuItem(value: '5', child: Text('05:00')),
                              DropdownMenuItem(value: '6', child: Text('06:00')),
                              DropdownMenuItem(value: '7', child: Text('07:00')),
                              DropdownMenuItem(value: '8', child: Text('08:00')),
                              DropdownMenuItem(value: '9', child: Text('09:00')),
                              DropdownMenuItem(value: '10', child: Text('10:00')),
                              DropdownMenuItem(value: '11', child: Text('11:00')),
                              DropdownMenuItem(value: '12', child: Text('12:00')),
                              DropdownMenuItem(value: '13', child: Text('13:00')),
                              DropdownMenuItem(value: '14', child: Text('14:00')),
                              DropdownMenuItem(value: '15', child: Text('15:00')),
                              DropdownMenuItem(value: '16', child: Text('16:00')),
                              DropdownMenuItem(value: '17', child: Text('17:00')),
                              DropdownMenuItem(value: '18', child: Text('18:00')),
                              DropdownMenuItem(value: '19', child: Text('19:00')),
                              DropdownMenuItem(value: '20', child: Text('20:00')),
                              DropdownMenuItem(value: '21', child: Text('21:00')),
                              DropdownMenuItem(value: '22', child: Text('22:00')),
                              DropdownMenuItem(value: '23', child: Text('23:00')),
                              DropdownMenuItem(value: '24', child: Text('24:00')),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedFromTime = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: _saveChanges,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Save changes'),
                  ),
                ),
                SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
