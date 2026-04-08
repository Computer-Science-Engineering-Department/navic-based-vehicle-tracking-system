import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  late Stream<List<Bus>> _busStream;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
  }

  void _resetBusStream() {
    if (!mounted) {
      return;
    }
    setState(() {
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
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<Bus>>(
        stream: _busStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StreamErrorView(
              message:
                  'Unable to load the buses list. Please check your network connection.',
              onRetry: _resetBusStream,
            );
          }
          final buses = snapshot.data ?? [];
          if (buses.isEmpty) {
            return const Center(child: Text('No buses available right now.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final bus = buses[index];
              final location = bus.location;
              final subtitle = location == null
                  ? 'Waiting for driver updates'
                  : 'Updated ${DateFormat.Hm().format(location.timestamp)}';
              final badge = bus.routeNumber.isNotEmpty
                  ? bus.routeNumber.substring(0, 1)
                  : '?';
              return ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(child: Text(badge)),
                title: Text(bus.name),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BusDetailPage(bus: bus)),
                ),
              );
            },
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemCount: buses.length,
          );
        },
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

  void _retryLocationStream() {
    setState(() => _locationRetryToken++);
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BusRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.bus.name)),
      body: StreamBuilder<BusLocation?>(
        key: ValueKey(_locationRetryToken),
        stream: repository.watchBusLocation(widget.bus.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StreamErrorView(
              message: 'Unable to load live bus location. Please try again.',
              onRetry: _retryLocationStream,
            );
          }
          final location = snapshot.data;
          if (location == null) {
            return const Center(
              child: Text('Driver has not started sharing location yet.'),
            );
          }
          final formatter = DateFormat('MMM d, HH:mm:ss');
          final busPosition = LatLng(location.latitude, location.longitude);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bus.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _LocationNameLabel(location: location),
                        if (location.speed != null)
                          Text(
                            'Speed: ${(location.speed! * 3.6).toStringAsFixed(1)} km/h',
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Last update: ${formatter.format(location.timestamp)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: busPosition,
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.navic_based_vehicle_tracking_system',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: busPosition,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.directions_bus_filled,
                                size: 40,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreamErrorView extends StatelessWidget {
  const _StreamErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resolves the current coordinates into a readable place name for display.
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
          return const Text('Location: resolving...');
        }
        if (snapshot.hasError) {
          return const Text('Location: unavailable');
        }
        final name = snapshot.data;
        if (name == null || name.isEmpty) {
          return Text(
            'Location: ${location.latitude.toStringAsFixed(4)}, '
            '${location.longitude.toStringAsFixed(4)}',
          );
        }
        return Text('Location: $name');
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
      placemark.subLocality?.trim() ?? '',
      placemark.locality?.trim() ?? '',
      placemark.administrativeArea?.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty && (placemark.country?.isNotEmpty ?? false)) {
      parts.add(placemark.country!.trim());
    }
    return parts.isEmpty ? null : parts.join(', ');
  } catch (error) {
    debugPrint('Reverse geocoding failed: $error');
    return null;
  }
}
