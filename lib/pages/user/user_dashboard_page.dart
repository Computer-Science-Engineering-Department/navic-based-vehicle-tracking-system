import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_handler.dart';
import '../../widgets/common_widgets.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  late Stream<List<Bus>> _busStream;
  int _retryToken = 0;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
    logger.info('User dashboard initialized');
  }

  void _resetBusStream() {
    if (!mounted) return;
    setState(() {
      _retryToken++;
      _busStream = context.read<BusRepository>().watchBuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Bus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _resetBusStream,
          ),
          IconButton(
            onPressed: () async {
              try {
                await auth.signOut();
              } catch (error) {
                if (mounted) {
                  ErrorHandler.showErrorSnackBar(context, error);
                }
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<Bus>>(
        key: ValueKey(_retryToken),
        stream: _busStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading buses...');
          }

          if (snapshot.hasError) {
            logger.error('Failed to load buses', snapshot.error);
            return ErrorStateWidget(
              message: 'Unable to load buses. Please check your connection.',
              onRetry: _resetBusStream,
            );
          }

          final buses = snapshot.data ?? [];

          if (buses.isEmpty) {
            return const EmptyStateWidget(
              message: 'No buses available right now.\nCheck back later!',
              icon: Icons.directions_bus_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _resetBusStream();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final bus = buses[index];
                return _BusCard(bus: bus);
              },
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemCount: buses.length,
            ),
          );
        },
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context) {
    final location = bus.location;
    final formatter = DateFormat('HH:mm');

    return Card(
      elevation: bus.isActive ? 3 : 1,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => BusDetailPage(bus: bus))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: bus.isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceVariant,
                child: Icon(
                  Icons.directions_bus,
                  size: 30,
                  color: bus.isActive
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bus.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: bus.isActive ? 'LIVE' : 'Offline',
                          isActive: bus.isActive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Route ${bus.routeNumber}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Updated ${formatter.format(location.timestamp)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Waiting for driver to start...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusDetailPage extends StatefulWidget {
  const BusDetailPage({super.key, required this.bus});

  final Bus bus;

  @override
  State<BusDetailPage> createState() => _BusDetailPageState();
}

class _BusDetailPageState extends State<BusDetailPage> {
  int _locationRetryToken = 0;
  final MapController _mapController = MapController();

  void _retryLocationStream() {
    setState(() => _locationRetryToken++);
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BusRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bus.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _retryLocationStream,
          ),
        ],
      ),
      body: StreamBuilder<BusLocation?>(
        key: ValueKey(_locationRetryToken),
        stream: repository.watchBusLocation(widget.bus.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading location...');
          }

          if (snapshot.hasError) {
            logger.error('Failed to load bus location', snapshot.error);
            return ErrorStateWidget(
              message: 'Unable to load bus location. Please try again.',
              onRetry: _retryLocationStream,
            );
          }

          final location = snapshot.data;

          if (location == null) {
            return EmptyStateWidget(
              message:
                  'Driver has not started sharing location yet.\nCheck back soon!',
              icon: Icons.location_off,
              action: _retryLocationStream,
              actionLabel: 'Refresh',
            );
          }

          if (!location.isValid) {
            return const ErrorStateWidget(
              message: 'Invalid location data received',
            );
          }

          final busPosition = LatLng(location.latitude, location.longitude);

          return Column(
            children: [
              // Info Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.bus.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Route ${widget.bus.routeNumber}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(label: 'LIVE', isActive: true),
                        ],
                      ),
                      const Divider(height: 24),
                      _LocationNameLabel(location: location),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (location.speed != null)
                            Expanded(
                              child: InfoCard(
                                title: 'Speed',
                                value:
                                    '${location.speedKmh.toStringAsFixed(1)} km/h',
                                icon: Icons.speed,
                              ),
                            ),
                          if (location.speed != null) const SizedBox(width: 12),
                          Expanded(
                            child: InfoCard(
                              title: 'Updated',
                              value: DateFormat(
                                'HH:mm:ss',
                              ).format(location.timestamp),
                              icon: Icons.access_time,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Map
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: busPosition,
                        initialZoom: 15,
                        minZoom: 10,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.navic_based_vehicle_tracking_system',
                          tileProvider: NetworkTileProvider(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: busPosition,
                              width: 80,
                              height: 80,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      widget.bus.routeNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.directions_bus,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final location = widget.bus.location;
          if (location != null) {
            _mapController.move(
              LatLng(location.latitude, location.longitude),
              15,
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _LocationNameLabel extends StatelessWidget {
  const _LocationNameLabel({required this.location});

  final BusLocation location;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.maybeLocaleOf(context)?.toLanguageTag();

    return FutureBuilder<String?>(
      future: _reverseGeocodeLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        localeTag: localeTag,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading location...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        final name = snapshot.data;
        final displayText = name != null && name.isNotEmpty
            ? name
            : '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';

        return Row(
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<String?> _reverseGeocodeLocation({
  required double latitude,
  required double longitude,
  String? localeTag,
}) async {
  try {
    final placemarks = await geocoding.placemarkFromCoordinates(
      latitude,
      longitude,
    );

    if (placemarks.isEmpty) {
      return null;
    }

    final placemark = placemarks.first;
    final parts = <String>[
      if (placemark.street?.isNotEmpty ?? false) placemark.street!.trim(),
      if (placemark.subLocality?.isNotEmpty ?? false)
        placemark.subLocality!.trim(),
      if (placemark.locality?.isNotEmpty ?? false) placemark.locality!.trim(),
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty && (placemark.country?.isNotEmpty ?? false)) {
      parts.add(placemark.country!.trim());
    }

    return parts.isEmpty ? null : parts.join(', ');
  } catch (error) {
    logger.error('Reverse geocoding failed', error);
    return null;
  }
}
