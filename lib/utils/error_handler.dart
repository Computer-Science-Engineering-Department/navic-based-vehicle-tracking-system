import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_exception.dart';
import 'app_logger.dart';

/// Global error handler for converting platform exceptions to app exceptions
class ErrorHandler {
  static AppException handleError(dynamic error, [StackTrace? stackTrace]) {
    // Log the error
    logger.error('Error occurred', error, stackTrace);

    // Convert to appropriate AppException
    if (error is AppException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return AuthException(
        error.message ?? 'Authentication failed',
        error.code,
        error,
      );
    }

    if (error is FirebaseException) {
      return DataException(
        error.message ?? 'Database error occurred',
        error.code,
        error,
      );
    }

    return UnknownException(error.toString(), error);
  }

  /// Show error in a SnackBar
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final appException = handleError(error);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(appException.userFriendlyMessage),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error in a dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) async {
    final appException = handleError(error);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(appException.userFriendlyMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
