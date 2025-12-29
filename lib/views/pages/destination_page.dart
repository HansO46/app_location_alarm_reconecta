import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DestinationPage extends StatefulWidget {
  final String? category; // Categoría seleccionada (home, work, train, other)
  final Alarm? alarmToEdit; // Alarma a editar (solo ubicación)

  const DestinationPage({super.key, this.category, this.alarmToEdit});

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class SearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  SearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class _DestinationPageState extends State<DestinationPage> {
  bool isDarkMode = isDarkModeNotifier.value;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _alarmNameController = TextEditingController();

  List<SearchResult> _searchResults = []; // Lista de resultados
  bool _showResults = false; // Controla si se muestran o no

  bool _loading = false; // Indica si hay una búsqueda en progreso

  final Completer<MapLibreMapController> _controllerCompleter = Completer<MapLibreMapController>();
  final GlobalKey _mapPreviewKey = GlobalKey(); // Key para tomar screenshot del mapa
  bool _styleLoaded = false;
  CameraPosition? _currentCameraPosition; // Guardar posición actual de la cámara
  geo.Position? position;
  Set<Symbol> _markers = {}; // Para almacenar los marcadores creados
  Fill? _geofenceFill; // Almacena únicamente el círculo actual para evitar parpadeos
  LatLng? _markerPosition; // Posición del marcador (centro del geofence)
  double _geofenceRadius = 100.0; // Radio del geofence en metros (valor inicial: 100m)
  Timer? _cameraIdleTimer; // Timer para debounce de onCameraIdle

  // Variables para controlar el redibujado secuencial del círculo
  bool _isDrawing = false;
  double? _pendingRadius;

  // Posición inicial del mapa (centro del mundo por defecto)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  bool locationSelected = false; //ya se selecciono la ubicacion
  bool isCustomRadius = false; //se esta usando el radio personalizado
  bool _isAlarmNameEmpty = true; // Controla si el nombre de la alarma está vacío
  String _selectedUnit = 'meters'; // Unidad para mostrar el radio

  @override
  void initState() {
    super.initState();
    // Cargar unidad preferida
    _loadPreferredUnit();
    // Si se está editando una alarma, cargar sus datos
    if (widget.alarmToEdit != null) {
      _alarmNameController.text = widget.alarmToEdit!.name;
      _geofenceRadius = widget.alarmToEdit!.radius;
      _markerPosition = LatLng(widget.alarmToEdit!.latitude, widget.alarmToEdit!.longitude);
      locationSelected = true;
      // Actualizar el estado del botón basado en el nombre cargado
      _isAlarmNameEmpty = _alarmNameController.text.trim().isEmpty;
    }
    // Listener para detectar cambios en el nombre de la alarma
    _alarmNameController.addListener(() {
      setState(() {
        _isAlarmNameEmpty = _alarmNameController.text.trim().isEmpty;
      });
    });
    // Obtener ubicación cuando el mapa esté listo
    if (widget.alarmToEdit == null) {
      _getLastKnownLocation();
      _getMyLocation();
    }
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

  // Obtener el valor mínimo y máximo para el slider según la unidad (máximo 5 km = 5000 m)
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
    // Máximo: 5 km = 5000 m en todas las unidades
    switch (unit) {
      case 'meters':
        return 5000.0; // 5 km
      case 'kilometers':
        return 5.0; // 5 km
      case 'miles':
        return 3.11; // ~5 km
      case 'feet':
        return 16404.0; // ~5 km
      case 'yards':
        return 5468.0; // ~5 km
      default:
        return 5000.0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _alarmNameController.dispose();
    _cameraIdleTimer?.cancel(); // Cancelar el timer si existe
    super.dispose();
  }

  void _hideResults() {
    setState(() {
      _showResults = false;
    });
  }

  void _selectResult(SearchResult result) {
    _hideResults(); // Ocultar primero
    _moveToLocation(result.latitude, result.longitude, zoom: 16);
  }

  Future<void> _searchAddress() async {
    // VALIDACIÓN: Verificar que el usuario haya escrito algo
    if (_searchController.text.isEmpty) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      return;
    }

    // PREPARACIÓN: Limpiar resultados anteriores y activar loading
    setState(() {
      _loading = true;
      _searchResults = []; // ← Limpiar lista antes de buscar
      _showResults = false; // ← Ocultar resultados anteriores
    });

    try {
      // Búsqueda con Geoapify
      await _searchWithGeoapify(_searchController.text);
    } catch (e) {
      setState(() {
        _loading = false;
        _showResults = false;
      });
    } finally {
      if (_loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Reverse geocoding: obtener dirección a partir de coordenadas usando Geoapify
  Future<String> _reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.geoapify.com/v1/geocode/reverse?lat=$latitude&lon=$longitude&apiKey=${KConstants.geoapifyApiKey}&lang=es',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final feature = data['features'][0];
          final properties = feature['properties'];

          // Construir dirección legible
          String address = '';

          // Intentar obtener la dirección formateada
          if (properties['formatted'] != null) {
            address = properties['formatted'];
          } else {
            // Construir dirección manualmente si no hay formato
            List<String> addressParts = [];

            if (properties['street'] != null) {
              addressParts.add(properties['street']);
            }
            if (properties['housenumber'] != null) {
              addressParts.add(properties['housenumber']);
            }
            if (properties['city'] != null) {
              addressParts.add(properties['city']);
            }
            if (properties['state'] != null) {
              addressParts.add(properties['state']);
            }
            if (properties['country'] != null) {
              addressParts.add(properties['country']);
            }

            address = addressParts.isNotEmpty
                ? addressParts.join(', ')
                : '$latitude, $longitude'; // Fallback a coordenadas
          }

          print('Dirección obtenida: $address');
          return address;
        } else {
          print('No se encontró dirección para las coordenadas');
          return '$latitude, $longitude'; // Fallback a coordenadas
        }
      } else {
        print('Error en reverse geocoding: ${response.statusCode}');
        return '$latitude, $longitude'; // Fallback a coordenadas
      }
    } catch (e) {
      print('Error haciendo reverse geocoding: $e');
      return '$latitude, $longitude'; // Fallback a coordenadas
    }
  }

  Future<void> _searchWithGeoapify(String query) async {
    try {
      print('Buscando con Geoapify: $query');

      // Codificar el query para URL
      final encodedQuery = Uri.encodeComponent(query);

      // Construir la URL de Geoapify Geocoding API
      final url = Uri.parse(
          'https://api.geoapify.com/v1/geocode/search?text=$encodedQuery&apiKey=${KConstants.geoapifyApiKey}&limit=5&lang=es');

      // Enviar solicitud HTTP GET
      final response = await http.get(url);

      print('Respuesta Geoapify: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List? ?? [];

        if (features.isEmpty) {
          setState(
            () {
              _loading = false;
              _showResults = false;
            },
          );
          return;
        }

        // Limpiar resultados anteriores
        _searchResults.clear();

        for (var feature in features) {
          var properties = feature['properties'] as Map<String, dynamic>;
          var geometry = feature['geometry'] as Map<String, dynamic>;
          var coordinates = geometry['coordinates'] as List;
          var longitude = coordinates[0] as double; // ← Conversión explícita
          var latitude = coordinates[1] as double; // ← Conversión explícita
          var name = properties['name'] ?? properties['formatted'] ?? 'Sin nombre';
          var addressLine1 = properties['address_line1'] ?? '';
          var addressLine2 = properties['address_line2'] ?? '';
          var city = properties['city'] ?? properties['town'] ?? '';
          var state = properties['state'] ?? '';
          var country = properties['country'] ?? '';

          // Construir dirección completa
          String fullAddress = '';
          if (addressLine1.isNotEmpty) fullAddress = addressLine1;
          if (addressLine2.isNotEmpty) fullAddress += ', $addressLine2';
          if (city.isNotEmpty) fullAddress += ', $city';
          if (state.isNotEmpty) fullAddress += ', $state';
          if (country.isNotEmpty) fullAddress += ', $country';
          if (fullAddress.isEmpty) fullAddress = name;

          _searchResults.add(SearchResult(
              name: name, address: fullAddress, latitude: latitude, longitude: longitude));
        }

        // ← ACTIVAR para mostrar resultados
        setState(() {
          _showResults = true;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _showResults = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _showResults = false;
      });
      print('Error Geoapify: $e');
    }
  }

  Future<void> _getLastKnownLocation() async {
    try {
      position = await geo.Geolocator.getLastKnownPosition();
      if (position != null) {
        print('Última ubicación conocida: ${position?.latitude}, ${position?.longitude}');
        _moveToLocation(position!.latitude, position!.longitude, zoom: 12);
      }
    } catch (e) {
      print('Error obteniendo última ubicación: $e');
    }
  }

  Future<void> _getMyLocation() async {
    try {
      position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      print('Mi ubicación actual: ${position?.latitude}, ${position?.longitude}');
      _moveToLocation(position!.latitude, position!.longitude, zoom: 14);
    } catch (e) {
      print('Error obteniendo ubicación actual: $e');
    }
  }

  Future<void> _moveToLocation(double latitude, double longitude, {double? zoom}) async {
    if (!_styleLoaded) return;

    try {
      final controller = await _controllerCompleter.future;
      CameraPosition newPosition;

      if (zoom != null) {
        // Mover y cambiar zoom
        newPosition = CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: zoom,
        );
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(newPosition),
        );
      } else {
        // Solo mover sin cambiar zoom (mantiene el zoom actual)
        double currentZoom = _currentCameraPosition?.zoom ?? 14.0;
        newPosition = CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: currentZoom,
        );
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(newPosition),
        );
      }

      // Guardar la nueva posición
      _currentCameraPosition = newPosition;
    } catch (e) {
      print('Error moviendo cámara: $e');
    }
  }

  // Construye la URL del estilo de Geoapify con la API key
  String _getGeoapifyStyleUrl({bool? forceDarkMode}) {
    // Opción 1: Usar estilo predefinido de Geoapify (más fácil)
    // Estilos disponibles: osm-bright, klokantech-basic, positron, dark-matter, etc.
    bool useDarkMode = forceDarkMode ?? isDarkMode;
    if (useDarkMode) {
      return 'https://maps.geoapify.com/v1/styles/dark-matter-yellow-roads/style.json?apiKey=${KConstants.geoapifyApiKey}';
    } else {
      return 'https://maps.geoapify.com/v1/styles/osm-bright/style.json?apiKey=${KConstants.geoapifyApiKey}';
    }

    // Opción 2: Si prefieres otro estilo, cambia 'osm-bright' por:
    // - 'klokantech-basic'
    // - 'positron'
    // - 'dark-matter'
    // - 'toner'
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (_showResults && !didPop) {
          _hideResults(); // Ocultar en lugar de salir
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset:
            false, // Evitar que el mapa se redimensione cuando aparece el teclado
        body: PopScope(
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: RepaintBoundary(
                      key: _mapPreviewKey,
                      child: MapLibreMap(
                        onMapClick: (point, coordinates) {
                          if (!isCustomRadius) {
                            _createMarker(point, coordinates);
                          }
                        },
                        onCameraIdle: () {
                          // Debounce: esperar 300ms antes de actualizar el círculo
                          // Esto evita ejecutar cálculos pesados en cada movimiento de cámara
                          if (_markerPosition != null && _styleLoaded && isCustomRadius) {
                            _cameraIdleTimer?.cancel(); // Cancelar timer anterior si existe
                            _cameraIdleTimer = Timer(Duration(milliseconds: 300), () {
                              drawGeocodingCircle(); // Ejecutar después del delay
                            });
                          }
                        },
                        initialCameraPosition: position != null
                            ? CameraPosition(
                                target: LatLng(position!.latitude, position!.longitude),
                                zoom: 12,
                              )
                            : _initialCameraPosition,
                        onMapCreated: (controller) {
                          _controllerCompleter.complete(controller);
                        },
                        onStyleLoadedCallback: () async {
                          setState(() {
                            _styleLoaded = true;
                          });
                          // Cargar la imagen personalizada del marcador
                          await _loadCustomMarkerImage();
                          // Si se está editando una alarma, cargar su ubicación
                          if (widget.alarmToEdit != null && _markerPosition != null) {
                            await _moveToLocation(
                                _markerPosition!.latitude, _markerPosition!.longitude,
                                zoom: 16);
                            // Crear marcador en la ubicación de la alarma
                            final controller = await _controllerCompleter.future;
                            await _removeMarker();
                            final symbol = await controller.addSymbol(
                              SymbolOptions(
                                geometry: _markerPosition!,
                                iconImage: 'custom_marker',
                                iconSize: 0.09,
                              ),
                            );
                            _markers.add(symbol);
                            await drawGeocodingCircle();
                          } else if (position != null) {
                            // Una vez cargado el estilo, mover a la ubicación si está disponible
                            _moveToLocation(position!.latitude, position!.longitude, zoom: 14);
                          }
                        },
                        myLocationEnabled: true,
                        styleString: _getGeoapifyStyleUrl(), // Estilo de Geoapify con API key
                      ),
                    ),
                  ),

                  if (!locationSelected && !isCustomRadius)
                    Positioned(
                      top: MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context)
                              .padding
                              .top // Cuando aparece el teclado, mantener en la parte superior con padding del SafeArea
                          : 0, // Sin teclado, posición normal
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(0, 4),
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                label: Text('Search destination'),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchResults = [];
                                            _showResults = false;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onSubmitted: (_) => _searchAddress(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showResults && _searchResults.isNotEmpty)
                    Positioned(
                      top: 80,
                      left: 20,
                      right: 20, // ← Agregar right para limitar ancho
                      height: 300,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(0, 4),
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header con botón de cerrar
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Resultados (${_searchResults.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close),
                                    onPressed: _hideResults,
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ),
                            // Lista de resultados reales con scroll
                            Flexible(
                              child: SingleChildScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                child: Column(
                                  children: _searchResults.map((result) {
                                    return ListTile(
                                      leading: SizedBox(
                                        width: double
                                            .minPositive, // Controla el ancho del espacio del leading
                                        child: Icon(
                                          Icons.location_on,
                                          color: KColors.mainColor,
                                        ),
                                      ),
                                      title: Text(
                                        result.name,
                                      ),
                                      subtitle: Text(
                                        result.address,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _selectResult(result),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (locationSelected)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 12),
                          FilledButton(
                            onPressed: () async {
                              // Dibujar el círculo del geofence
                              await drawGeocodingCircle();
                              locationSelected = false;
                              isCustomRadius = true;
                              setState(() {});
                            },
                            child: Text('Choose location'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Slider para controlar el radio del geofence
                  if (isCustomRadius || locationSelected)
                    Positioned(
                      top: MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context)
                              .padding
                              .top // Cuando aparece el teclado, mantener en la parte superior con padding del SafeArea
                          : 0, // Sin teclado, posición normal
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Evita que se expanda infinitamente
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Para que TextField ocupe todo el ancho
                        children: [
                          IconButton(
                            onPressed: () async {
                              isCustomRadius = false;
                              locationSelected = false;
                              await _removeMarker();
                              await _removeGeofence();
                              setState(() {});
                            },
                            icon: Icon(Icons.arrow_back),
                          ),
                          if (isCustomRadius || !locationSelected)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: _alarmNameController,
                                decoration: InputDecoration(
                                  label: Text('Alarm name'),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (isCustomRadius)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width - 40,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode ? Colors.black : Colors.white,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Circle radius',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Dropdown para seleccionar unidad
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
                                        if (newValue != null && newValue != _selectedUnit) {
                                          setState(() {
                                            _selectedUnit = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    // Convertir el radio de metros a la unidad seleccionada para el slider
                                    double radiusInSelectedUnit =
                                        _convertFromMeters(_geofenceRadius, _selectedUnit);
                                    double minValue = _getMinValue(_selectedUnit);
                                    double maxValue = _getMaxValue(_selectedUnit);
                                    String unitSymbol = _getUnitSymbol(_selectedUnit);

                                    return Slider(
                                      value: radiusInSelectedUnit.clamp(minValue, maxValue),
                                      min: minValue,
                                      max: maxValue,
                                      divisions: 99,
                                      label:
                                          '${radiusInSelectedUnit.toStringAsFixed(_selectedUnit == 'meters' ? 0 : 2)} $unitSymbol',
                                      activeColor: KColors.mainColor,
                                      onChanged: (double value) {
                                        // Convertir el valor seleccionado de vuelta a metros
                                        _updateGeofenceRadius(
                                            _convertToMeters(value, _selectedUnit));
                                      },
                                    );
                                  },
                                ),
                                SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    // Crear un controller para el TextField con el valor en la unidad seleccionada
                                    double radiusInSelectedUnit =
                                        _convertFromMeters(_geofenceRadius, _selectedUnit);
                                    final TextEditingController radiusController =
                                        TextEditingController(
                                            text: radiusInSelectedUnit.toStringAsFixed(
                                                _selectedUnit == 'meters' ? 0 : 2));

                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        return StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            return AlertDialog(
                                              title: Text('Custom radius'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Dropdown para seleccionar unidad en el diálogo
                                                  DropdownButton<String>(
                                                    value: _selectedUnit,
                                                    isExpanded: true,
                                                    items: [
                                                      DropdownMenuItem(
                                                          value: 'meters',
                                                          child: Text('Meters (m)')),
                                                      DropdownMenuItem(
                                                          value: 'kilometers',
                                                          child: Text('Kilometers (km)')),
                                                      DropdownMenuItem(
                                                          value: 'miles',
                                                          child: Text('Miles (mi)')),
                                                      DropdownMenuItem(
                                                          value: 'feet', child: Text('Feet (ft)')),
                                                      DropdownMenuItem(
                                                          value: 'yards',
                                                          child: Text('Yards (yd)')),
                                                    ],
                                                    onChanged: (String? newValue) {
                                                      if (newValue != null) {
                                                        setDialogState(() {
                                                          // Convertir el valor actual a la nueva unidad
                                                          double currentValue = double.tryParse(
                                                                  radiusController.text) ??
                                                              _geofenceRadius;
                                                          double currentInMeters =
                                                              _selectedUnit == 'meters'
                                                                  ? currentValue
                                                                  : _convertToMeters(
                                                                      currentValue, _selectedUnit);
                                                          _selectedUnit = newValue;
                                                          double newValueInUnit =
                                                              _convertFromMeters(
                                                                  currentInMeters, newValue);
                                                          radiusController.text =
                                                              newValueInUnit.toStringAsFixed(
                                                                  newValue == 'meters' ? 0 : 2);
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  SizedBox(height: 16),
                                                  TextField(
                                                    controller: radiusController,
                                                    keyboardType: TextInputType.numberWithOptions(
                                                        decimal: true),
                                                    decoration: InputDecoration(
                                                      label: Text(
                                                          'Radius in ${_getUnitSymbol(_selectedUnit)}'),
                                                      border: OutlineInputBorder(),
                                                      hintText:
                                                          'Maximum: ${_getMaxValue(_selectedUnit).toStringAsFixed(_selectedUnit == 'meters' ? 0 : 2)} ${_getUnitSymbol(_selectedUnit)} (5 km)',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                        dialogContext); // Cerrar sin guardar
                                                    // Disposer el controller después de que el diálogo se cierre completamente
                                                    Future.delayed(Duration(milliseconds: 200), () {
                                                      try {
                                                        radiusController.dispose();
                                                      } catch (e) {
                                                        // Ignorar si ya fue dispuesto
                                                      }
                                                    });
                                                  },
                                                  child: Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    // Leer el valor del TextField ANTES de cerrar el diálogo
                                                    final textValue = radiusController.text.trim();
                                                    final radius = double.tryParse(textValue);

                                                    // Validar que sea un número válido según la unidad seleccionada
                                                    if (radius != null) {
                                                      double minValue = _getMinValue(_selectedUnit);
                                                      double maxValue = _getMaxValue(_selectedUnit);

                                                      if (radius >= minValue &&
                                                          radius <= maxValue) {
                                                        // Convertir a metros antes de guardar
                                                        double radiusInMeters =
                                                            _convertToMeters(radius, _selectedUnit);
                                                        // Guardar el valor antes de cerrar
                                                        Navigator.pop(
                                                            dialogContext); // Cerrar el diálogo
                                                        // Disposer el controller después de que el diálogo se cierre completamente
                                                        Future.delayed(Duration(milliseconds: 200),
                                                            () {
                                                          try {
                                                            radiusController.dispose();
                                                          } catch (e) {
                                                            // Ignorar si ya fue dispuesto
                                                          }
                                                        });
                                                        // Actualizar el radio después de cerrar el diálogo
                                                        Future.microtask(() {
                                                          _updateGeofenceRadius(radiusInMeters);
                                                        });
                                                      } else {
                                                        // Mostrar error si el valor no es válido
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                                'Please enter a value between ${minValue.toStringAsFixed(_selectedUnit == 'meters' ? 0 : 2)} and ${maxValue.toStringAsFixed(_selectedUnit == 'meters' ? 0 : 2)} ${_getUnitSymbol(_selectedUnit)}'),
                                                            duration: Duration(seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      // Mostrar error si no es un número válido
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content:
                                                              Text('Please enter a valid number'),
                                                          duration: Duration(seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: Text('Save'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size(0, 24), // Altura mínima pequeña
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap, // Reduce el área táctil
                                  ),
                                  child: Text(
                                    'Custom',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 12),
                              FilledButton(
                                onPressed: _isAlarmNameEmpty
                                    ? null
                                    : () async {
                                        // Validar que haya nombre y ubicación
                                        if (_alarmNameController.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Por favor ingresa un nombre para la alarma'),
                                            ),
                                          );
                                          return;
                                        }

                                        if (_markerPosition == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Por favor selecciona una ubicación en el mapa'),
                                            ),
                                          );
                                          return;
                                        }

                                        // Mostrar pantalla de carga
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => PopScope(
                                            canPop: false, // Prevenir cierre con botón de retroceso
                                            child: Dialog(
                                              backgroundColor: Colors.transparent,
                                              child: Container(
                                                padding: EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).scaffoldBackgroundColor,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(),
                                                    SizedBox(height: 16),
                                                    Text(
                                                      'Saving alarm...',
                                                      style: TextStyle(fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );

                                        // Guardar la alarma (esto tomará screenshots de ambos temas)
                                        bool hasChanges = await _saveAlarm();

                                        // Cerrar diálogo de carga
                                        Navigator.pop(context);

                                        // Solo mostrar mensaje de éxito si hubo cambios
                                        if (hasChanges) {
                                          // Mostrar animación Lottie de éxito
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => PopScope(
                                              canPop:
                                                  false, // Prevenir cierre con botón de retroceso
                                              child: Dialog(
                                                backgroundColor: Colors.transparent,
                                                child: Container(
                                                  padding: EdgeInsets.all(20),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Theme.of(context).scaffoldBackgroundColor,
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Lottie.asset(
                                                        'assets/lotties/checked.json',
                                                        width: 200,
                                                        height: 200,
                                                        fit: BoxFit.contain,
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        'Alarm saved successfully',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );

                                          // Esperar a que termine la animación (2.5 segundos)
                                          await Future.delayed(Duration(milliseconds: 2500));

                                          // Cerrar diálogo de éxito
                                          Navigator.pop(context);
                                        }

                                        // Si se está editando una alarma, retornar true si hubo cambios
                                        if (widget.alarmToEdit != null) {
                                          Navigator.pop(context, hasChanges);
                                        } else {
                                          // Limpiar y resetear
                                          _alarmNameController.clear();
                                          await _removeMarker();
                                          await _removeGeofence();
                                          locationSelected = false;
                                          isCustomRadius = false;

                                          // Navegar a la página de alarmas
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (context) => AlarmsPage()),
                                          );
                                        }
                                      },
                                child: Text('Set alarm'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  // Cargar la imagen personalizada del marcador en el estilo del mapa
  Future<void> _loadCustomMarkerImage() async {
    try {
      final controller = await _controllerCompleter.future;

      // Cargar la imagen desde assets
      final ByteData data = await rootBundle.load('assets/images/location.png');
      final Uint8List bytes = data.buffer.asUint8List();

      // Agregar la imagen al estilo del mapa con un nombre
      await controller.addImage('custom_marker', bytes);

      print('Imagen del marcador cargada correctamente');
    } catch (e) {
      print('Error cargando imagen del marcador: $e');
    }
  }

  Future<void> _removeMarker() async {
    final controller = await _controllerCompleter.future;
    for (var marker in _markers) {
      await controller.removeSymbol(marker);
    }
    _markers.clear();
  }

  Future<void> _createMarker(Point<double> point, LatLng coordinates) async {
    if (!_styleLoaded) return;

    try {
      final controller = await _controllerCompleter.future;

      await _removeMarker();
      // Limpiar la lista de marcadores
      _markers.clear();

      // Agregar el nuevo marcador usando addSymbol
      // MapLibre devuelve el Symbol creado
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: coordinates, // LatLng donde se colocará el marcador
          iconImage: 'custom_marker', // Nombre de la imagen cargada (NO la ruta del asset)
          iconSize: 0.09, // Tamaño del icono (ajusta según necesites)
          // iconColor no funciona con imágenes personalizadas, solo con iconos predefinidos
        ),
      );

      _markers.add(symbol);

      // Guardar la posición del marcador para el geofence
      setState(() {
        _markerPosition = coordinates;
        locationSelected = true;
      });
      if (!isCustomRadius) {
        await _moveToLocation(coordinates.latitude, coordinates.longitude);
        // Guardar posición de cámara después de mover
        _currentCameraPosition = CameraPosition(
          target: coordinates,
          zoom: 14.0,
        );
      } else {
        // Si ya está en modo custom radius, guardar posición basada en el marcador
        _currentCameraPosition = CameraPosition(
          target: coordinates,
          zoom: _currentCameraPosition?.zoom ?? 14.0,
        );
      }
      print('Marcador creado en: ${coordinates.latitude}, ${coordinates.longitude}');
    } catch (e) {
      print('Error creando marcador: $e');
    }
  }

  // Genera puntos de un círculo usando la fórmula de Haversine
  List<LatLng> _generateCirclePoints(LatLng center, double radiusInMeters, int numPoints) {
    List<LatLng> points = [];
    const double earthRadius = 6371000; // Radio de la Tierra en metros

    // Limitar el radio a un valor máximo razonable para evitar problemas
    double safeRadius = radiusInMeters.clamp(10.0, 5000.0); // Máximo 5 km

    // Reducir el número de puntos para radios grandes para evitar sobrecarga
    int actualNumPoints = numPoints;
    if (safeRadius > 2000) {
      actualNumPoints = 32; // Menos puntos para radios grandes
    } else if (safeRadius > 1000) {
      actualNumPoints = 48; // Puntos intermedios
    }

    try {
      // Calcular el ángulo en radianes (distancia angular) una sola vez
      double angularDistance = safeRadius / earthRadius;

      // Validar que el ángulo angular esté en un rango válido
      if (angularDistance > pi || angularDistance < 0 || !angularDistance.isFinite) {
        print('Radio inválido: ${safeRadius}m, angularDistance: $angularDistance');
        return [];
      }

      // Pre-calcular valores constantes
      double cosAngularDist = cos(angularDistance);
      double sinAngularDist = sin(angularDistance);

      // Validar que los valores sean finitos
      if (!cosAngularDist.isFinite || !sinAngularDist.isFinite) {
        print('Valores trigonométricos inválidos para radio: ${safeRadius}m');
        return [];
      }

      // Convertir latitud y longitud a radianes una sola vez
      double latRad = center.latitude * (pi / 180);
      double lonRad = center.longitude * (pi / 180);
      double cosLat = cos(latRad);
      double sinLat = sin(latRad);

      for (int i = 0; i < actualNumPoints; i++) {
        double angle = (2 * pi * i) / actualNumPoints;

        // Calcular nueva latitud con validación
        double cosAngle = cos(angle);
        double sinAngle = sin(angle);

        double asinArg = sinLat * cosAngularDist + cosLat * sinAngularDist * cosAngle;
        // Validar que el argumento de asin esté en [-1, 1]
        asinArg = asinArg.clamp(-1.0, 1.0);

        if (!asinArg.isFinite) {
          print('Argumento asin inválido en punto $i');
          continue; // Saltar este punto
        }

        double newLat = asin(asinArg);

        // Calcular nueva longitud
        double denominator = cosAngularDist - sinLat * sin(newLat);
        if (denominator.abs() < 1e-10) {
          // Evitar división por cero
          denominator = denominator >= 0 ? 1e-10 : -1e-10;
        }

        double newLon = lonRad + atan2(sinAngle * sinAngularDist * cosLat, denominator);

        // Convertir de vuelta a grados
        double latDeg = newLat * (180 / pi);
        double lonDeg = newLon * (180 / pi);

        // Validar y normalizar coordenadas
        latDeg = latDeg.clamp(-90.0, 90.0);
        // Normalizar longitud a [-180, 180]
        while (lonDeg > 180) lonDeg -= 360;
        while (lonDeg < -180) lonDeg += 360;

        // Validar que las coordenadas sean finitas antes de agregar
        if (latDeg.isFinite && lonDeg.isFinite) {
          points.add(LatLng(latDeg, lonDeg));
        } else {
          print('Coordenadas no finitas en punto $i: lat=$latDeg, lon=$lonDeg');
        }
      }

      // Validar que tengamos suficientes puntos
      if (points.length < 3) {
        print('No se generaron suficientes puntos: ${points.length}');
        return [];
      }

      // Cerrar el polígono (volver al primer punto)
      if (points.isNotEmpty) {
        points.add(points[0]);
      }
    } catch (e, stackTrace) {
      print('Error generando puntos del círculo: $e');
      print('Stack trace: $stackTrace');
      return [];
    }

    return points;
  }

  Future<void> _removeGeofence() async {
    final controller = await _controllerCompleter.future;
    if (_geofenceFill != null) {
      await controller.removeFill(_geofenceFill!);
      _geofenceFill = null;
    }
  }

  Future<void> drawGeocodingCircle() async {
    // print('Dibujando círculo: $_markerPosition'); // Comentado para evitar spam en consola
    if (!_styleLoaded || _markerPosition == null) {
      print('Mapa no listo o marcador no disponible');
      return;
    }

    try {
      // Validar que el radio esté en un rango seguro antes de intentar dibujar
      if (_geofenceRadius < 10 || _geofenceRadius > 5000) {
        print('Radio fuera de rango: ${_geofenceRadius}m');
        return;
      }

      final controller = await _controllerCompleter.future;
      // YA NO eliminar el geofence anterior aquí para evitar parpadeos
      // await _removeGeofence();

      // Generar puntos del círculo (el número de puntos se ajusta según el radio)
      List<LatLng> circlePoints = _generateCirclePoints(_markerPosition!, _geofenceRadius, 64);

      // Validar que se generaron puntos válidos
      if (circlePoints.isEmpty || circlePoints.length < 3) {
        print('No se pudieron generar puntos válidos del círculo');
        return;
      }

      // Validar que todos los puntos sean válidos
      bool allPointsValid = circlePoints.every((point) =>
          point.latitude >= -90 &&
          point.latitude <= 90 &&
          point.longitude >= -180 &&
          point.longitude <= 180);

      if (!allPointsValid) {
        print('Algunos puntos del círculo son inválidos');
        return;
      }

      // Crear el polígono circular
      String colorHex = '#${KColors.mainColor.value.toRadixString(16).substring(2)}';

      final fillOptions = FillOptions(
        geometry: [circlePoints], // Lista de anillos (el primero es el exterior)
        fillColor: colorHex,
        fillOpacity: 0.3,
        fillOutlineColor: colorHex,
      );

      if (_geofenceFill != null) {
        // ACTUALIZAR el existente para una animación suave
        await controller.updateFill(_geofenceFill!, fillOptions);
      } else {
        // CREAR uno nuevo si no existe
        _geofenceFill = await controller.addFill(fillOptions);
      }

      // print('Círculo actualizado - Radio: ${_geofenceRadius}m');
    } catch (e, stackTrace) {
      print('Error dibujando círculo: $e');
      print('Stack trace: $stackTrace');
      // No mostrar error al usuario aquí, ya que _updateGeofenceRadius maneja los errores
    }
  }

  // Método para gestionar la cola de redibujado
  Future<void> _processDrawingQueue() async {
    if (_isDrawing) return;
    _isDrawing = true;

    while (_pendingRadius != null) {
      // Tomar el último radio pendiente y limpiar la variable
      // Esto asegura que si llegan 50 notificaciones, solo dibujamos la última que llegó mientras dibujábamos
      final radiusToDraw = _pendingRadius;
      _pendingRadius = null;

      try {
        // Asegurarnos de que el estado refleje el radio que vamos a dibujar
        if (mounted && radiusToDraw != null) {
          // Ya se actualizó el estado en _updateGeofenceRadius, pero por seguridad
        }

        await drawGeocodingCircle();
      } catch (e) {
        print('Error en cola de dibujo: $e');
      }
    }

    _isDrawing = false;
  }

  // Método para actualizar el radio cuando cambia el slider
  void _updateGeofenceRadius(double newRadius) {
    // Validar y limitar el radio a un valor máximo razonable
    double safeRadius = newRadius.clamp(10.0, 5000.0); // Máximo 5 km

    if (safeRadius != newRadius) {
      // Mostrar advertencia si se limitó el valor (con throttle para no spamear)
      // Aquí podríamos omitir el snackbar durante el drag para no molestar
    }

    // Actualizar la UI inmediatamente
    setState(() {
      _geofenceRadius = safeRadius;
    });

    // Encolar el trabajo de dibujo
    _pendingRadius = safeRadius;
    _processDrawingQueue();
  }

  // Tomar screenshot del mapa
  Future<String?> _takeMapScreenshot() async {
    try {
      // Esperar un momento para que el mapa termine de renderizar
      await Future.delayed(Duration(milliseconds: 500));

      final RenderRepaintBoundary? boundary =
          _mapPreviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        print('No se pudo obtener el RenderRepaintBoundary');
        return null;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        print('No se pudo convertir la imagen a bytes');
        return null;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final String base64Image = base64Encode(pngBytes);

      print('Screenshot tomado: ${pngBytes.length} bytes');
      return base64Image;
    } catch (e) {
      print('Error tomando screenshot: $e');
      return null;
    }
  }

  // Guardar alarma en SharedPreferences
  // Retorna true si hubo cambios, false si no hubo cambios
  Future<bool> _saveAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener dirección mediante reverse geocoding
      String address = await _reverseGeocode(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
      );

      // Tomar screenshot del mapa antes de guardar
      String? previewImage = await _takeMapScreenshot();

      // Cargar alarmas existentes
      List<Alarm> alarms = await _loadAlarms();

      if (widget.alarmToEdit != null) {
        // Editar alarma existente: actualizar ubicación, categoría y nombre
        int index = alarms.indexWhere((a) => a.id == widget.alarmToEdit!.id);
        if (index != -1) {
          final updatedAlarm = Alarm(
            id: widget.alarmToEdit!.id,
            name: _alarmNameController.text.trim(), // Usar el nombre del TextField
            latitude: _markerPosition!.latitude,
            longitude: _markerPosition!.longitude,
            address: address,
            radius: _geofenceRadius,
            createdAt: widget.alarmToEdit!.createdAt,
            previewImageBase64: previewImage ?? widget.alarmToEdit!.previewImageBase64,
            category: widget.category ?? widget.alarmToEdit!.category,
            isActive: widget.alarmToEdit!.isActive, // Mantener el estado activo/inactivo original
          );

          // Verificar si hubo cambios (incluyendo el nombre)
          bool hasChanges = widget.alarmToEdit!.name != updatedAlarm.name ||
              widget.alarmToEdit!.latitude != updatedAlarm.latitude ||
              widget.alarmToEdit!.longitude != updatedAlarm.longitude ||
              widget.alarmToEdit!.radius != updatedAlarm.radius ||
              widget.alarmToEdit!.category != updatedAlarm.category ||
              widget.alarmToEdit!.isActive != updatedAlarm.isActive;

          if (hasChanges) {
            alarms[index] = updatedAlarm;
          } else {
            // No hubo cambios, no guardar
            return false;
          }
        }
      } else {
        // Crear nueva alarma
        final alarm = Alarm(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // ID único basado en timestamp
          name: _alarmNameController.text.trim(),
          latitude: _markerPosition!.latitude,
          longitude: _markerPosition!.longitude,
          address: address,
          radius: _geofenceRadius,
          createdAt: DateTime.now(),
          previewImageBase64: previewImage,
          category: widget.category,
          isActive: true, // ¡IMPORTANTE! Las nuevas alarmas nacen activas
        );

        alarms.add(alarm);
      }

      // Convertir lista de alarmas a JSON
      List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();

      // Guardar en SharedPreferences
      await prefs.setStringList(KConstants.alarmsKey, alarmsJson);

      // Cargar desde SharedPreferences para verificar que se guardó correctamente
      List<Alarm> savedAlarms = await _loadAlarms();

      // Imprimir la alarma recién guardada (la última) en formato JSON
      if (savedAlarms.isNotEmpty) {
        Alarm savedAlarm = savedAlarms.last;
        print('Alarma guardada en SharedPreferences:');
        print(jsonEncode(savedAlarm.toJson()));
      }
      return true; // Hubo cambios y se guardó
    } catch (e) {
      print('Error guardando alarma: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la alarma: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Cargar alarmas desde SharedPreferences
  Future<List<Alarm>> _loadAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? alarmsJson = prefs.getStringList(KConstants.alarmsKey);

      if (alarmsJson == null || alarmsJson.isEmpty) {
        return [];
      }

      // Convertir JSON a lista de Alarmas
      List<Alarm> alarms = alarmsJson.map((jsonString) {
        Map<String, dynamic> json = jsonDecode(jsonString);
        return Alarm.fromJson(json);
      }).toList();

      return alarms;
    } catch (e) {
      print('Error cargando alarmas: $e');
      return [];
    }
  }
}
