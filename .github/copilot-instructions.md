# SOI App Copilot Instructions

## Project Overview
SOI is a sophisticated social media Flutter app focused on photo sharing with voice memos. Built with Flutter for multi-platform deployment (iOS, Android, Web, macOS, Linux, Windows), using Firebase backend and custom native camera implementations.

## Architecture & Patterns

### Core Architecture
- **Pattern**: MVC + Provider state management 
- **Structure**: `lib/{controllers,models,services,repositories,views,widgets}`
- **State Management**: Provider + ChangeNotifier pattern exclusively
- **Data Flow**: Views → Controllers → Services → Repositories → Firebase/Supabase

### Key Controllers (ChangeNotifier-based)
- `AuthController`: Phone-based authentication, user management
- `CategoryController`: Photo categories and group management  
- `AudioController`: Voice recording/playback with waveform visualization
- `CommentAudioController`: Voice comments system
- `PhotoController`: Image processing and Firebase Storage uploads
- `ContactController`: Device contacts integration for friend discovery

### Native Integration
- **iOS Camera**: Custom `SwiftCameraPlugin.swift` with AVFoundation integration
- **Audio Recording**: Native iOS/Android recorders via MethodChannel `com.soi.camera`
- **Platform Views**: Custom camera preview using FlutterPlatformView
- **Audio Session**: iOS audio session management for camera/recorder compatibility

## Firebase Configuration

### Authentication
- **Phone-based auth** with SMS verification
- **reCAPTCHA bypass** via APNs tokens on iOS
- **User lookup**: Find existing users by phone number for seamless login
- **Project ID**: `soi-sns` (configured in firebase.json)

### Firestore Schema
```
users/{userId} - user profiles with phone, name, profile_image
categories/{categoryId} - shared photo albums
  └─ photos/{photoId} - images with audioUrl for voice memos
    └─ comments/{userNickname} - voice comments per photo
```

### Security Rules
- Current: Development mode (authenticated users have full access)
- Production-ready rules defined but commented in `firestore.rules`

## Development Workflows

### Build Commands
```bash
# Development
flutter run --debug
flutter run --release

# Platform-specific
flutter run -d ios
flutter run -d android
flutter run -d chrome

# Native dependencies
cd ios && pod install
cd android && ./gradlew clean
```

### Key Development Files
- `pubspec.yaml`: Dependencies and version configuration
- `firebase.json`: Firebase project configuration with emulator settings
- `ios/Runner/AppDelegate.swift`: Firebase initialization and APNs setup
- `functions/index.js`: Cloud Functions for URL shortening and invite system

### Memory Optimization
- Image cache limits: 100 images/50MB (debug), 50 images/30MB (release)
- Automatic image compression before upload
- Controller disposal patterns in all screens

## Critical Integration Points

### Camera Service Architecture
- **Service**: `CameraService` abstracts platform-specific camera operations
- **Native iOS**: `SwiftCameraPlugin` handles session management, zoom, flash
- **Method Channels**: `com.soi.camera` for camera control
- **Audio Conflicts**: iOS audio session coordination between camera and recorder

### Audio System
- **Packages**: `audio_waveforms` for recording, `audioplayers` for playback
- **Waveform Display**: Real-time visualization during recording
- **File Format**: AAC with 44.1kHz sample rate
- **Storage**: Firebase Storage with automatic compression

### Friend System
- **Discovery**: Device contacts matching with phone numbers
- **Categories**: Multi-user shared photo albums
- **Invitations**: Deep linking system via Cloud Functions

## Common Patterns

### Provider Usage
```dart
// Always use Provider.of with listen: false in Controllers
final authController = Provider.of<AuthController>(context, listen: false);

// Use Consumer for UI updates
Consumer<CategoryController>(
  builder: (context, controller, child) => // UI
)
```

### Error Handling
- Try-catch blocks with user-friendly Fluttertoast messages
- Debug logging with descriptive prefixes (📱, 🎯, ❌)
- Graceful degradation for network/permission failures

### Memory Management
- Always override `dispose()` in StatefulWidgets
- Cancel timers, subscriptions, and audio players
- Use `mounted` checks before setState calls

## Platform-Specific Notes

### iOS Considerations
- **Minimum**: iOS 15.0
- **Camera**: Custom AVCaptureSession implementation
- **APNs**: Required for reCAPTCHA bypass in phone auth
- **Audio Sessions**: Careful coordination to avoid "Cannot Record" errors

### Android Considerations  
- **Permissions**: Dynamic runtime permissions for camera, microphone, contacts
- **CameraX**: Future migration planned from deprecated Camera API

### Web Considerations
- **reCAPTCHA**: Required for phone authentication
- **Limited Features**: No native camera, contacts access
- **Firebase Auth**: Web-specific configuration in `index.html`

## Testing & Debugging

### Debug Tools
- Firebase Emulator Suite configured (ports 4000, 8080, 9099, 9199)
- Flutter Inspector for widget debugging
- Native logging through platform channels

### Common Issues
- **Audio conflicts**: Check iOS audio session state in camera operations
- **Firebase connection**: Verify project ID and platform configuration
- **Memory leaks**: Monitor image cache usage via debug prints

## Dependencies Management
- **Firebase**: Latest stable versions across auth, firestore, storage
- **UI Packages**: flutter_screenutil for responsive design, google_fonts
- **Native Features**: permission_handler, flutter_contacts, image_picker
- **Audio/Video**: audio_waveforms, audioplayers, camera packages

When working on this codebase, prioritize the Provider pattern for state management, maintain the repository pattern for data access, and ensure proper disposal of resources to prevent memory leaks.