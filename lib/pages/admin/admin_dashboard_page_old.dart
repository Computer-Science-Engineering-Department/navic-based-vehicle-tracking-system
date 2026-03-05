import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/bus.dart';
import '../../services/bus_repository.dart';

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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _busStream = context.read<BusRepository>().watchBuses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _routeController.dispose();
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

    try {
      await repo.createBus(name: name, routeNumber: route);
      if (!mounted) {
        return;
      }
      _nameController.clear();
      _routeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bus "$name" added successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add bus: $error')));
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
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final content = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _BusList(stream: _busStream),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          top: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: _NewBusForm(
                          formKey: _formKey,
                          nameController: _nameController,
                          routeController: _routeController,
                          submitting: _submitting,
                          onSubmit: _createBus,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BusList(stream: _busStream),
                    const SizedBox(height: 16),
                    _NewBusForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      routeController: _routeController,
                      submitting: _submitting,
                      onSubmit: _createBus,
                    ),
                  ],
                );

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withValues(alpha: 0.2),
            ),
            child: content,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configured buses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Bus>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final buses = snapshot.data ?? [];
                if (buses.isEmpty) {
                  return const SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No buses configured yet.\nUse the form to add one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: buses.length,
                  itemBuilder: (context, index) {
                    final bus = buses[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          _initialsFor(bus.routeNumber),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        ),
                      ),
                      title: Text(bus.name),
                      subtitle: Text(
                        bus.routeNumber.isEmpty
                            ? 'Route not set'
                            : 'Route ${bus.routeNumber}',
                      ),
                      trailing: Text(
                        bus.driverIds.isEmpty
                            ? 'No drivers'
                            : '${bus.driverIds.length} drivers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _initialsFor(String value) {
  final trimmed = value.trim().toUpperCase();
  if (trimmed.isEmpty) {
    return '?';
  }
  final length = math.min(2, trimmed.length);
  return trimmed.substring(0, length);
}

class _NewBusForm extends StatelessWidget {
  const _NewBusForm({
    required this.formKey,
    required this.nameController,
    required this.routeController,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController routeController;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add new bus',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Register buses so drivers can start sharing live locations.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Bus name',
                  hintText: 'e.g. Campus Express',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: routeController,
                decoration: const InputDecoration(
                  labelText: 'Route number or label',
                  hintText: 'e.g. R12',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Route is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(submitting ? 'Saving...' : 'Save bus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
