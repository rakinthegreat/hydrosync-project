# hydrosync 

hydrosync is a precision hydration tracking platform designed to optimize human performance through data-driven biological strategy. Unlike traditional trackers, hydrosync utilizes generative AI to calibrate hydration plans based on weight, lifestyle, weather conditions, and chronic health factors.

## Premium Features

- **Dual-Engine AI Architect**: Integrates **NVIDIA** and **Google Gemini** models to generate medically-aware 7-day hydration strategies.
- **Immersive Full-Screen Alarms**: High-priority, zero-friction notification system that commands attention during critical hydration windows.
- **Real-time Weather Sync**: Automatically adjusts hydration goals based on local temperature, humidity, and atmospheric trends.
- **Universal Cloud Sync**: Securely backs up settings and intake logs to the cloud via **Firebase & Google Sign-In**.
- **Home Screen Widget**: Real-time progress tracking directly from your Android home screen.
- **Dusty Ocean Aesthetic**: A stunning, premium UI featuring glassmorphism, soft gradients, and an adaptive light/dark theme.

## Technical Stack

- **Framework**: Flutter
- **Backend**: Firebase (Auth, Firestore)
- **AI**: NVIDIA API, Google Gemini API
- **State Management**: Provider
- **Local Storage**: SharedPreferences

## Getting Started

### Secure Configuration
hydrosync uses a decoupled secret management system. Create a `.env` file in the root directory:

```env
NVIDIA_API_KEY=your_nvidia_key
GEMINI_API_KEY=your_gemini_key
```

### Build & Run
Ensure you have the Flutter SDK installed, then run:

```bash
# Get dependencies
flutter pub get

# Run with environment variables
flutter run
```

## Privacy & Safety
hydrosync treats health data with clinical detachment. All biological markers (weight, sex, conditions) are used solely for the generation of your personalized hydration plan. The app includes specific overrides for kidney and heart conditions to ensure safe water intake limits.

---
**hydrosync** - *Precision Hydration. Redefined.*
