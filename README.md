# Kapaan - Emergency Response Management System

Kapaan is a comprehensive emergency response management system built with Flutter and Firebase. It facilitates coordination between police, ambulance services, and administrative authorities during emergency situations.

## Features

### Multi-User System
- **Admin Dashboard**: Manage users, monitor emergency responses, and oversee system operations
- **Police Dashboard**: Track and manage emergency situations, coordinate with ambulance services
- **Ambulance Dashboard**: Real-time navigation and emergency response coordination
- **User Authentication**: Secure login system with role-based access control

### Key Functionalities
- Real-time location tracking for emergency vehicles
- Emergency situation management and coordination
- User management and role-based access control
- Secure authentication system
- Cross-platform support (iOS, Android, Web)

## Technical Stack

- **Frontend**: Flutter
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
- **State Management**: Provider
- **Maps Integration**: Google Maps API

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
├── screens/                  # UI screens
│   ├── admin/               # Admin dashboard and related screens
│   ├── ambulance/           # Ambulance service screens
│   ├── auth/                # Authentication screens
│   └── police/              # Police dashboard and related screens
├── services/                # Business logic and API services
├── utils/                   # Utility functions and helpers
└── widgets/                 # Reusable UI components
```

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Firebase account
- Google Maps API key
- Android Studio / Xcode (for mobile development)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/max-mani/Kapaan.git
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a new Firebase project
   - Add your Android and iOS apps to the Firebase project
   - Download and add the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS

4. Configure Google Maps:
   - Get a Google Maps API key
   - Add the API key to the appropriate configuration files

5. Run the app:
   ```bash
   flutter run
   ```

## Usage

1. **Login**: Use the login screen to access the system with appropriate credentials
2. **Role Selection**: Choose your role (Admin/Police/Ambulance Service)
3. **Dashboard Access**: Access role-specific features and functionalities
4. **Emergency Management**: Coordinate and respond to emergency situations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Max Mani - [GitHub Profile](https://github.com/max-mani)

Project Link: [https://github.com/max-mani/Kapaan](https://github.com/max-mani/Kapaan)
