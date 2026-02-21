import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';
import '../../services/location_tracker.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_handler.dart';
import '../../widgets/common_widgets.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
    logger.info('Driver dashboard initialized');
  }

  @override
  void dispose() {
    _tracker.dispose();
    logger.debug('Driver dashboard disposed');
    super.dispose();
  }

  Future<void> _toggleTracking(bool value) async {
    final busRepository = context.read<BusRepository>();
    final auth = context.read<AuthController>();
    final user = auth.user;

    if (user == null) {
      logger.warning('Cannot toggle tracking: user not authenticated');
      return;
    }

    if (value) {
      if (_selectedBusId == null) {
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            'Please select a bus before starting location sharing.',
          );
        }
        return;
      }

      try {
        setState(() => _error = null);

        final granted = await _tracker.ensurePermissions();
        if (!granted) {
          if (!mounted) return;
          setState(() => _error = 'Location permission required');
          return;
        }

        await busRepository.setActiveDriver(
          busId: _selectedBusId!,
          driverId: user.uid,
        );

        await _tracker.startTracking(
          (position) async {
            try {
              await busRepository.updateBusLocation(
                busId: _selectedBusId!,
                driverId: user.uid,
                position: position,
              );
              if (mounted) {
                setState(() {
                  _lastPosition = position;
                  _error = null;
                });
              }
            } catch (error) {
              logger.error('Failed to update bus location', error);
              if (mounted) {
                setState(() => _error = 'Failed to update location');
              }
            }
          },
          onError: (error) {
            logger.error('Location tracking error', error);
            if (mounted) {
              setState(() => _error = 'Location tracking error');
            }
          },
        );

        if (!mounted) return;
        setState(() => _tracking = true);
        logger.info('Location tracking started for bus $_selectedBusId');
      } catch (error) {
        logger.error('Failed to start tracking', error);
        if (mounted) {
          ErrorHandler.showErrorSnackBar(context, error);
          setState(() => _error = 'Failed to start tracking');
        }
      }
    } else {
      try {
        await _tracker.stopTracking();
        if (_selectedBusId != null) {
          await busRepository.clearActiveDriver(_selectedBusId!);
        }
        if (!mounted) return;
        setState(() {
          _tracking = false;
          _lastPosition = null;
          _error = null;
        });
        logger.info('Location tracking stopped');
      } catch (error) {
        logger.error('Failed to stop tracking', error);
        if (mounted) {
          ErrorHandler.showErrorSnackBar(context, error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Console'),
        actions: [
          if (_tracking)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: StatusBadge(label: 'LIVE', isActive: true)),
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
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _error = null),
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Bus>>(
              stream: _busStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading buses...');
                }

                if (snapshot.hasError) {
                  return ErrorStateWidget(
                    message:
                        'Failed to load buses. Please check your connection.',
                    onRetry: () => setState(() {}),
                  );
                }

                final buses = snapshot.data ?? [];
                if (buses.isEmpty) {
                  return const EmptyStateWidget(
                    message:
                        'No buses configured yet.\nContact your administrator.',
                    icon: Icons.directions_bus_outlined,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Your Bus',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose the bus you are currently driving',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...buses.map((bus) {
                      final isSelected = bus.id == _selectedBusId;
                      final isActive = bus.isActive;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isSelected ? 4 : 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.directions_bus,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            bus.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Route: ${bus.routeNumber}'),
                              const SizedBox(height: 4),
                              StatusBadge(
                                label: isActive ? 'Active' : 'Inactive',
                                isActive: isActive,
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 32,
                                )
                              : const Icon(Icons.radio_button_unchecked),
                          onTap: _tracking
                              ? null
                              : () {
                                  setState(() => _selectedBusId = bus.id);
                                  logger.info('Selected bus: ${bus.id}');
                                },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    title: Text(
                      'Share Live Location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _tracking
                          ? 'Broadcasting your location to passengers'
                          : 'Location sharing is paused',
                    ),
                    value: _tracking,
                    onChanged: (_selectedBusId == null && !_tracking)
                        ? null
                        : _toggleTracking,
                  ),
                  if (_lastPosition != null) ...[
                    const Divider(height: 24),
                    _LocationInfo(position: _lastPosition!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationInfo extends StatelessWidget {
  const _LocationInfo({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm:ss');

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Location Details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                title: 'Latitude',
                value: position.latitude.toStringAsFixed(5),
                icon: Icons.location_on,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoCard(
                title: 'Longitude',
                value: position.longitude.toStringAsFixed(5),
                icon: Icons.location_on,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (position.speed > 0)
              Expanded(
                child: InfoCard(
                  title: 'Speed',
                  value: '${(position.speed * 3.6).toStringAsFixed(1)} km/h',
                  icon: Icons.speed,
                ),
              ),
            if (position.speed > 0) const SizedBox(width: 12),
            Expanded(
              child: InfoCard(
                title: 'Accuracy',
                value: '${position.accuracy.toStringAsFixed(1)}m',
                icon: Icons.my_location,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last update: ${formatter.format(DateTime.now())}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
