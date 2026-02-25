import 'package:geolocator/geolocator.dart';

class Bus {
  Bus({
    required this.id,
    required this.name,
    required this.routeNumber,
    required this.driverIds,
    this.location,
    this.activeDriverId,
    this.capacity,
  });

  final String id;
  final String name;
  final String routeNumber;
  final List<String> driverIds;
  final BusLocation? location;
  final String? activeDriverId;
  final int? capacity;

  bool isAssignedTo(String uid) => driverIds.contains(uid);
  bool get isActive => location != null && activeDriverId != null;
  bool get hasRecentUpdate {
    if (location == null) return false;
    final diff = DateTime.now().difference(location!.timestamp);
    return diff.inMinutes < 5; // Consider updates within 5 minutes as recent
  }

  Bus copyWith({
    BusLocation? location,
    String? activeDriverId,
    bool clearActiveDriver = false,
  }) =>
      Bus(
        id: id,
        name: name,
        routeNumber: routeNumber,
        driverIds: driverIds,
        location: location ?? this.location,
        activeDriverId: clearActiveDriver ? null : (activeDriverId ?? this.activeDriverId),
        capacity: capacity,
      );

  static Bus fromMap(String id, Map<dynamic, dynamic> data) {
    try {
      final drivers = <String>[];
      final driverMap = data['driverIds'];
      if (driverMap is Map) {
        final entries = Map<dynamic, dynamic>.from(driverMap).entries;
        drivers.addAll(
          entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key.toString()),
        );
      }

      final locationMap = data['location'];
      return Bus(
        id: id,
        name: data['name']?.toString() ?? 'Bus $id',
        routeNumber: data['routeNumber']?.toString() ?? '-',
        driverIds: drivers,
        location: locationMap is Map ? BusLocation.fromMap(locationMap) : null,
        activeDriverId: data['activeDriverId']?.toString(),
        capacity: data['capacity'] != null ? int.tryParse(data['capacity'].toString()) : null,
      );
    } catch (e) {
      // Return a default bus if parsing fails
      return Bus(
        id: id,
        name: 'Bus $id',
        routeNumber: '-',
        driverIds: const [],
      );
    }
  }

  Map<String, dynamic> toMap() {
    final driverMap = <String, bool>{};
    for (final driverId in driverIds) {
      driverMap[driverId] = true;
    }

    return {
      'name': name,
      'routeNumber': routeNumber,
      'driverIds': driverMap,
      if (activeDriverId != null) 'activeDriverId': activeDriverId,
      if (capacity != null) 'capacity': capacity,
      if (location != null) 'location': location!.toMap(),
    };
  }
}

class BusLocation {
  const BusLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.heading,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed;
  final double? heading;
  final double? accuracy;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  double get speedKmh => (speed ?? 0) * 3.6;

  static BusLocation fromMap(Map<dynamic, dynamic> data) {
    try {
      final timestamp = data['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse('${data['updatedAt']}') ??
                  DateTime.now().millisecondsSinceEpoch,
            )
          : DateTime.now();

      return BusLocation(
        latitude: _parseDouble(data['lat']),
        longitude: _parseDouble(data['lng']),
        timestamp: timestamp,
        speed: data['speed'] == null ? null : _parseDouble(data['speed']),
        heading: data['heading'] == null ? null : _parseDouble(data['heading']),
        accuracy:
            data['accuracy'] == null ? null : _parseDouble(data['accuracy']),
      );
    } catch (e) {
      // Return a default invalid location if parsing fails
      return BusLocation(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'updatedAt': timestamp.millisecondsSinceEpoch,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
      };

  static BusLocation fromPosition(Position position) => BusLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed <= 0 ? null : position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
}

double _parseDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
