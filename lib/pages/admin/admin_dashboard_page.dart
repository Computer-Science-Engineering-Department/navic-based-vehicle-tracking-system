import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_handler.dart';
import '../../widgets/common_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final Stream<List<Bus>> _busStream;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _routeController = TextEditingController();
  final _capacityController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
    logger.info('Admin dashboard initialized');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _routeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _createBus() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final repo = context.read<BusRepository>();
    final name = _nameController.text.trim();
    final route = _routeController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim());

    try {
      await repo.createBus(
        name: name,
        routeNumber: route,
        capacity: capacity,
      );
      
      if (!mounted) return;
      
      _nameController.clear();
      _routeController.clear();
      _capacityController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Bus "$name" added successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      logger.info('Bus created: $name');
    } catch (error) {
      logger.error('Failed to create bus', error);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _BusList(stream: _busStream),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _NewBusForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      routeController: _routeController,
                      capacityController: _capacityController,
                      submitting: _submitting,
                      onSubmit: _createBus,
                    ),
                  ),
                ),
              ],
            );
          }
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BusList(stream: _busStream),
              const SizedBox(height: 16),
              _NewBusForm(
                formKey: _formKey,
                nameController: _nameController,
                routeController: _routeController,
                capacityController: _capacityController,
                submitting: _submitting,
                onSubmit: _createBus,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BusList extends StatelessWidget {
  const _BusList({required this.stream});

  final Stream<List<Bus>> stream;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                ),
                const SizedBox(width: 12),
                Text(
                  'Fleet Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor all registered buses and their status',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const Divider(height: 32),
            StreamBuilder<List<Bus>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: LoadingIndicator(message: 'Loading fleet...'),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 200,
                    child: ErrorStateWidget(
                      message: 'Failed to load buses',
                      onRetry: () {},
                    ),
                  );
                }

                final buses = snapshot.data ?? [];
                
                if (buses.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: EmptyStateWidget(
                      message: 'No buses registered yet.\nUse the form to add your first bus.',
                      icon: Icons.directions_bus_outlined,
                    ),
                  );
                }

                final activeBuses = buses.where((b) => b.isActive).length;
                final totalBuses = buses.length;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InfoCard(
                            title: 'Total Buses',
                            value: totalBuses.toString(),
                            icon: Icons.directions_bus,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InfoCard(
                            title: 'Active Now',
                            value: activeBuses.toString(),
                            icon: Icons.online_prediction,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: buses.length,
                      itemBuilder: (context, index) {
                        final bus = buses[index];
                        return _BusListTile(bus: bus);
                      },
                      separatorBuilder: (_, __) => const Divider(height: 24),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BusListTile extends StatelessWidget {
  const _BusListTile({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: bus.isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceVariant,
        child: Text(
          _initialsFor(bus.routeNumber),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: bus.isActive ? Colors.green : null,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              bus.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          StatusBadge(
            label: bus.isActive ? 'LIVE' : 'Offline',
            isActive: bus.isActive,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Route: ${bus.routeNumber}'),
          if (bus.location != null) ...[
            const SizedBox(height: 2),
            Text(
              'Updated: ${formatter.format(bus.location!.timestamp)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (bus.capacity != null)
            Text(
              '${bus.capacity} seats',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            '${bus.driverIds.length} drivers',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(String value) {
  final trimmed = value.trim().toUpperCase();
  if (trimmed.isEmpty) return '?';
  final length = math.min(2, trimmed.length);
  return trimmed.substring(0, length);
}

class _NewBusForm extends StatelessWidget {
  const _NewBusForm({
    required this.formKey,
    required this.nameController,
    required this.routeController,
    required this.capacityController,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController routeController;
  final TextEditingController capacityController;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Register New Bus',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Add a new bus to your fleet for drivers to track',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const Divider(height: 32),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Bus Name',
                  hintText: 'e.g. Campus Express',
                  prefixIcon: Icon(Icons.directions_bus),
                ),
                enabled: !submitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bus name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: routeController,
                decoration: const InputDecoration(
                  labelText: 'Route Number',
                  hintText: 'e.g. R12 or A1',
                  prefixIcon: Icon(Icons.route),
                ),
                enabled: !submitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Route number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: capacityController,
                decoration: const InputDecoration(
                  labelText: 'Seating Capacity (Optional)',
                  hintText: 'e.g. 50',
                  prefixIcon: Icon(Icons.event_seat),
                ),
                keyboardType: TextInputType.number,
                enabled: !submitting,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final num = int.tryParse(value);
                    if (num == null || num <= 0) {
                      return 'Enter a valid capacity';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(submitting ? 'Adding...' : 'Add Bus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}