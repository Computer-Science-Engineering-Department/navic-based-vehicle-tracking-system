import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bus.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';
import '../utils/error_handler.dart';

class BusRepository {
  BusRepository() : _busesRef = FirebaseDatabase.instance.ref('buses');

  final DatabaseReference _busesRef;

  Stream<List<Bus>> watchBuses() {
    logger.debug('Watching buses stream');
    
    return _busesRef.onValue.map((event) {
      try {
        final data = event.snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          final buses = data.entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => Bus.fromMap(
                  entry.key.toString(),
                  Map<dynamic, dynamic>.from(entry.value as Map),
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          
          logger.debug('Loaded ${buses.length} buses');
          return buses;
        }
        logger.debug('No buses found in database');
        return <Bus>[];
      } catch (error, stackTrace) {
        logger.error('Failed to parse buses data', error, stackTrace);
        throw ErrorHandler.handleError(error, stackTrace);
      }
    }).handleError((error, stackTrace) {
      logger.error('Bus stream error', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    });
  }

  Stream<BusLocation?> watchBusLocation(String busId) {
    logger.debug('Watching location for bus: $busId');
    
    return _busesRef.child(busId).child('location').onValue.map((event) {
      try {
        final data = event.snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          final location = BusLocation.fromMap(data);
          if (location.isValid) {
            return location;
          } else {
            logger.warning('Invalid location data for bus $busId');
            return null;
          }
        }
        return null;
      } catch (error, stackTrace) {
        logger.error('Failed to parse bus location', error, stackTrace);
        return null; // Return null instead of throwing to keep stream alive
      }
    }).handleError((error, stackTrace) {
      logger.error('Bus location stream error', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    });
  }

  Future<void> updateBusLocation({
    required String busId,
    required String driverId,
    required Position position,
  }) async {
    try {
      final location = BusLocation.fromPosition(position);
      
      if (!location.isValid) {
        throw ValidationException('Invalid location coordinates');
      }

      final payload = location.toMap()..addAll({'driverId': driverId});

      await _busesRef.child(busId).child('location').set(payload);
      logger.debug('Updated location for bus $busId');
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to update bus location', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    } catch (error, stackTrace) {
      logger.error('Unexpected error updating bus location', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> setActiveDriver({
    required String busId,
    required String driverId,
  }) async {
    try {
      logger.info('Setting active driver $driverId for bus $busId');
      await _busesRef.child(busId).update({'activeDriverId': driverId});
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to set active driver', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> clearActiveDriver(String busId) async {
    try {
      logger.info('Clearing active driver for bus $busId');
      await _busesRef.child(busId).child('activeDriverId').remove();
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to clear active driver', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> createBus({
    required String name,
    required String routeNumber,
    List<String>? driverIds,
    int? capacity,
  }) async {
    try {
      if (name.trim().isEmpty) {
        throw ValidationException('Bus name cannot be empty');
      }
      if (routeNumber.trim().isEmpty) {
        throw ValidationException('Route number cannot be empty');
      }

      logger.info('Creating new bus: $name (Route: $routeNumber)');

      final newRef = _busesRef.push();
      final driversMap = <String, bool>{};
      if (driverIds != null) {
        for (final id in driverIds) {
          final normalized = id.trim();
          if (normalized.isEmpty) {
            continue;
          }
          driversMap[normalized] = true;
        }
      }

      await newRef.set({
        'name': name.trim(),
        'routeNumber': routeNumber.trim(),
        'driverIds': driversMap,
        if (capacity != null && capacity > 0) 'capacity': capacity,
      });

      logger.info('Bus created successfully with ID: ${newRef.key}');
    } on AppException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to create bus', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    } catch (error, stackTrace) {
      logger.error('Unexpected error creating bus', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> updateBus({
    required String busId,
    String? name,
    String? routeNumber,
    int? capacity,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        updates['name'] = name.trim();
      }
      if (routeNumber != null && routeNumber.trim().isNotEmpty) {
        updates['routeNumber'] = routeNumber.trim();
      }
      if (capacity != null && capacity > 0) {
        updates['capacity'] = capacity;
      }

      if (updates.isEmpty) {
        logger.warning('No valid updates provided for bus $busId');
        return;
      }

      logger.info('Updating bus $busId');
      await _busesRef.child(busId).update(updates);
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to update bus', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }

  Future<void> deleteBus(String busId) async {
    try {
      logger.info('Deleting bus $busId');
      await _busesRef.child(busId).remove();
    } on FirebaseException catch (error, stackTrace) {
      logger.error('Failed to delete bus', error, stackTrace);
      throw ErrorHandler.handleError(error, stackTrace);
    }
  }
}
