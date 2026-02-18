import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'models/user_role.dart';
import 'pages/auth/auth_page.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/driver/driver_dashboard_page.dart';
import 'pages/user/user_dashboard_page.dart';
import 'services/bus_repository.dart';
import 'utils/app_logger.dart';
import 'utils/app_theme.dart';
import 'widgets/common_widgets.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Setup global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.fatal('Flutter error', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.fatal('Platform error', error, stack);
    return true;
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('Firebase initialized successfully');
  } catch (error, stackTrace) {
    logger.fatal('Failed to initialize Firebase', error, stackTrace);
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        Provider(create: (_) => BusRepository()),
      ],
      child: MaterialApp(
        title: 'NAVIC Vehicle Tracking',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const _RootRouter(),
        builder: (context, child) {
          // Add error boundary wrapper
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return ErrorStateWidget(
              message: kDebugMode
                  ? details.exceptionAsString()
                  : 'Something went wrong',
            );
          };
          return child!;
        },
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        // Show loading screen while checking authentication state
        if (auth.isBusy && auth.user == null) {
          return const Scaffold(body: LoadingIndicator(message: 'Loading...'));
        }

        // Show error if authentication failed
        if (auth.error != null && auth.user == null) {
          return Scaffold(
            body: ErrorStateWidget(
              message: auth.error!.userFriendlyMessage,
              onRetry: () {
                // Restart the auth controller
                context.read<AuthController>();
              },
            ),
          );
        }

        // Not authenticated - show auth page
        if (auth.user == null) {
          return const AuthPage();
        }

        // Route based on user role
        final role = auth.role;
        if (role == UserRole.driver) {
          return const DriverDashboardPage();
        }
        if (role == UserRole.rider) {
          return const UserDashboardPage();
        }
        if (role == UserRole.admin) {
          return const AdminDashboardPage();
        }

        // Fallback to auth page if role is not set
        return const AuthPage();
      },
    );
  }
}
