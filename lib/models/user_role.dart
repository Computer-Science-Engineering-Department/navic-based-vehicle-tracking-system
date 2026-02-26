enum UserRole { rider, driver, admin }

extension UserRoleExtension on UserRole {
  String get key => switch (this) {
    UserRole.driver => 'driver',
    UserRole.rider => 'rider',
    UserRole.admin => 'admin',
  };

  String get displayName => switch (this) {
    UserRole.driver => 'Bus Driver',
    UserRole.rider => 'Passenger',
    UserRole.admin => 'Admin',
  };
}

UserRole roleFromKey(String raw) {
  final normalized = raw.toLowerCase();
  if (normalized == 'driver') {
    return UserRole.driver;
  }
  if (normalized == 'admin') {
    return UserRole.admin;
  }
  return UserRole.rider;
}
