import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_role.dart';
import '../../utils/error_handler.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'NAVIC Tracking',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          ),
                          labelColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          unselectedLabelColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.person),
                              text: 'Passenger',
                            ),
                            Tab(
                              icon: Icon(Icons.directions_bus),
                              text: 'Driver',
                            ),
                            Tab(
                              icon: Icon(Icons.admin_panel_settings),
                              text: 'Admin',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        children: [
                          _AuthForm(
                            role: UserRole.rider,
                            isBusy: controller.isBusy,
                          ),
                          _AuthForm(
                            role: UserRole.driver,
                            isBusy: controller.isBusy,
                          ),
                          _AuthForm(
                            role: UserRole.admin,
                            isBusy: controller.isBusy,
                            allowRegister: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthForm extends StatefulWidget {
  const _AuthForm({
    required this.role,
    required this.isBusy,
    this.allowRegister = true,
  });

  final UserRole role;
  final bool isBusy;
  final bool allowRegister;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthController>();
    await auth.signInOrRegister(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: widget.role,
      isRegistering: widget.allowRegister && _isRegistering,
    );
    
    if (auth.error != null && mounted) {
      ErrorHandler.showErrorSnackBar(context, auth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headline = switch (widget.role) {
      UserRole.driver => 'Driver Portal',
      UserRole.admin => 'Admin Console',
      UserRole.rider => 'Passenger Portal',
    };
    
    final helperText = switch (widget.role) {
      UserRole.driver =>
        'Track and share your bus location in real-time with passengers.',
      UserRole.admin => 'Manage fleet, routes, and monitor all bus operations.',
      UserRole.rider => 'Find and track your bus in real-time on the map.',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForRole(widget.role),
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined),
                helperText: ' ',
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !widget.isBusy,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                helperText: _isRegistering ? 'At least 6 characters' : ' ',
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !widget.isBusy,
              onFieldSubmitted: (_) => _handleSubmit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (_isRegistering && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.isBusy ? null : _handleSubmit,
                icon: widget.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isRegistering ? Icons.person_add : Icons.login),
                label: Text(
                  _isRegistering ? 'Create Account' : 'Sign In',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (widget.allowRegister) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.isBusy
                    ? null
                    : () => setState(() => _isRegistering = !_isRegistering),
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Sign in'
                      : 'Need an account? Register',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForRole(UserRole role) {
    return switch (role) {
      UserRole.rider => Icons.location_on,
      UserRole.driver => Icons.drive_eta,
      UserRole.admin => Icons.dashboard,
    };
  }
}