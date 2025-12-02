import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:app_location_alarm_reconecta/views/pages/alarms_page.dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DestinationPage extends StatefulWidget {
  const DestinationPage({super.key});

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

// Modelo para guardar alarmas
class Alarm {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address; // Dirección obtenida mediante reverse geocoding
  final double radius; // Radio del geofence en metros
  final DateTime createdAt;
  final String? previewImageBase64; // Imagen previa del mapa en base64

  Alarm({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.radius,
    required this.createdAt,
    this.previewImageBase64,
  });

  // Convertir a JSON para guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'radius': radius,
      'createdAt': createdAt.toIso8601String(),
      'previewImageBase64': previewImageBase64,
    };
  }

  // Crear desde JSON
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      address: json['address'] as String? ??
          '${json['latitude']}, ${json['longitude']}', // Compatibilidad con versiones anteriores
      radius: json['radius'] as double,
      createdAt: DateTime.parse(json['createdAt'] as String),
      previewImageBase64: json['previewImageBase64'] as String?,
    );
  }
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
  Set<Fill> _geofenceFills =
      {}; // Para almacenar los polígonos del geofence (círculo como polígono)
  LatLng? _markerPosition; // Posición del marcador (centro del geofence)
  double _geofenceRadius = 100.0; // Radio del geofence en metros (valor inicial: 100m)
  Timer? _cameraIdleTimer; // Timer para debounce de onCameraIdle

  // Posición inicial del mapa (centro del mundo por defecto)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  bool locationSelected = false; //ya se selecciono la ubicacion
  bool isCustomRadius = false; //se esta usando el radio personalizado
  bool _isAlarmNameEmpty = true; // Controla si el nombre de la alarma está vacío

  @override
  void initState() {
    super.initState();
    // Listener para detectar cambios en el nombre de la alarma
    _alarmNameController.addListener(() {
      setState(() {
        _isAlarmNameEmpty = _alarmNameController.text.trim().isEmpty;
      });
    });
    // Obtener ubicación cuando el mapa esté listo
    _getLastKnownLocation();
    _getMyLocation();
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
                          // Una vez cargado el estilo, mover a la ubicación si está disponible
                          if (position != null) {
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
                                    Text(
                                      '${_geofenceRadius.toInt()} m',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: KColors.mainColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Slider(
                                  value: _geofenceRadius.clamp(
                                      10.0, 1000.0), // Limitar visualmente al rango del slider
                                  min: 10.0, // Mínimo: 10 metros
                                  max: 1000.0, // Máximo: 1 kilómetro (para el slider)
                                  divisions: 99, // 99 divisiones (cada 10 metros)
                                  label: _geofenceRadius > 1000
                                      ? '${_geofenceRadius.toInt()} m (Custom)'
                                      : '${_geofenceRadius.toInt()} m',
                                  activeColor: KColors.mainColor,
                                  onChanged: (double value) {
                                    _updateGeofenceRadius(value);
                                  },
                                ),
                                // Mostrar advertencia si el valor es mayor al máximo del slider
                                if (_geofenceRadius > 1000)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Valor personalizado: ${_geofenceRadius.toInt()} m',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: KColors.mainColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    // Crear un controller para el TextField
                                    final TextEditingController radiusController =
                                        TextEditingController(
                                            text: _geofenceRadius.toInt().toString());

                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text('Custom radius'),
                                          content: TextField(
                                            controller: radiusController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              label: Text('Radius in meters'),
                                              border: OutlineInputBorder(),
                                              hintText: 'Ej: 5000 (para valores > 1000m)',
                                              helperText:
                                                  'El slider permite hasta 1000m. Usa Custom para valores mayores.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context); // Cerrar ssin guardar
                                              },
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Leer el valor del TextField
                                                final textValue = radiusController.text.trim();
                                                final radius = double.tryParse(textValue);

                                                // Validar que sea un número válido (mínimo 10, sin máximo para Custom)
                                                if (radius != null && radius >= 10) {
                                                  _updateGeofenceRadius(radius);
                                                  Navigator.pop(context); // Cerrar el diálogo
                                                } else {
                                                  // Mostrar error si el valor no es válido
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Por favor ingresa un valor mayor o igual a 10 metros'),
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
                                    ).then((_) {
                                      // Limpiar el controller cuando se cierre el diálogo
                                      radiusController.dispose();
                                    });
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
                                                      'Guardando alarma...',
                                                      style: TextStyle(fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );

                                        // Guardar la alarma (esto tomará screenshots de ambos temas)
                                        await _saveAlarm();

                                        // Cerrar diálogo de carga
                                        Navigator.pop(context);

                                        // Mostrar animación Lottie de éxito
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
                                                    Lottie.asset(
                                                      'assets/lotties/checked.json',
                                                      width: 200,
                                                      height: 200,
                                                      fit: BoxFit.contain,
                                                    ),
                                                    SizedBox(height: 16),
                                                    Text(
                                                      'Alarma guardada exitosamente',
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

    for (int i = 0; i < numPoints; i++) {
      double angle = (2 * pi * i) / numPoints;

      // Convertir latitud y longitud a radianes
      double latRad = center.latitude * (pi / 180);
      double lonRad = center.longitude * (pi / 180);

      // Calcular nueva latitud
      double newLat = asin(sin(latRad) * cos(radiusInMeters / earthRadius) +
          cos(latRad) * sin(radiusInMeters / earthRadius) * cos(angle));

      // Calcular nueva longitud
      double newLon = lonRad +
          atan2(sin(angle) * sin(radiusInMeters / earthRadius) * cos(latRad),
              cos(radiusInMeters / earthRadius) - sin(latRad) * sin(newLat));

      // Convertir de vuelta a grados
      points.add(LatLng(newLat * (180 / pi), newLon * (180 / pi)));
    }

    // Cerrar el polígono (volver al primer punto)
    points.add(points[0]);

    return points;
  }

  Future<void> _removeGeofence() async {
    final controller = await _controllerCompleter.future;
    for (var fill in _geofenceFills) {
      await controller.removeFill(fill);
    }
    _geofenceFills.clear();
  }

  Future<void> drawGeocodingCircle() async {
    print('Dibujando círculo: ${_markerPosition}');
    if (!_styleLoaded || _markerPosition == null) return;

    try {
      final controller = await _controllerCompleter.future;
      await _removeGeofence();
      // Generar puntos del círculo (64 puntos para un círculo suave)
      List<LatLng> circlePoints = _generateCirclePoints(_markerPosition!, _geofenceRadius, 64);

      // Crear el polígono circular
      String colorHex = '#${KColors.mainColor.value.toRadixString(16).substring(2)}';

      final newFill = await controller.addFill(
        FillOptions(
          geometry: [circlePoints], // Lista de anillos (el primero es el exterior)
          fillColor: colorHex,
          fillOpacity: 0.3,
          fillOutlineColor: colorHex,
        ),
      );

      // Guardar la referencia del nuevo polígono
      _geofenceFills.add(newFill);

      print('Círculo actualizado - Radio: ${_geofenceRadius}m');
    } catch (e) {
      print('Error dibujando círculo: $e');
    }
  }

  // Método para actualizar el radio cuando cambia el slider
  Future<void> _updateGeofenceRadius(double newRadius) async {
    setState(() {
      _geofenceRadius = newRadius;
    });
    await drawGeocodingCircle();
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
  Future<void> _saveAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener dirección mediante reverse geocoding
      String address = await _reverseGeocode(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
      );

      // Tomar screenshot del mapa antes de guardar
      String? previewImage = await _takeMapScreenshot();

      // Crear nueva alarma con la imagen previa y dirección
      final alarm = Alarm(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // ID único basado en timestamp
        name: _alarmNameController.text.trim(),
        latitude: _markerPosition!.latitude,
        longitude: _markerPosition!.longitude,
        address: address,
        radius: _geofenceRadius,
        createdAt: DateTime.now(),
        previewImageBase64: previewImage,
      );

      // Cargar alarmas existentes
      List<Alarm> alarms = await _loadAlarms();

      // Agregar nueva alarma
      alarms.add(alarm);

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
    } catch (e) {
      print('Error guardando alarma: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la alarma: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  // Eliminar una alarma por ID
  Future<void> _deleteAlarm(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Alarm> alarms = await _loadAlarms();

      // Filtrar la alarma a eliminar
      alarms.removeWhere((alarm) => alarm.id == alarmId);

      // Guardar lista actualizada
      List<String> alarmsJson = alarms.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(KConstants.alarmsKey, alarmsJson);

      print('Alarma eliminada: $alarmId');
    } catch (e) {
      print('Error eliminando alarma: $e');
    }
  }
}
