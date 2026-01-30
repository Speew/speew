import 'dart:async';
import '../core/utils.dart';

/// Compartilhamento de localização em tempo real
/// Estilo WhatsApp Live Location, Telegram Location
class LocationSharing {
  final Map<String, LiveLocation> _sharedLocations = {};
  final Map<String, Timer> _updateTimers = {};
  
  final StreamController<LocationUpdate> _locationController =
      StreamController<LocationUpdate>.broadcast();

  Stream<LocationUpdate> get locationStream => _locationController.stream;

  /// Compartilhar localização em tempo real
  Future<String?> shareLiveLocation({
    required Duration duration,
    required Function(Location) onUpdate,
  }) async {
    try {
      final sessionId = _generateSessionId();
      final endTime = DateTime.now().add(duration);

      final liveLocation = LiveLocation(
        sessionId: sessionId,
        startTime: DateTime.now(),
        endTime: endTime,
        isActive: true,
      );

      _sharedLocations[sessionId] = liveLocation;

      // Iniciar atualizações periódicas (a cada 5 segundos)
      _updateTimers[sessionId] = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _updateLocation(sessionId, onUpdate),
      );

      // Timer para parar compartilhamento
      Timer(duration, () => stopSharing(sessionId));

      DebugUtils.log(
        'Live location sharing started for ${duration.inMinutes}min',
        tag: 'LOCATION',
      );

      return sessionId;
    } catch (e) {
      DebugUtils.logError('Failed to share location', error: e);
      return null;
    }
  }

  /// Atualizar localização
  Future<void> _updateLocation(
    String sessionId,
    Function(Location) onUpdate,
  ) async {
    final liveLocation = _sharedLocations[sessionId];
    if (liveLocation == null || !liveLocation.isActive) return;

    try {
      // Obter localização atual
      final location = await _getCurrentLocation();

      if (location != null) {
        liveLocation.currentLocation = location;
        liveLocation.lastUpdate = DateTime.now();
        liveLocation.updateCount++;

        // Callback
        onUpdate(location);

        // Notificar
        _locationController.add(LocationUpdate(
          sessionId: sessionId,
          location: location,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      DebugUtils.logError('Failed to update location', error: e);
    }
  }

  /// Parar compartilhamento
  void stopSharing(String sessionId) {
    final liveLocation = _sharedLocations[sessionId];
    if (liveLocation != null) {
      liveLocation.isActive = false;
    }

    _updateTimers[sessionId]?.cancel();
    _updateTimers.remove(sessionId);

    DebugUtils.log('Live location sharing stopped', tag: 'LOCATION');
  }

  /// Compartilhar localização estática (uma vez)
  Future<Location?> shareStaticLocation() async {
    try {
      final location = await _getCurrentLocation();
      
      if (location != null) {
        DebugUtils.log(
          'Static location shared: ${location.latitude}, ${location.longitude}',
          tag: 'LOCATION',
        );
      }

      return location;
    } catch (e) {
      DebugUtils.logError('Failed to get location', error: e);
      return null;
    }
  }

  /// Obter localização atual
  Future<Location?> _getCurrentLocation() async {
    try {
      // Usar geolocator ou location package
      // final position = await Geolocator.getCurrentPosition();
      
      // Simulação
      return Location(
        latitude: -23.5505, // São Paulo
        longitude: -46.6333,
        accuracy: 10.0,
        altitude: 760.0,
        speed: 0.0,
        heading: 0.0,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Calcular distância entre dois pontos
  double calculateDistance(Location from, Location to) {
    // Fórmula de Haversine
    const earthRadius = 6371000.0; // metros

    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(from.latitude)) *
            _cos(_toRadians(to.latitude)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  /// Formatar distância
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Obter localização ativa
  LiveLocation? getLiveLocation(String sessionId) {
    return _sharedLocations[sessionId];
  }

  /// Verificar se está compartilhando
  bool isSharing(String sessionId) {
    return _sharedLocations[sessionId]?.isActive ?? false;
  }

  String _generateSessionId() {
    return 'loc_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Math helpers
  double _toRadians(double degrees) => degrees * 3.14159265359 / 180.0;
  double _sin(double x) => x - (x * x * x) / 6;
  double _cos(double x) => 1 - (x * x) / 2;
  double _sqrt(double x) => x > 0 ? x / 2 : 0;
  double _atan2(double y, double x) => y / x;

  void dispose() {
    for (final timer in _updateTimers.values) {
      timer.cancel();
    }
    _updateTimers.clear();
    _sharedLocations.clear();
    _locationController.close();
  }
}

class Location {
  final double latitude;
  final double longitude;
  final double accuracy; // metros
  final double? altitude; // metros
  final double? speed; // m/s
  final double? heading; // graus (0-360)
  final DateTime timestamp;

  Location({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    latitude: json['latitude'],
    longitude: json['longitude'],
    accuracy: json['accuracy'],
    altitude: json['altitude'],
    speed: json['speed'],
    heading: json['heading'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
  );

  String get coordinatesString => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

class LiveLocation {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  bool isActive;
  Location? currentLocation;
  DateTime? lastUpdate;
  int updateCount;

  LiveLocation({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    this.currentLocation,
    this.lastUpdate,
    this.updateCount = 0,
  });

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  String get timeRemainingFormatted {
    final remaining = timeRemaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isExpired => DateTime.now().isAfter(endTime);
}

class LocationUpdate {
  final String sessionId;
  final Location location;
  final DateTime timestamp;

  LocationUpdate({
    required this.sessionId,
    required this.location,
    required this.timestamp,
  });
}

/// Places Nearby (locais próximos)
class PlacesNearby {
  /// Buscar locais próximos
  static Future<List<Place>> searchNearby({
    required Location location,
    required String query,
    int radius = 1000, // metros
  }) async {
    try {
      // Usar Google Places API ou Nominatim (OpenStreetMap)
      // final places = await placesApi.searchNearby(...)
      
      DebugUtils.log(
        'Searching places near ${location.coordinatesString}',
        tag: 'PLACES',
      );

      // Simulação
      return [
        Place(
          id: '1',
          name: 'Café Central',
          address: 'Rua Principal, 123',
          location: Location(
            latitude: location.latitude + 0.001,
            longitude: location.longitude + 0.001,
            accuracy: 10,
            timestamp: DateTime.now(),
          ),
          category: 'Café',
          rating: 4.5,
        ),
      ];
    } catch (e) {
      return [];
    }
  }

  /// Obter endereço de coordenadas (reverse geocoding)
  static Future<String?> getAddress(Location location) async {
    try {
      // Usar Nominatim ou Google Geocoding API
      // final address = await geocoding.getAddress(...)
      
      return 'Rua Exemplo, 123 - São Paulo, SP';
    } catch (e) {
      return null;
    }
  }
}

class Place {
  final String id;
  final String name;
  final String address;
  final Location location;
  final String category;
  final double? rating;
  final String? phone;
  final String? website;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.category,
    this.rating,
    this.phone,
    this.website,
  });
}
