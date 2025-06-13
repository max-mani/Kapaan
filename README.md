# Kapaan

A Flutter application with Firebase integration.

## Setup Instructions

1. Configure Firebase:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download and add the configuration files:
     - For Android: Place `google-services.json` in `android/app/`
     - For iOS: Place `GoogleService-Info.plist` in `ios/Runner/`

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

- `lib/screens/` - UI screens (login, home, etc.)
- `lib/services/` - Firebase services (auth, Firestore, storage)
- `lib/widgets/` - Reusable UI components
- `lib/models/` - Data models
- `lib/utils/` - Utility functions and helpers

## Features

- Material 3 design system
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Loading indicators and snackbar utilities
- Named routing
