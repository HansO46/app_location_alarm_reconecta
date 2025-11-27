import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:http/http.dart' as http;

class Example2Page extends StatefulWidget {
  const Example2Page({super.key});

  @override
  State<Example2Page> createState() => _Example2PageState();
}

class _Example2PageState extends State<Example2Page> {
  // Controlador del campo de texto donde el usuario escribe la búsqueda
  final TextEditingController _searchController =
      TextEditingController(text: 'Ángel de la Independencia');

  // Variables de estado para almacenar los resultados de cada servicio
  String? _geoCodingResult; // Resultados de Mapbox
  String? _nominatimResult; // Resultados de Nominatim (OSM)
  String? _placesResult; // Resultados de búsqueda de lugares (no usado actualmente)
  bool _loading = false; // Indica si hay una búsqueda en progreso
  String? _mapboxKey; // API key de Mapbox (opcional)

  @override
  void initState() {
    super.initState();
    // Al inicializar el widget, intentamos obtener la API key de Mapbox
    // Esto es opcional - Nominatim funciona sin API key
    _initializeMapbox();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Inicializa la API key de Mapbox (opcional)
  /// Intenta obtenerla desde variables de entorno, si no existe usa una hardcodeada
  /// NOTA: Nominatim NO requiere API key, así que esta función es solo para Mapbox
  Future<void> _initializeMapbox() async {
    // Intentar obtener desde --dart-define primero (ej: flutter run --dart-define=ACCESS_TOKEN=xxx)
    String MAPBOX_KEY = String.fromEnvironment("ACCESS_TOKEN");

    // Si está vacío, usar el token directamente (ya que está en strings.xml)
    if (MAPBOX_KEY.isEmpty) {
      print(' ACCESS_TOKEN está vacío desde --dart-define');
      print('Usando token desde strings.xml (hardcoded para pruebas)');
      MAPBOX_KEY =
          'pk.eyJ1IjoiaGFuczA0NiIsImEiOiJjbWh4dDVxcmkwNHRpMmxvcW5xdnh2N3VnIn0.3_W6I8Jcl8556RcKgVNWLg';
    }

    _mapboxKey = MAPBOX_KEY;
    MapBoxSearch.init(MAPBOX_KEY); // Inicializa el SDK de Mapbox (no usado en este ejemplo)
  }

  /// ============================================================
  /// FLUJO PRINCIPAL: Esta función se ejecuta cuando el usuario presiona "Buscar"
  /// ============================================================
  ///
  /// PASO 1: Validación
  ///   - Verifica que el campo de texto no esté vacío
  ///
  /// PASO 2: Preparación del estado
  ///   - Activa el indicador de carga (_loading = true)
  ///   - Limpia los resultados anteriores (null)
  ///
  /// PASO 3: Ejecución de búsquedas (en orden secuencial)
  ///   a) Primero: Nominatim
  ///   b) Segundo: Mapbox
  ///
  /// PASO 4: Manejo de errores y finalización
  ///   - Captura cualquier error
  ///   - Asegura que _loading se desactive al finalizar
  /// ============================================================
  Future<void> _searchAddress() async {
    // VALIDACIÓN: Verificar que el usuario haya escrito algo
    if (_searchController.text.isEmpty) {
      setState(() {
        _geoCodingResult = 'Por favor escribe una dirección';
      });
      return; // Salir temprano si no hay texto
    }

    // PREPARACIÓN: Limpiar resultados anteriores y activar loading
    setState(() {
      _loading = true; // Muestra el spinner de carga
      _geoCodingResult = null; // Limpia resultados de Mapbox
      _nominatimResult = null; // Limpia resultados de Nominatim
      _placesResult = null; // Limpia otros resultados
    });

    try {
      // ============================================================
      // BÚSQUEDA 1: Nominatim (OpenStreetMap) - GRATUITO
      // ============================================================
      // Esta es la primera búsqueda que se ejecuta
      // No requiere API key, es completamente gratuito
      // URL: https://nominatim.openstreetmap.org/search
      await _searchWithNominatim(_searchController.text);

      // ============================================================
      // BÚSQUEDA 2: Mapbox - REQUIERE API KEY
      // ============================================================
      // Esta búsqueda solo se ejecuta si Mapbox está configurado
      // Si _mapboxKey es null, esta búsqueda se omite
      // URL: https://api.mapbox.com/geocoding/v5/mapbox.places/
      if (_mapboxKey != null) {
        await _searchPlace(_searchController.text);
      }
    } catch (e) {
      // MANEJO DE ERRORES: Si algo falla, mostrar el error
      setState(() {
        _geoCodingResult = 'Error: $e';
        _loading = false;
      });
    } finally {
      // FINALIZACIÓN: Asegurar que el loading se desactive siempre
      // Esto se ejecuta incluso si hay un error
      if (_loading) {
        setState(() {
          _loading = false; // Oculta el spinner de carga
        });
      }
    }
  }

  /// ============================================================
  /// BÚSQUEDA CON NOMINATIM (OpenStreetMap Geocoding)
  /// ============================================================
  ///
  /// Esta función realiza una búsqueda de geocoding usando Nominatim
  /// Nominatim es el servicio oficial de geocoding de OpenStreetMap
  ///
  /// VENTAJAS:
  ///   - Completamente GRATUITO
  ///   - NO requiere API key
  ///   - Basado en datos abiertos de OpenStreetMap
  ///   - Incluye detalles de dirección estructurados
  ///
  /// FLUJO DE EJECUCIÓN:
  ///   1. Codifica el query para URL (ej: "Ángel" -> "%C3%81ngel")
  ///   2. Construye la URL con parámetros:
  ///      - q: query de búsqueda
  ///      - format=jsonv2: formato de respuesta JSON v2
  ///      - limit=5: máximo 5 resultados
  ///      - addressdetails=1: incluir detalles de dirección
  ///      - extratags=1: incluir tags adicionales
  ///   3. Envía GET request con headers apropiados
  ///   4. Procesa la respuesta JSON
  ///   5. Extrae y formatea los datos para mostrar
  /// ============================================================
  Future<void> _searchWithNominatim(String query) async {
    try {
      print('Buscando con Nominatim: $query');

      // PASO 1: Codificar el texto de búsqueda para URL
      // Ejemplo: "Ángel de la Independencia" -> "%C3%81ngel%20de%20la%20Independencia"
      final encodedQuery = Uri.encodeComponent(query);

      // PASO 2: Construir la URL completa con todos los parámetros
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?'
          'q=$encodedQuery&' // Query de búsqueda
          'format=jsonv2&' // Formato JSON v2 (más completo)
          'limit=5&' // Máximo 5 resultados
          'addressdetails=1&' // Incluir detalles de dirección estructurados
          'extratags=1'); // Incluir tags adicionales (wikipedia, etc.)

      // PASO 3: Enviar solicitud HTTP GET
      // IMPORTANTE: Nominatim requiere User-Agent obligatorio
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'app_location_alarm_reconecta/1.0', // OBLIGATORIO para Nominatim
          'Accept-Language': 'es-MX,es,en', // Idioma preferido para resultados
        },
      );

      print(' Respuesta Nominatim: ${response.statusCode}');

      // PASO 4: Verificar que la respuesta sea exitosa (código 200)
      if (response.statusCode == 200) {
        // PASO 5: Decodificar el JSON de respuesta
        // La respuesta es un array de lugares encontrados
        final data = jsonDecode(response.body) as List;

        // PASO 6: Verificar si hay resultados
        if (data.isEmpty) {
          setState(() {
            _nominatimResult = 'No se encontraron resultados en Nominatim para "$query"';
          });
          return; // Salir si no hay resultados
        }

        // PASO 7: Construir el texto de resultados
        String result = '📍 Nominatim (OSM) - Encontrados ${data.length} lugares:\n\n';

        // PASO 8: Iterar sobre cada lugar encontrado y extraer información
        for (var i = 0; i < data.length; i++) {
          var place = data[i];

          // Extraer campos principales del lugar
          var displayName = place['display_name'] ?? 'Sin nombre'; // Nombre completo del lugar
          var lat = place['lat'] ?? ''; // Latitud
          var lon = place['lon'] ?? ''; // Longitud
          var type = place['type'] ?? ''; // Tipo específico (ej: "monument")
          var category = place['category'] ?? ''; // Categoría (ej: "tourism")
          var importance = place['importance'] ?? ''; // Importancia (0.0 a 1.0)

          // PASO 9: Extraer detalles de dirección estructurados
          // Nominatim devuelve la dirección descompuesta en partes
          var address = place['address'] as Map<String, dynamic>?;
          String addressDetails = '';
          if (address != null) {
            var road = address['road'] ?? ''; // Nombre de la calle
            var houseNumber = address['house_number'] ?? ''; // Número de casa
            var city = address['city'] ?? address['town'] ?? address['village'] ?? ''; // Ciudad
            var state = address['state'] ?? ''; // Estado/Provincia
            var country = address['country'] ?? ''; // País
            var postcode = address['postcode'] ?? ''; // Código postal

            // Construir dirección formateada
            if (houseNumber.isNotEmpty && road.isNotEmpty) {
              addressDetails = '$houseNumber $road';
            } else if (road.isNotEmpty) {
              addressDetails = road;
            }
            if (city.isNotEmpty) addressDetails += ', $city';
            if (state.isNotEmpty) addressDetails += ', $state';
            if (country.isNotEmpty) addressDetails += ', $country';
            if (postcode.isNotEmpty) addressDetails += ' ($postcode)';
          }

          // PASO 10: Formatear la información del lugar para mostrar
          result += 'Lugar ${i + 1}:\n';
          result += '   Nombre: $displayName\n';
          if (addressDetails.isNotEmpty && addressDetails != displayName) {
            result += '   Dirección: $addressDetails\n';
          }
          result += '   Tipo: $category${type.isNotEmpty ? ' ($type)' : ''}\n';
          if (lat.isNotEmpty && lon.isNotEmpty) {
            result += '   Coordenadas: Lat: $lat, Lng: $lon\n';
          }
          if (importance.toString().isNotEmpty) {
            result += '   Importancia: $importance\n';
          }
          result += '\n';
        }

        // PASO 11: Actualizar el estado con los resultados formateados
        // Esto dispara un rebuild del widget y muestra los resultados en pantalla
        setState(() {
          _nominatimResult = result;
        });
      } else {
        setState(() {
          _nominatimResult =
              'Error Nominatim: ${response.statusCode} - ${response.body.substring(0, 200)}';
        });
      }
    } catch (e) {
      setState(() {
        _nominatimResult = 'Error al buscar en Nominatim: $e';
      });
      print('Error Nominatim: $e');
    }
  }

  /// ============================================================
  /// BÚSQUEDA CON MAPBOX (Geocoding Comercial)
  /// ============================================================
  ///
  /// Esta función realiza una búsqueda de geocoding usando Mapbox
  /// Mapbox es un servicio comercial que requiere API key
  ///
  /// REQUISITOS:
  ///   - API key de Mapbox (almacenada en _mapboxKey)
  ///   - Si no hay API key, esta función no se ejecuta
  ///
  /// ESTRATEGIA HÍBRIDA:
  ///   1. Primero busca POIs (Points of Interest) - lugares específicos
  ///   2. Si no encuentra POIs, busca todo (direcciones + lugares)
  ///
  /// FLUJO DE EJECUCIÓN:
  ///   1. Verificar que existe API key
  ///   2. Codificar el query para URL
  ///   3. Primera búsqueda: solo POIs (types=poi)
  ///   4. Si no hay resultados, segunda búsqueda: todo (sin filtro)
  ///   5. Procesar respuesta y formatear resultados
  /// ============================================================
  Future<void> _searchPlace(String query) async {
    // VALIDACIÓN: Solo ejecutar si Mapbox está configurado
    if (_mapboxKey == null) return;

    setState(() => _loading = true);

    try {
      // PASO 1: Codificar el texto de búsqueda para URL
      final encodedQuery = Uri.encodeComponent(query);

      // PASO 2: Primera búsqueda - Buscar solo POIs (Points of Interest)
      // POIs son lugares específicos como restaurantes, monumentos, etc.
      // URL: https://api.mapbox.com/geocoding/v5/mapbox.places/{query}.json
      var response = await http.get(Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=${_mapboxKey!}&limit=5&types=poi'));

      // PASO 3: Verificar si la primera búsqueda encontró resultados
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        // Si no hay POIs, hacer segunda búsqueda sin filtro
        if (features.isEmpty) {
          // PASO 4: Segunda búsqueda - Buscar todo (direcciones + lugares)
          // Esta búsqueda es más amplia y puede encontrar direcciones también
          response = await http.get(Uri.parse(
              'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=${_mapboxKey!}&limit=5'));
        }
      }

      // PASO 5: Procesar la respuesta final (ya sea de POIs o búsqueda amplia)
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List; // Array de lugares encontrados

        // PASO 6: Verificar si hay resultados
        if (features.isEmpty) {
          setState(() {
            _geoCodingResult = '🗺️ Mapbox - No se encontraron resultados para "$query"';
            _loading = false;
          });
          return;
        }

        // PASO 7: Construir el texto de resultados
        String result = 'Encontrados ${features.length} lugares:\n\n';

        // PASO 8: Iterar sobre cada lugar encontrado
        for (var i = 0; i < features.length; i++) {
          var feature = features[i];

          // Extraer información del lugar
          var placeName = feature['place_name'] ?? feature['text'] ?? 'Sin nombre';
          var coordinates = feature['geometry']['coordinates'] as List;
          var placeType = feature['place_type'] ?? ['unknown']; // Array de tipos

          // IMPORTANTE: En Mapbox, las coordenadas vienen como [longitude, latitude]
          // (al revés que en otros sistemas que usan [latitude, longitude])
          var longitude = coordinates[0];
          var latitude = coordinates[1];

          // PASO 9: Formatear la información del lugar
          result += 'Lugar ${i + 1}:\n';
          result += '   Nombre: $placeName\n';
          result += '   Tipo: ${placeType.join(", ")}\n'; // Un lugar puede tener múltiples tipos
          result += '   Coordenadas: Lat: $latitude, Lng: $longitude\n';
          result += '\n';
        }

        // PASO 10: Actualizar el estado con los resultados
        // NOTA: No desactivamos _loading aquí porque puede haber más búsquedas pendientes
        setState(() {
          _geoCodingResult = '🗺️ Mapbox - Encontrados ${features.length} lugares:\n\n$result';
          // No establecer _loading = false aquí, se hará al finalizar todas las búsquedas
        });
      } else {
        setState(() {
          _geoCodingResult = 'Error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _geoCodingResult = 'Error al buscar: $e';
      });
      print('Error Mapbox: $e');
    }
  }

  ///Reverse GeoCoding sample call (ya no se usa, solo para referencia)
  Future<void> geoCoding(String apiKey) async {
    var geoCodingService = GeoCoding(
      country: "MX",
      limit: 5,
    );

    var addresses = await geoCodingService.getAddress((
      lat: -19.984846,
      long: -43.946852,
    ));

    addresses.fold(
      (success) {
        setState(() {
          _geoCodingResult = success.toString();
        });
        print(success);
      },
      (failure) {
        setState(() {
          _geoCodingResult = 'Error: $failure';
        });
        print(failure);
      },
    );
  }

  /// Obtener museos de CDMX usando Overpass API (ejemplo de la guía)
  Future<List<Map<String, dynamic>>> getMuseosCDMX() async {
    final query = '''
      [out:json];
      area["name"="Ciudad de México"]->.cdmx;
      node["tourism"="museum"](area.cdmx);
      out center;
    ''';

    final url = Uri.parse("https://overpass-api.de/api/interpreter");
    final response = await http.post(url, body: {"data": query});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['elements'] as List)
          .map((e) => {
                "name": e["tags"]?["name"] ?? "Sin nombre",
                "lat": e["lat"] ?? e["center"]?["lat"],
                "lon": e["lon"] ?? e["center"]?["lon"],
              })
          .toList();
    } else {
      throw Exception('Error al obtener museos: ${response.statusCode}');
    }
  }

  ///Places search sample call
  Future<void> placesSearch(String apiKey) async {
    var placesService = GeoCoding(
      apiKey: apiKey,
      country: "MX",
      limit: 5,
    );

    var places = await placesService.getPlaces(
      "CIITEC",
      proximity: Proximity.LatLong(
        lat: -19.984634,
        long: -43.9502958,
      ),
    );

    setState(() {
      _placesResult = places.toString();
    });
    print(places);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buscar Lugar'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar dirección o lugar:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                label: Text('Angel de la Indeapendencia'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _geoCodingResult = null;
                            _nominatimResult = null;
                            _placesResult = null;
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
            SizedBox(height: 16),
            // ============================================================
            // BOTÓN DE BÚSQUEDA - PUNTO DE ENTRADA PRINCIPAL
            // ============================================================
            // Este botón ejecuta _searchAddress() cuando se presiona
            //
            // COMPORTAMIENTO:
            //   - Si _loading es true: botón deshabilitado, muestra spinner
            //   - Si _loading es false: botón habilitado, ejecuta búsqueda
            //
            // ALTERNATIVA: También se puede activar presionando Enter en el TextField
            // (ver línea 370: onSubmitted: (_) => _searchAddress())
            // ============================================================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _searchAddress, // ← AQUÍ SE CONECTA AL FLUJO PRINCIPAL
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2), // Muestra spinner mientras busca
                      )
                    : Text('Buscar'),
              ),
            ),
            SizedBox(height: 24),
            // Resultados de Nominatim (primero - gratuito)
            if (_nominatimResult != null) ...[
              Text(
                '1️⃣ Nominatim (OSM) - Gratuito:',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[300]),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[700]!, width: 2),
                ),
                child: Text(
                  _nominatimResult!,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
            // Resultados de Mapbox (segundo - requiere API key)
            if (_geoCodingResult != null) ...[
              SizedBox(height: 16),
              Text(
                '2️⃣ Mapbox (requiere API key):',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[300]),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[700]!, width: 2),
                ),
                child: Text(
                  _geoCodingResult!,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
            if (_placesResult != null) ...[
              SizedBox(height: 16),
              Text(
                'Places Search Result:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(_placesResult!),
            ],
          ],
        ),
      ),
    );
  }
}
