# Gmail API Setup Guide

To connect Junkpile to Gmail, you'll need to set up OAuth credentials through Google Cloud Console.

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Create Project" or select an existing project
3. Give it a name like "Junkpile Email App"

## Step 2: Enable Gmail API

1. In your project, go to "APIs & Services" > "Library"
2. Search for "Gmail API"
3. Click on it and press "Enable"

## Step 3: Create OAuth Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - User Type: External (for testing) or Internal (for Google Workspace)
   - App name: "Junkpile"
   - User support email: Your email
   - Developer contact: Your email
   - Add scopes: `gmail.readonly` and `gmail.modify`
   - Add test users (your Gmail address)
4. Back in Credentials:
   - Application type: "Web application"
   - Name: "Junkpile Web Client"
   - Authorized redirect URIs: `http://localhost:3000/auth/google/callback`
   - Click "Create"

## Step 4: Configure Your App

1. Copy the Client ID and Client Secret
2. Create a `.env` file in the project root (copy from `.env.example`):

```bash
GMAIL_CLIENT_ID=your_client_id_here
GMAIL_CLIENT_SECRET=your_client_secret_here
GMAIL_REDIRECT_URI=http://localhost:3000/auth/google/callback
SESSION_SECRET=your_random_secret_key_here
```

3. Replace the placeholder values with your actual credentials
4. For SESSION_SECRET, generate a random string (e.g., use a password generator)

## Step 5: Install Dependencies & Restart

```bash
npm install
npm start
```

## Step 6: Test the Connection

1. Open http://localhost:3000
2. Click "Connect Gmail"
3. You'll be redirected to Google's login page
4. Sign in and grant permissions
5. You'll be redirected back to Junkpile with your emails loaded!

## Troubleshooting

- **"Gmail API not configured"**: Make sure your `.env` file exists and has the correct values
- **"Authentication failed"**: Check that your redirect URI in Google Console matches exactly
- **"No emails found"**: The app looks for emails with unsubscribe links from the last 30 days
- **OAuth consent screen warnings**: For testing, you can add yourself as a test user

## Security Notes

- Never commit your `.env` file to git (it's already in `.gitignore`)
- The OAuth tokens are stored in server-side sessions only
- For production, use HTTPS and set `cookie.secure: true` in session config
