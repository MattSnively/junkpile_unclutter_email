# Privacy Policy for Junkpile

**Last Updated: February 13, 2026**

## Introduction

Junkpile ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use the Junkpile mobile application (the "App").

**Our Core Privacy Commitment: We do not read, store, analyze, or sell your email data. Period.**

## Information We Do NOT Collect

We want to be explicit about what we do NOT do with your data:

- **We DO NOT read the content of your emails**
- **We DO NOT store your email messages**
- **We DO NOT analyze your email content for advertising or profiling**
- **We DO NOT sell your data to third parties**
- **We DO NOT share your email data with anyone**
- **We DO NOT use your email data for machine learning or AI training**
- **We DO NOT track your email reading habits**

## Information We Access (But Do Not Store)

To provide the core functionality of Junkpile, we temporarily access:

### Email Metadata (Transient Access Only)
- **Sender addresses** - To display who sent the email
- **Subject lines** - To help you identify emails
- **Unsubscribe links** - To process your unsubscribe requests (List-Unsubscribe headers and URLs)
- **Email count and frequency data** - To show you statistics about your inbox

**Important:** This data is processed in real-time on our servers and is NOT stored in any database. We fetch it from your email provider when you open the app, display it to you, and discard it immediately after processing your swipe decision.

## Information We Do Store

### Account Information
When you sign in with Apple or Google, we store:
- **User ID** (Apple user identifier or Google user ID)
- **Email address** (to associate your account)
- **Name** (if provided during initial sign-in with Apple)
- **Authentication tokens** (stored securely in your device's Keychain, not on our servers)

### Server-Side Session Tokens (Apple Sign-In Only)
- **JWT session tokens** (7-day expiry, used to authenticate API requests)
- These tokens do NOT contain email content or metadata

### Gamification Data
We store your app usage data to power the gamification features:
- **XP (experience points) earned**
- **Current level and streak count**
- **Achievement unlock status**
- **Session statistics** (number of emails processed, keep/unsubscribe decisions made, time spent)
- **Daily activity history** (for displaying your activity chart)

This data is stored in our database and associated with your user account. It contains NO email content or sender information—only aggregated counts and timestamps.

### Device Data
We store minimal device information:
- **Push notification tokens** (if you enable notifications, to send you streak reminders and session prompts)

## How We Use Information

### Email Metadata (Transient)
- **Display emails** to you in the swipe interface
- **Process unsubscribe requests** when you swipe left
- **Generate session statistics** (e.g., "You processed 15 emails this session")

### Account and Gamification Data
- **Authenticate your identity** across app sessions
- **Track your progress** (XP, levels, achievements, streaks)
- **Send push notifications** (if enabled) to remind you to maintain your streak
- **Display your statistics** in the Stats and Profile views

## Data Storage and Security

### Where Data is Stored
- **On your device:** Authentication tokens are stored in iOS Keychain (encrypted by Apple)
- **On our servers:** User account data and gamification statistics are stored in JSON files (`data/users.json`) on our Node.js backend server

### Data Retention
- **Email metadata:** NOT stored (fetched on-demand, discarded after use)
- **Account data:** Stored until you delete your account
- **Gamification data:** Stored until you delete your account
- **Session tokens:** Automatically expire after 7 days (Apple users) or per OAuth provider expiry (Google users)

### Security Measures
- **HTTPS/TLS encryption** for all data transmitted between your device and our servers
- **Keychain storage** for sensitive authentication tokens (encrypted by iOS)
- **OAuth 2.0 authentication** (no passwords stored by Junkpile)
- **Server-side JWT verification** using Apple's public JWKS (JSON Web Key Set)

## Third-Party Services

### Apple Sign-In
When you sign in with Apple, Apple provides us with:
- A unique user identifier
- Your email address (real or relay address if you choose "Hide My Email")
- Your name (only on first sign-in)

Apple's Privacy Policy applies to their authentication service: https://www.apple.com/legal/privacy/

### Google Sign-In and Gmail API
When you connect Gmail, Google provides us with:
- A unique user identifier
- Your email address
- OAuth access tokens (stored on your device, used to fetch email metadata)

We request **read-only access** to your Gmail account with the minimum scopes necessary:
- `https://www.googleapis.com/auth/gmail.readonly` - To read email metadata and unsubscribe links
- `https://www.googleapis.com/auth/gmail.modify` - To send unsubscribe requests on your behalf

**We DO NOT request scopes to delete emails, send emails on your behalf (except unsubscribe requests), or access Google Drive, Calendar, or other Google services.**

Google's Privacy Policy applies to their services: https://policies.google.com/privacy

### Analytics and Crash Reporting
Currently, Junkpile uses **only Apple's built-in App Analytics** (provided through App Store Connect). We do not use third-party analytics SDKs like Google Analytics, Mixpanel, or Amplitude.

In future versions, we may integrate privacy-focused analytics (e.g., TelemetryDeck) and crash reporting (e.g., Sentry). If we do, we will update this Privacy Policy and notify users.

## Your Privacy Rights

### Access and Deletion
You have the right to:
- **Access your data:** Contact us at support@junkpile.app to request a copy of your stored data
- **Delete your account:** Use the "Delete Account" option in Settings, which will permanently delete all your account and gamification data from our servers

### Revoke Email Access
You can revoke Junkpile's access to your email at any time:
- **Apple Sign-In:** Go to iOS Settings > Apple ID > Password & Security > Apps Using Apple ID > Junkpile > Stop Using Apple ID
- **Google/Gmail:** Go to your Google Account settings at https://myaccount.google.com/permissions and remove Junkpile's access

### Opt-Out of Notifications
You can disable push notifications at any time:
- **In the app:** Settings > Notifications > Disable all notification types
- **In iOS Settings:** Settings > Notifications > Junkpile > Turn off Allow Notifications

## Children's Privacy

Junkpile is not directed to children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately at support@junkpile.app.

## Data Sharing and Disclosure

### We Do Not Sell Your Data
We will never sell your personal information or email data to third parties.

### Limited Disclosure Scenarios
We may disclose your information only in these limited circumstances:
- **Legal compliance:** If required by law, court order, or government request
- **Safety and security:** To protect the rights, property, or safety of Junkpile, our users, or the public
- **Business transfer:** In the event of a merger, acquisition, or sale of assets, your data may be transferred to the new owner (you will be notified and can delete your account before the transfer)

## International Data Transfers

Junkpile's servers are currently hosted in [specify your server location, e.g., "the United States" or "AWS US-East-1"]. If you use Junkpile from outside this region, your data may be transferred to and processed in this location.

We comply with applicable data protection laws, including GDPR (if applicable to EU users) and CCPA (California residents).

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. When we do:
- We will update the "Last Updated" date at the top
- We will notify you via push notification or in-app message for material changes
- Your continued use of the app after changes constitutes acceptance of the updated policy

## Contact Us

If you have questions about this Privacy Policy or how we handle your data, please contact us:

**Email:** support@junkpile.app
**Website:** [Your website URL - to be added]
**Mail:** [Your mailing address - if required by jurisdiction]

---

## Summary (TL;DR)

✅ **We DO:**
- Temporarily access email metadata (sender, subject, unsubscribe links) to show you emails
- Store your account ID, gamification stats (XP, levels, achievements, streaks)
- Use authentication tokens (stored on your device) to access Gmail on your behalf

❌ **We DO NOT:**
- Read, store, or analyze the content of your emails
- Sell your data to anyone
- Use your email for advertising or profiling
- Share your email data with third parties

🔒 **Your Control:**
- You can delete your account anytime (Settings > Delete Account)
- You can revoke Gmail access anytime (Google Account settings)
- You control notification preferences (Settings > Notifications)

**Questions? Email support@junkpile.app**
