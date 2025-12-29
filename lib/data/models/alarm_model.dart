class Alarm {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address; // Dirección obtenida mediante reverse geocoding
  final double radius; // Radio del geofence en metros
  final DateTime createdAt;
  final String? previewImageBase64; // Imagen previa del mapa en base64
  final String? category; // Categoría de la alarma (home, work, train, other)
  final bool isActive; // Si la alarma está activa o no

  Alarm({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.radius,
    required this.createdAt,
    this.previewImageBase64,
    this.category,
    this.isActive = true, // Por defecto activa
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
      'category': category ?? 'other',
      'isActive': isActive,
      'previewImageBase64': previewImageBase64 ?? '', // Al final para que no corte el log
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
      category: json['category'] as String?,
      isActive: json['isActive'] as bool? ?? true, // Por defecto true para alarmas antiguas
    );
  }

  // Crear una copia con campos modificados
  Alarm copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    double? radius,
    DateTime? createdAt,
    String? previewImageBase64,
    String? category,
    bool? isActive,
  }) {
    return Alarm(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      radius: radius ?? this.radius,
      createdAt: createdAt ?? this.createdAt,
      previewImageBase64: previewImageBase64 ?? this.previewImageBase64,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }
}
