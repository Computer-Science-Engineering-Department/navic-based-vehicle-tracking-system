import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/app_exception.dart';
import '../utils/app_logger.dart';

class LocationTracker {
  StreamSubscription<Position>? _subscription;
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;
  bool get isTracking => _subscription != null;

  Future<bool> ensurePermissions() async {
    try {
      logger.info('Checking location permissions');
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.warning('Location services are disabled');
        throw const PermissionException(
          'Location services are disabled',
          'location-service-disabled',
        );
      }

      var permission = await Geolocator.checkPermission();
      logger.debug('Current location permission: $permission');

      if (permission == LocationPermission.denied) {
        logger.info('Requesting location permission');
        permission = await Geolocator.requestPermission();
        logger.debug('Permission result: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        logger.error('Location permission permanently denied');
        throw const PermissionException(
          'Location permission was permanently denied',
          'location-denied-forever',
        );
      }

      if (permission == LocationPermission.denied) {
        logger.warning('Location permission denied');
        throw const PermissionException(
          'Location permission was denied',
          'location-denied',
        );
      }

      logger.info('Location permissions granted');
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      logger.error('Error checking location permissions', e);
      throw PermissionException('Failed to check location permissions: $e');
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      logger.debug('Getting current position');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPosition = position;
      return position;
    } catch (error, stackTrace) {
      logger.error('Failed to get current position', error, stackTrace);
      return null;
    }
  }

  Future<void> startTracking(
    Function(Position) onPosition, {
    Function(Object)? onError,
  }) async {
    try {
      logger.info('Starting location tracking');
      await _subscription?.cancel();
      
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 25, // Update every 25 meters
        timeLimit: Duration(minutes: 5), // Timeout after 5 minutes
      );

      _subscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (position) {
          _lastPosition = position;
          logger.debug(
            'Position update: ${position.latitude}, ${position.longitude}',
          );
          onPosition(position);
        },
        onError: (error, stackTrace) {
          logger.error('Location stream error', error, stackTrace);
          onError?.call(error);
        },
        onDone: () {
          logger.info('Location stream closed');
        },
        cancelOnError: false, // Keep stream alive on errors
      );

      logger.info('Location tracking started');
    } catch (error, stackTrace) {
      logger.error('Failed to start location tracking', error, stackTrace);
      throw PermissionException('Failed to start tracking: $error');
    }
  }

  Future<void> stopTracking() async {
    try {
      logger.info('Stopping location tracking');
      await _subscription?.cancel();
      _subscription = null;
      _lastPosition = null;
    } catch (error, stackTrace) {
      logger.error('Error stopping location tracking', error, stackTrace);
    }
  }

  void dispose() {
    logger.debug('Disposing location tracker');
    _subscription?.cancel();
    _subscription = null;
    _lastPosition = null;
  }
}
