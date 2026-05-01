# Smart Shopper - Frontend Setup Guide 🚀

This guide provides instructions on how to set up and run the "Smart Shopper" application, developed using the Flutter framework.

---

## ⚙️ Getting Started

### 1. Prerequisites
* **Flutter SDK:** version 3.x or higher.
* **Dart SDK:** version 3.x or higher.
* **IDE:** VS Code or Android Studio.
* **Devices:** Android Emulator, iOS Simulator, or a physical device.

### 2. Installation
Open your terminal in the project directory and run the following command to install dependencies:
```bash
cd smart_shopper_frontend
flutter pub get
```

### 3. Running the App
To launch the application on your connected device or emulator:
```bash
flutter run
```

---

## 🌐 Base URL Configuration

To connect the frontend to the backend, you must configure the base URL in the following file:
`lib/services/api_service.dart`

Update the value based on your testing environment:

| Environment | Base URL Value | Notes |
| :--- | :--- | :--- |
| **Android Emulator** | `[http://10.0.2.2:8000](http://10.0.2.2:8000)` | Default for Android emulators |
| **iOS Simulator** | `http://localhost:8000` | For macOS simulators |
| **Physical Device** | `[http://192.168.](http://192.168.)x.x:8000` | Use your computer's local IP address |

---

## 📁 Project Structure

The following list describes the organization of files and folders inside the `lib` directory:

```text
lib/
├── main.dart                 # Entry point + Splash screen management
├── app_state.dart            # State management (Theme, Language)
├── theme.dart                # Visual styles and color schemes
├── l10n.dart                 # Localization files (AR, EN, etc.)
├── data/
│   └── regions.dart          # Supported countries and currencies data
├── services/
│   └── api_service.dart      # API communication logic (Backend integration)
├── widgets/
│   └── error_handler.dart    # Reusable UI for SnackBars and alerts
└── screens/                  # Main application screens
    ├── onboarding_screen.dart # Welcome and intro tour
    ├── login_screen.dart      # User login
    ├── register_screen.dart   # Account registration
    ├── otp_screen.dart        # OTP verification
    ├── home_screen.dart       # Dashboard and bottom navigation
    ├── search_screen.dart     # Image processing and product analysis
    ├── history_screen.dart    # User's previous search history
    ├── product_detail_screen.dart # Product details and price comparisons
    ├── admin_screen.dart      # Admin control panel
    ├── user_detail_screen.dart # User management screen for admins
    └── settings_screen.dart   # Profile and app settings
```

---

## 🔧 Troubleshooting

### ❌ Error: `No pubspec.yaml file found`
* **Fix:** Ensure your terminal's current working directory is `smart_shopper_frontend` before running Flutter commands.

### ❌ Connection Failure (Backend)
* Ensure the Backend server is running on port **8000**.
* Verify the `baseUrl` in `api_service.dart`.
* If using a physical device, both the phone and the computer must be on the same Wi-Fi network.

### ❌ Camera or Gallery Access Issues
* The app includes the necessary permissions in `AndroidManifest.xml` and `Info.plist`. Ensure you grant permission when prompted by the OS.