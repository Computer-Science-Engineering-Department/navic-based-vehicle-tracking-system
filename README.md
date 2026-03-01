# NAVIC-Based Vehicle Tracking System

A production-ready, real-time vehicle tracking application built with Flutter and Firebase. Track buses, share live locations, and monitor your fleet with a beautiful, modern UI.

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.11.0 or higher)
- Firebase account with a configured project
- Android Studio / Xcode for mobile development

### Installation

1. **Clone and setup**

```bash
git clone <your-repo>
cd navic_based_vehicle_tracking_system
flutter pub get
```

2. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication (Email/Password)
   - Enable Realtime Database
   - Download and add configuration files:
     - `android/app/google-services.json`
     - `ios/Runner/GoogleService-Info.plist`

3. **Deploy Security Rules**

```bash
firebase deploy --only database
```

4. **Run the app**

```bash
flutter run
```

## ✨ Features

### 🎯 For Passengers

- **Real-time Tracking**: Watch buses move on an interactive map
- **Live Status**: See if buses are active or offline
- **Location Details**: View speed, address, and update times
- **Beautiful UI**: Modern Material Design 3 interface

### 🚌 For Drivers

- **Location Sharing**: Share your position with one tap
- **Bus Selection**: Choose from your assigned vehicles
- **Live Stats**: See speed, accuracy, and coordinates
- **Battery Efficient**: Smart location updates every 25 meters

### 🛠️ For Admins

- **Fleet Management**: Register and monitor all buses
- **Real-time Dashboard**: See active buses at a glance
- **Driver Assignment**: Manage bus-driver relationships
- **Capacity Planning**: Track seating capacity

## 🏗️ Architecture

### Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Authentication + Realtime Database)
- **Maps**: OpenStreetMap with flutter_map
- **State Management**: Provider
- **Logging**: Logger package

### Project Structure

```
lib/
├── main.dart                    # App entry with error boundaries
├── controllers/                 # Business logic
├── models/                      # Data models
├── services/                    # API & location services
├── pages/                       # UI screens
├── utils/                       # Helpers (logger, theme, errors)
└── widgets/                     # Reusable components
```

## 🔐 Security

The app implements:

- ✅ Role-based access control (Admin, Driver, Passenger)
- ✅ Firebase security rules (see `database.rules.json`)
- ✅ Input validation and sanitization
- ✅ Secure authentication flow

## 📱 Screenshots

### Authentication

Beautiful tabbed interface for passengers, drivers, and admins with role-specific messaging.

### Driver Dashboard

Real-time location sharing with live status indicators and location statistics.

### Passenger Map

Interactive map with custom bus markers, pull-to-refresh, and address resolution.

### Admin Console

Fleet overview with statistics, bus registration, and real-time monitoring.

## 🧪 Testing

Create test accounts for each role:

```bash
# Passenger
Email: passenger@test.com
Password: test123

# Driver
Email: driver@test.com
Password: test123

# Admin
Email: admin@test.com
Password: test123
```

## 📦 Dependencies

Key packages:

- `firebase_core` & `firebase_auth` - Backend services
- `firebase_database` - Real-time data
- `geolocator` - Location tracking
- `flutter_map` - Map rendering
- `provider` - State management
- `logger` - Production logging

See `pubspec.yaml` for the full list.

## 🚀 Deployment

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## 📚 Documentation

For detailed information, see:

- [PRODUCTION_READY.md](PRODUCTION_READY.md) - Complete feature list and improvements
- [database.rules.json](database.rules.json) - Firebase security rules

## 🐛 Troubleshooting

### Common Issues

**Location not updating?**

- Check permission settings
- Verify GPS is enabled
- Ensure app has background location access

**Can't sign in?**

- Verify Firebase Authentication is enabled
- Check email/password in Firebase Console
- Review error messages in logs

**Map not loading?**

- Check internet connection
- Verify OpenStreetMap tiles are accessible
- Clear app cache

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- Push notifications for bus arrivals
- Route planning and visualization
- Historical trip data
- Offline mode support
- Multi-language support
- Automated testing

## 📄 License

This project is open source and available for educational and commercial use.

## 🙏 Acknowledgments

Built with:

- Flutter & Firebase
- OpenStreetMap
- Material Design 3
- And the amazing Flutter community!

---

**Note**: This is a production-ready template with comprehensive error handling, logging, and modern UI. See [PRODUCTION_READY.md](PRODUCTION_READY.md) for the full list of enhancements.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# navic-based-vehicle-tracking-system
