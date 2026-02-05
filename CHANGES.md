# Changes Made to Junkpile

## Visual Design Updates

### 1. Clean White/Black/Gray Theme
- Removed purple gradient background
- Changed to clean white background (#ffffff)
- Updated all UI elements to use black (#000), gray (#666), and light gray (#f5f5f5)
- Buttons now use black with sharp corners instead of rounded purple gradients
- Borders are crisp black lines instead of soft shadows

### 2. Envelope Pile Visualization
- Added left and right envelope piles on desktop view
- Left pile: Accumulates envelopes for each "unsubscribe" swipe
- Right pile: Accumulates envelopes for each "keep" swipe
- Envelopes have animated drop-in effect
- Piles are hidden on mobile/tablet for better UX (< 1200px width)

### 3. Email Display Improvements
- Email card now shows original HTML content in an isolated iframe
- Preserves all formatting, images, and styling from the original email
- Email header (sender/subject) separated from body for better organization
- Increased card height to 500px for better viewing
- Scrollable email body to view full content

## Gmail Integration

### Backend Changes
- Added Gmail API integration using Google OAuth 2.0
- New dependencies: `googleapis`, `express-session`, `dotenv`
- Created `gmailService.js` to handle:
  - Fetching emails with unsubscribe links
  - Parsing email HTML content
  - Extracting unsubscribe URLs from headers and body
  - Deduplicating emails by sender domain
  - Processing unsubscribe actions

### Authentication Flow
- OAuth 2.0 flow for secure Gmail access
- Session-based token storage
- Automatic redirect to Google login
- Callback handling and token management
- Permission scopes: `gmail.readonly` and `gmail.modify`

### API Endpoints Added
- `GET /api/auth/url` - Get OAuth authorization URL
- `GET /auth/google/callback` - OAuth callback handler
- `POST /api/logout` - Clear session and logout

### Frontend Changes
- Updated connect button to trigger OAuth flow
- Added auth status checking on page load
- Automatic email fetching after successful authentication
- Better error handling for various auth states

## Files Added
- `server/gmailService.js` - Gmail API service layer
- `.env.example` - Environment variable template
- `GMAIL_SETUP.md` - Complete setup guide for Gmail OAuth
- `CHANGES.md` - This file

## Files Modified
- `public/css/style.css` - Complete visual redesign
- `public/index.html` - Added envelope piles and updated structure
- `public/js/app.js` - Added OAuth flow and email rendering
- `server/server.js` - Gmail integration and OAuth endpoints
- `package.json` - New dependencies
- `.gitignore` - Added .env to prevent credential leaks

## Next Steps to Use Gmail

1. Follow the instructions in `GMAIL_SETUP.md` to set up Google Cloud OAuth
2. Create a `.env` file with your credentials (see `.env.example`)
3. Restart the server: `npm start`
4. Click "Connect Gmail" and authorize the app
5. Start swiping on your real emails!

## How It Works Now

1. User clicks "Connect Gmail"
2. Redirected to Google OAuth consent screen
3. User grants permissions
4. App fetches emails with unsubscribe links from last 30 days
5. Emails are deduplicated by sender domain (one per sender)
6. User swipes left (unsubscribe) or right (keep)
7. Left swipes mark email as read and store the unsubscribe URL
8. Envelope visualizations appear on each swipe
9. Original email HTML is rendered in the card for authentic viewing

## Technical Notes

- Email HTML is rendered in a sandboxed iframe for security
- OAuth tokens are stored server-side in sessions
- Unsubscribe URLs are extracted from List-Unsubscribe headers or email body
- The app searches for emails up to 30 days old with "unsubscribe" keywords
- All sensitive credentials are in `.env` and excluded from git
