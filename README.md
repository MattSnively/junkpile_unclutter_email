# Junkpile - Unclutter Your Email

[![iOS Build](https://github.com/MattSnively/junkpile_unclutter_email/actions/workflows/ios-build.yml/badge.svg)](https://github.com/MattSnively/junkpile_unclutter_email/actions/workflows/ios-build.yml)
[![Backend Test](https://github.com/MattSnively/junkpile_unclutter_email/actions/workflows/backend-test.yml/badge.svg)](https://github.com/MattSnively/junkpile_unclutter_email/actions/workflows/backend-test.yml)

A fun, swipe-based email unsubscribe app with gamification. Like "Hot or Not" but for your inbox!

## Features

- Swipe left to unsubscribe from emails
- Swipe right to keep subscriptions
- Clean, intuitive interface
- Track your unsubscribe progress
- Keyboard support (arrow keys)

## Installation

1. Install dependencies:
```bash
npm install
```

2. Start the server:
```bash
npm start
```

3. Open your browser to:
```
http://localhost:3000
```

## Development

Run with auto-reload:
```bash
npm run dev
```

## How It Works

1. Click "Connect Email" to load subscription emails
2. Swipe left (or press left arrow) to unsubscribe
3. Swipe right (or press right arrow) to keep the subscription
4. View your stats and progress as you go

## Future Enhancements

- Real email integration (Gmail, Outlook, etc.)
- Actual unsubscribe functionality via email APIs
- User authentication
- Email filtering and categorization
- Analytics dashboard

## Tech Stack

### Web
- Frontend: HTML, CSS, JavaScript
- Backend: Node.js, Express
- Data Storage: JSON files (ready to upgrade to database)

### iOS App (New!)
- Framework: SwiftUI
- Architecture: MVVM
- Persistence: SwiftData (iOS 17+)
- Auth: ASWebAuthenticationSession for Google OAuth

See [ios/README.md](ios/README.md) for iOS-specific setup instructions.

## iOS App Features

The native iOS app includes full gamification:

- **Points & XP**: Earn 10 pts / 15 XP per unsubscribe, 5 pts / 10 XP per keep
- **20 Levels**: Progress through levels with increasing XP thresholds
- **21 Achievements**: Unlock badges for milestones, streaks, and special actions
- **Daily Streaks**: Build consecutive day streaks for bonus rewards
- **Statistics Dashboard**: Track your progress with charts and history

## CI/CD

This project uses GitHub Actions for continuous integration:

### Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `ios-build.yml` | Push to `ios/**` | Builds iOS app, runs tests, creates archive |
| `backend-test.yml` | Push to `server/**` | Tests Node.js backend |

### Running CI Locally

To test the iOS build locally (requires macOS):
```bash
cd ios/Junkpile
xcodebuild build -scheme Junkpile -destination "platform=iOS Simulator,name=iPhone 15"
```

### Setup

1. Push your code to GitHub
2. Workflows run automatically on push/PR to `main` or `develop`
3. Update the badge URLs in this README with your GitHub username

## Project Structure

```
junkpile_unclutter_email/
├── server/              # Node.js backend
│   ├── server.js        # Express server with API endpoints
│   └── gmailService.js  # Gmail API integration
├── public/              # Web frontend
│   ├── index.html
│   ├── css/
│   └── js/
├── ios/                 # iOS app (SwiftUI)
│   └── Junkpile/
│       ├── Models/
│       ├── Views/
│       ├── ViewModels/
│       ├── Services/
│       └── Persistence/
├── data/                # Local data storage
└── .github/workflows/   # CI/CD pipelines
```
