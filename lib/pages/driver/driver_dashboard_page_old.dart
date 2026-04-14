import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';
import '../../services/location_tracker.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  late final Stream<List<Bus>> _busStream;
  final LocationTracker _tracker = LocationTracker();
  String? _selectedBusId;
  bool _tracking = false;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _toggleTracking(bool value) async {
    final busRepository = context.read<BusRepository>();
    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    if (value) {
      if (_selectedBusId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a bus before sharing location.')),
        );
        return;
      }

      final granted = await _tracker.ensurePermissions();
      if (!granted) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      await busRepository.setActiveDriver(busId: _selectedBusId!, driverId: user.uid);
      await _tracker.startTracking((position) {
        busRepository.updateBusLocation(
          busId: _selectedBusId!,
          driverId: user.uid,
          position: position,
        );
        if (mounted) {
          setState(() => _lastPosition = position);
        }
      });

      if (!mounted) {
        return;
      }
      setState(() => _tracking = true);
    } else {
      await _tracker.stopTracking();
      if (_selectedBusId != null) {
        await busRepository.clearActiveDriver(_selectedBusId!);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _tracking = false;
        _lastPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Console'),
        actions: [
          IconButton(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<List<Bus>>(
                stream: _busStream,
                builder: (context, snapshot) {
                  final buses = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (buses.isEmpty) {
                    return const Center(child: Text('No buses configured yet.'));
                  }
                  return ListView(
                    children: [
                      const Text('Choose the bus you are driving:'),
                      const SizedBox(height: 8),
                      ...buses.map((bus) {
                        final isSelected = bus.id == _selectedBusId;
                        return Card(
                          child: ListTile(
                            title: Text('${bus.name} (${bus.routeNumber})'),
                            subtitle: Text(
                              bus.driverIds.isEmpty
                                  ? 'No assigned drivers'
                                  : 'Assigned drivers: ${bus.driverIds.length}',
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            selected: isSelected,
                            onTap: _tracking
                                ? null
                                : () => setState(() => _selectedBusId = bus.id),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Share live location'),
            subtitle: Text(_tracking
                ? 'Active - sending updates'
                : 'Location updates are paused'),
            value: _tracking,
            onChanged: (_selectedBusId == null && !_tracking)
                ? null
                : (value) => _toggleTracking(value),
          ),
          if (_lastPosition != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latitude: ${_lastPosition!.latitude.toStringAsFixed(5)}'),
                  Text('Longitude: ${_lastPosition!.longitude.toStringAsFixed(5)}'),
                  if (_lastPosition!.speed > 0)
                    Text('Speed: ${(_lastPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
                ],
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Location continues updating while the switch remains ON. Keep the app running in the background.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
