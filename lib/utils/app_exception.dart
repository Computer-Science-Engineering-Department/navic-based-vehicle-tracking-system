/// Base class for all app-specific exceptions
abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() => message;

  String get userFriendlyMessage => message;
}

/// Network related errors
class NetworkException extends AppException {
  const NetworkException([
    String message = 'Network error occurred. Please check your connection.',
    String? code,
    dynamic details,
  ]) : super(message, code: code, details: details);
}

/// Authentication and authorization errors
class AuthException extends AppException {
  const AuthException([
    String message = 'Authentication failed.',
    String? code,
    dynamic details,
  ]) : super(message, code: code, details: details);

  @override
  String get userFriendlyMessage {
    if (code == 'user-not-found') {
      return 'No account found with this email.';
    }
    if (code == 'wrong-password') {
      return 'Incorrect password. Please try again.';
    }
    if (code == 'email-already-in-use') {
      return 'An account with this email already exists.';
    }
    if (code == 'invalid-email') {
      return 'Please enter a valid email address.';
    }
    if (code == 'weak-password') {
      return 'Password is too weak. Please use a stronger password.';
    }
    if (code == 'user-disabled') {
      return 'This account has been disabled.';
    }
    if (code == 'too-many-requests') {
      return 'Too many failed attempts. Please try again later.';
    }
    return message;
  }
}

/// Permission related errors
class PermissionException extends AppException {
  const PermissionException([
    String message = 'Required permission was denied.',
    String? code,
    dynamic details,
  ]) : super(message, code: code, details: details);

  @override
  String get userFriendlyMessage {
    if (code == 'location-denied') {
      return 'Location permission is required to track your bus.';
    }
    if (code == 'location-denied-forever') {
      return 'Location permission was permanently denied. Please enable it in settings.';
    }
    if (code == 'location-service-disabled') {
      return 'Location services are disabled. Please enable them in settings.';
    }
    return message;
  }
}

/// Data/database related errors
class DataException extends AppException {
  const DataException([
    String message = 'Failed to access data.',
    String? code,
    dynamic details,
  ]) : super(message, code: code, details: details);

  @override
  String get userFriendlyMessage {
    if (code == 'not-found') {
      return 'The requested data was not found.';
    }
    if (code == 'permission-denied') {
      return 'You do not have permission to access this data.';
    }
    if (code == 'unavailable') {
      return 'Service is temporarily unavailable. Please try again.';
    }
    return 'Failed to load data. Please check your connection.';
  }
}

/// Validation errors
class ValidationException extends AppException {
  const ValidationException([
    String message = 'Validation failed.',
    String? code,
    dynamic details,
  ]) : super(message, code: code, details: details);
}

/// Unexpected/unknown errors
class UnknownException extends AppException {
  const UnknownException([
    String message = 'An unexpected error occurred.',
    dynamic details,
  ]) : super(message, details: details);

  @override
  String get userFriendlyMessage =>
      'Something went wrong. Please try again later.';
}
