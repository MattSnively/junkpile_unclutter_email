# Junkpile iOS App

Native iOS app for email unsubscribe management with gamification features.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- macOS Ventura or later

## Project Structure

```
Junkpile/
├── JunkpileApp.swift          # Main app entry point
├── Models/                    # SwiftData and API models
│   ├── PlayerProfile.swift    # User gamification profile
│   ├── Session.swift          # Swipe session tracking
│   ├── Decision.swift         # Individual swipe decisions
│   ├── DailyActivity.swift    # Daily activity for streaks
│   ├── Achievement.swift      # Achievement definitions and unlocks
│   └── APIModels.swift        # Codable structs for API communication
├── Views/
│   ├── Onboarding/           # Welcome and Google Sign-In flows
│   ├── Home/                 # Dashboard with stats and quick actions
│   ├── Swipe/                # Card stack and swipe interface
│   ├── Gamification/         # Profile, achievements, streaks
│   ├── Statistics/           # Charts and session history
│   └── Settings/             # Account and preferences
├── ViewModels/               # MVVM view models
│   ├── AuthViewModel.swift
│   ├── SwipeViewModel.swift
│   ├── GamificationViewModel.swift
│   └── StatsViewModel.swift
├── Services/
│   ├── KeychainService.swift      # Secure token storage
│   ├── APIService.swift           # Backend communication
│   ├── GoogleAuthService.swift    # OAuth flow handling
│   └── GamificationService.swift  # Points, XP, achievements logic
├── Persistence/
│   └── PersistenceController.swift # SwiftData setup
└── Resources/
    ├── Assets.xcassets       # App icons and colors
    └── Info.plist            # App configuration
```

## Setup Instructions

### 1. Google OAuth Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Gmail API
4. Create OAuth 2.0 credentials (iOS application)
5. Add your bundle identifier: `com.junkpile.app`
6. Download the credentials

### 2. Update Configuration

1. Open `Services/GoogleAuthService.swift`
2. Replace `YOUR_GOOGLE_CLIENT_ID` with your actual client ID:
   ```swift
   private let clientId = "YOUR_CLIENT_ID.apps.googleusercontent.com"
   ```

3. Open `Resources/Info.plist`
4. Replace the URL scheme with your reversed client ID:
   ```xml
   <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
   ```

### 3. Backend Configuration

1. Ensure the Node.js backend is running (see main project README)
2. Update the API base URL in `Services/APIService.swift`:
   ```swift
   self.baseURL = "http://your-server-url:3000"
   ```
   For development, localhost should work if testing on simulator.

### 4. Build and Run

1. Open `Junkpile.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on simulator or device

## Features

### Core Functionality
- Gmail OAuth integration via ASWebAuthenticationSession
- Swipe-based email unsubscribe interface
- Secure token storage in iOS Keychain

### Gamification System
- **Points**: 10 pts for unsubscribe, 5 pts for keep
- **XP**: 15 XP for unsubscribe, 10 XP for keep
- **Levels**: 20 levels with increasing XP thresholds
- **Achievements**: 21 achievements across 5 categories
- **Streaks**: Daily activity tracking with streak bonuses

### Statistics
- Weekly activity charts (Swift Charts)
- Unsubscribe/keep ratio visualization
- Session history
- Lifetime statistics

## Architecture

- **SwiftUI**: Declarative UI framework
- **MVVM**: Model-View-ViewModel pattern
- **SwiftData**: Persistence (iOS 17+)
- **Combine**: Reactive programming for state management

## Backend API Endpoints

The app communicates with these endpoints:

### Authentication
- `POST /api/auth/mobile` - Exchange OAuth code for tokens
- `POST /api/auth/refresh` - Refresh expired access token
- `GET /api/auth/validate` - Validate current token

### Email Operations
- `GET /api/emails` - Fetch emails with unsubscribe options
- `POST /api/decision` - Record swipe decision

### Statistics
- `GET /api/stats` - Get aggregated statistics

## Testing

### Running Tests
```bash
xcodebuild test -scheme Junkpile -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manual Testing Checklist
1. **Auth**: Sign in with Gmail, verify token stored in Keychain
2. **Emails**: Fetch emails, verify card display
3. **Swipe**: Test left/right swipe, verify decisions logged
4. **Gamification**: Make decisions, verify points/XP awarded
5. **Persistence**: Close app, reopen, verify stats persist
6. **Streak**: Use app on consecutive days, verify streak increments

## License

Copyright (c) 2026 Junkpile. All rights reserved.
