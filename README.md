# Flutter Firebase WebRTC Video Call App

## Overview
This project is a Flutter-based video and audio call application that allows users to authenticate, view a list of other users, and initiate one-on-one audio or video calls. The app leverages **Firebase** for user authentication and signaling, and **WebRTC** for real-time peer-to-peer communication. The app is designed to provide a seamless calling experience with features like online status tracking, incoming call dialogs, and call management.

## Features
- **User Authentication**: Secure login and registration using Firebase Authentication (email/password).
- **User List**: Displays all registered users with their online/offline status and last seen timestamp.
- **Audio/Video Calls**: Each user in the list has buttons to initiate audio or video calls.
- **Real-Time Communication**: Uses WebRTC for high-quality, low-latency audio and video streaming.
- **Signaling**: Firebase Firestore handles signaling (exchange of SDP offers/answers and ICE candidates).
- **Incoming Call Notifications**: Displays a dialog with a timer for incoming calls, allowing users to accept or reject.
- **Call Controls**: Mute microphone, toggle video, and end call during active sessions.
- **Responsive UI**: Clean and intuitive interface built with Flutter's Material Design.

## Technologies Used
- **Flutter**: Cross-platform framework for building the mobile app (supports iOS, Android, and web).
- **Firebase Authentication**: Manages user login and registration.
- **Firebase Firestore**: Stores user data, call metadata, and handles WebRTC signaling.
- **flutter_webrtc**: Flutter package for WebRTC to enable real-time audio and video communication.
- **Dart**: Programming language used for Flutter development.

## Prerequisites
To run this project, ensure you have the following installed:
- **Flutter**: Version 3.0.0 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install)).
- **Dart**: Included with Flutter.
- **Firebase Project**: Set up a Firebase project with Authentication and Firestore enabled.
- **Node.js**: For local testing of WebRTC signaling (optional, if using a custom TURN server).
- **IDE**: Android Studio, VS Code, or any IDE with Flutter support.
- **Physical Device/Emulator**: For testing (iOS or Android).

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd flutter-firebase-webrtc
and navigate to branch earbajv1 here you get the lattest code 
```

### 2. Install Dependencies
Run the following command to install required packages:
```bash
flutter pub get
```

Required dependencies in `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  flutter_webrtc: ^0.10.0
```

### 3. Configure Firebase
1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password** authentication in the Authentication section.
3. Enable **Firestore** database and set up rules (example below).
4. Download the `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) and place them in the appropriate directories:
    - Android: `android/app/`
    - iOS: `ios/Runner/`
5. Add Firebase configuration to your Flutter app:
    - Update `main.dart` with Firebase initialization:
      ```dart
      import 'package:firebase_core/firebase_core.dart';
      import 'firebase_options.dart';
 
      void main() async {
        WidgetsFlutterBinding.ensureInitialized();
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        runApp(const MyApp());
      }
      ```

### 4. Firestore Database Structure
The app uses Firestore for user data and call signaling. Suggested structure:
- **users** collection:
    - Document ID: User UID
    - Fields: `name` (string), `email` (string), `isOnline` (boolean), `lastSeen` (timestamp)
- **calls** collection:
    - Document ID: Receiver's UID
    - Fields: `callerId`, `callerName`, `callType` (video/audio), `roomId`, `status` (ringing/accepted/rejected), `createdAt`, `acceptedAt`, `rejectedAt`
- **rooms** collection:
    - Document ID: Room ID
    - Fields: `callerId`, `callerName`, `receiverId`, `receiverName`, `callType`, `status`, `createdAt`, `offer`, `answer`
    - Subcollections: `offerCandidates`, `answerCandidates` (for ICE candidates)

**Firestore Security Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /calls/{callId} {
      allow read, write: if request.auth != null;
    }
    match /rooms/{roomId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 5. WebRTC Setup
- The app uses a STUN server (`stun:stun.l.google.com:19302`) for NAT traversal. For production, consider adding a TURN server (e.g., [openrelay.metered.ca](https://openrelay.metered.ca/)) for better connectivity.
- Update the `_configuration` map in `VideoCallScreen` if using a custom TURN server:
  ```dart
  final Map<String, dynamic> _configuration = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "turn:your-turn-server", "username": "user", "credential": "pass"}
    ]
  };
  ```

### 6. Run the App
```bash
flutter run
```
- Ensure a device/emulator is connected.
- Log in or register using an email and password.
- The homepage (`UsersListScreen`) will display all users with audio/video call buttons.

## Project Structure
```
lib/
├── main.dart               # App entry point and routing
├── users_list_screen.dart  # Homepage with user list and call buttons
├── video_call_screen.dart  # WebRTC call screen with video renderers
├── incoming_call_dialog.dart # Dialog for incoming calls
firebase_options.dart       # Firebase configuration (auto-generated)
```

## Usage
1. **Authentication**: Users sign in or register via Firebase Authentication.
2. **Homepage**: Shows a list of all users (except the current user) with their online status and email.
3. **Initiating a Call**:
    - Click the audio (`Icons.call`) or video (`Icons.videocam`) button next to a user.
    - This creates a room in Firestore and sends a call notification to the receiver.
4. **Receiving a Call**:
    - An incoming call dialog appears with the caller's name and a 30-second timer.
    - Accept or reject the call using the respective buttons.
5. **During a Call**:
    - View local and remote video streams (video calls only).
    - Use controls to mute the microphone, toggle video, or end the call.
6. **Logout**: Use the logout button in the app bar to sign out and set offline status.

## Limitations
- **Peer-to-Peer Only**: Currently supports 1-on-1 calls. For group calls (10-50 users), switch to an SFU (e.g., Mediasoup) or MCU architecture.
- **Network Dependence**: WebRTC requires good network conditions. TURN servers are recommended for NAT traversal.
- **Scalability**: Firebase Firestore is sufficient for signaling, but media streaming for large groups needs a media server.

## Extending to Group Calls
To support group calls (10-50 users):
1. Use a **Selective Forwarding Unit (SFU)** like Mediasoup or Jitsi Videobridge.
2. Modify `UsersListScreen` to allow selecting multiple users for a group call.
3. Update `VideoCallScreen` to handle multiple `RTCPeerConnection`s or connect to an SFU.
4. Store participant lists in the `rooms` collection.
5. Use a backend server (Node.js + Mediasoup) for media routing.

**Resources for Group Calls**:
- [Mediasoup Documentation](https://mediasoup.org/documentation/)
- [WebRTC for the Curious](https://webrtcforthecurious.com/)
- [Flutter WebRTC Group Call Tutorial](https://medium.com/search?q=flutter+webrtc+group+call)

## Troubleshooting
- **No Video/Audio**: Check camera/mic permissions and ensure `flutter_webrtc` is compatible with your platform.
- **Connection Issues**: Verify STUN/TURN server settings and network connectivity.
- **Firestore Errors**: Ensure security rules allow read/write and Firebase is initialized correctly.
- **Debugging WebRTC**: Use `chrome://webrtc-internals/` in Chrome to inspect connections.

## Contributing
Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m 'Add your feature'`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## License
This project is licensed under the MIT License.

## Acknowledgments
- Flutter community for robust packages like `flutter_webrtc`.
- Firebase for seamless auth and database integration.
- WebRTC community for open-source real-time communication tools.