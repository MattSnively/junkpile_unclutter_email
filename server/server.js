require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { google } = require('googleapis');
const GmailService = require('./gmailService');
const { verifyAppleToken } = require('./appleAuth');
const { generateSessionToken, verifySessionToken } = require('./sessionToken');
const userStore = require('./userStore');

const app = express();
// Use Railway's injected PORT in production, fall back to 3000 for local dev
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(session({
    secret: process.env.SESSION_SECRET || 'junkpile-secret-key',
    resave: false,
    saveUninitialized: false,
    // Secure cookies in production (Railway serves over HTTPS)
    cookie: { secure: process.env.NODE_ENV === 'production' }
}));
app.use(express.static(path.join(__dirname, '../public')));

// Health check endpoint — returns 200 so Railway knows the service is alive
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// Data file path
const DATA_FILE = path.join(__dirname, '../data/decisions.json');

// OAuth2 Client — used for web auth flow (session-based)
const oauth2Client = new google.auth.OAuth2(
    process.env.GMAIL_CLIENT_ID,
    process.env.GMAIL_CLIENT_SECRET,
    process.env.GMAIL_REDIRECT_URI || 'http://localhost:3000/auth/google/callback'
);

/**
 * Exchange a mobile auth code directly with Google's token endpoint.
 * The googleapis OAuth2 library doesn't handle public (secretless) clients
 * correctly, so we POST to the token endpoint ourselves.
 *
 * @param {string} code - Authorization code from the iOS app
 * @returns {Object} Token response with access_token, refresh_token, etc.
 */
async function exchangeMobileAuthCode(code) {
    const params = new URLSearchParams({
        code,
        client_id: process.env.GMAIL_IOS_CLIENT_ID,
        redirect_uri: 'com.junkpile.app:/oauth2callback',
        grant_type: 'authorization_code'
        // No client_secret — iOS OAuth clients are public
    });

    const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    });

    const data = await response.json();

    if (!response.ok) {
        const errMsg = data.error_description || data.error || 'Token exchange failed';
        throw new Error(errMsg);
    }

    return data;
}

// Initialize data file, creating the data/ directory if it doesn't exist.
// The data/ directory is gitignored, so it won't exist on first deploy.
async function initDataFile() {
    try {
        // Ensure the parent directory exists (gitignored, won't be in the repo)
        const dataDir = path.dirname(DATA_FILE);
        await fs.mkdir(dataDir, { recursive: true });

        await fs.access(DATA_FILE);
    } catch {
        await fs.writeFile(DATA_FILE, JSON.stringify({ sessions: [] }, null, 2));
    }
}

// Check if Gmail credentials are configured
function hasGmailCredentials() {
    return !!(process.env.GMAIL_CLIENT_ID && process.env.GMAIL_CLIENT_SECRET);
}

// =============================================================================
// MOBILE AUTH ENDPOINTS
// These endpoints support iOS/Android apps with Bearer token authentication
// =============================================================================

/**
 * Exchange authorization code for tokens (mobile OAuth flow).
 * Mobile apps use this instead of the web callback since they can't use session cookies.
 * Returns tokens directly to be stored securely on device (Keychain/Keystore).
 */
app.post('/api/auth/mobile', async (req, res) => {
    const { code, platform } = req.body;

    // Validate required parameters
    if (!code) {
        return res.status(400).json({
            success: false,
            error: 'Authorization code is required'
        });
    }

    // Check if Gmail credentials are configured
    if (!hasGmailCredentials()) {
        return res.status(503).json({
            success: false,
            error: 'Gmail credentials not configured on server'
        });
    }

    try {
        // Exchange the authorization code via direct POST to Google's token endpoint.
        // We can't use the googleapis OAuth2 library here because iOS clients are
        // public (no secret), and the library doesn't handle that correctly.
        const tokens = await exchangeMobileAuthCode(code);

        // Get user info using the access token.
        // Access tokens are client-agnostic, so we can use the web oauth2Client.
        oauth2Client.setCredentials({ access_token: tokens.access_token });
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        // Return tokens to the mobile app
        // The app should store these securely in Keychain (iOS) or Keystore (Android)
        res.json({
            success: true,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_in: tokens.expires_in || 3600,
            token_type: 'Bearer',
            email: userInfo.data.email,
            name: userInfo.data.name,
            picture: userInfo.data.picture
        });

    } catch (error) {
        console.error('Mobile auth error:', error);
        res.status(401).json({
            success: false,
            error: error.message || 'Failed to exchange authorization code'
        });
    }
});

/**
 * Refresh an expired access token using the refresh token.
 * Handles both direct refresh tokens (Google users) and server-side
 * stored tokens (Apple users who connected Gmail).
 */
app.post('/api/auth/refresh', async (req, res) => {
    const { refresh_token } = req.body;

    // Check if this is an Apple user refreshing via their session token.
    // Apple users' Gmail refresh tokens are stored server-side.
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const sessionPayload = verifySessionToken(token);

        if (sessionPayload) {
            // Apple user — refresh using server-stored Gmail refresh token
            try {
                const user = await userStore.findById(sessionPayload.userId);
                if (!user || !user.gmailTokens || !user.gmailTokens.refresh_token) {
                    return res.status(400).json({
                        success: false,
                        error: 'No Gmail connection found. Please connect Gmail first.'
                    });
                }

                // Use the server-stored refresh token to get a new access token
                oauth2Client.setCredentials({ refresh_token: user.gmailTokens.refresh_token });
                const { credentials } = await oauth2Client.refreshAccessToken();

                // Update the stored tokens on the user record
                await userStore.updateUser(user.id, {
                    gmailTokens: {
                        ...user.gmailTokens,
                        access_token: credentials.access_token,
                        expiry_date: credentials.expiry_date
                    }
                });

                return res.json({
                    success: true,
                    access_token: credentials.access_token,
                    expires_in: credentials.expiry_date
                        ? Math.floor((credentials.expiry_date - Date.now()) / 1000)
                        : 3600
                });

            } catch (error) {
                console.error('Apple user token refresh error:', error);
                return res.status(401).json({
                    success: false,
                    error: 'Failed to refresh Gmail token. Please reconnect Gmail.'
                });
            }
        }
    }

    // Google user — use the client-provided refresh token (existing behavior)
    if (!refresh_token) {
        return res.status(400).json({
            success: false,
            error: 'Refresh token is required'
        });
    }

    try {
        oauth2Client.setCredentials({ refresh_token });
        const { credentials } = await oauth2Client.refreshAccessToken();

        res.json({
            success: true,
            access_token: credentials.access_token,
            expires_in: credentials.expiry_date
                ? Math.floor((credentials.expiry_date - Date.now()) / 1000)
                : 3600
        });

    } catch (error) {
        console.error('Token refresh error:', error);
        res.status(401).json({
            success: false,
            error: 'Failed to refresh token. Please sign in again.'
        });
    }
});

/**
 * Validate a token and return user info.
 * Handles both server session tokens (Apple users) and Google access tokens.
 * Mobile apps use this to check if their stored token is still valid.
 */
app.get('/api/auth/validate', async (req, res) => {
    // Extract Bearer token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            valid: false,
            error: 'No authorization token provided'
        });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Try to verify as a server session token first (Apple users)
    const sessionPayload = verifySessionToken(token);
    if (sessionPayload) {
        try {
            const user = await userStore.findById(sessionPayload.userId);
            if (user) {
                return res.json({
                    valid: true,
                    email: user.email,
                    name: user.name,
                    provider: user.authProvider,
                    gmailConnected: !!user.gmailTokens,
                    gmailEmail: user.gmailEmail || null
                });
            }
        } catch (err) {
            console.error('User lookup during validation failed:', err);
        }
        return res.status(401).json({
            valid: false,
            error: 'Session token is valid but user not found'
        });
    }

    // Fall back to Google access token validation (existing behavior)
    try {
        oauth2Client.setCredentials({ access_token: token });
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        res.json({
            valid: true,
            email: userInfo.data.email,
            name: userInfo.data.name,
            picture: userInfo.data.picture,
            provider: 'google',
            gmailConnected: true
        });

    } catch (error) {
        console.error('Token validation error:', error);
        res.status(401).json({
            valid: false,
            error: 'Token is invalid or expired'
        });
    }
});

// =============================================================================
// APPLE SIGN-IN ENDPOINTS
// These endpoints support the two-step auth flow: Apple identity + Gmail access
// =============================================================================

/**
 * Exchange an Apple identity token for a server session token.
 * Called after the iOS app completes Sign in with Apple.
 *
 * Flow:
 * 1. Verify the Apple identity token JWT (signature, issuer, audience)
 * 2. Extract the Apple user ID (`sub`) from the token
 * 3. Find or create a user record in our store
 * 4. Issue a server session token (7-day expiry) for subsequent API calls
 *
 * CRITICAL: Apple only provides email and fullName on the FIRST sign-in.
 * On subsequent sign-ins these fields are null. We must store them immediately.
 */
app.post('/api/auth/apple', async (req, res) => {
    const { identityToken, authorizationCode, email, fullName, platform } = req.body;

    // Validate required parameters
    if (!identityToken) {
        return res.status(400).json({
            success: false,
            error: 'Apple identity token is required'
        });
    }

    try {
        // Step 1: Verify the Apple identity token
        const decoded = await verifyAppleToken(identityToken);
        const appleUserId = decoded.sub; // Apple's stable user identifier

        // Step 2: Find existing user or create a new one
        let user = await userStore.findByAppleId(appleUserId);

        if (user) {
            // Returning user — update last login timestamp
            user = await userStore.updateUser(user.id, {
                lastLoginAt: new Date().toISOString()
            });
        } else {
            // New user — create record with email/name from the request.
            // Apple's JWT may also contain email, but the request body version
            // is more reliable on first sign-in (includes full name).
            const userEmail = email || decoded.email || 'unknown@privaterelay.appleid.com';
            user = await userStore.createUser({
                appleUserId,
                email: userEmail,
                name: fullName || null,
                authProvider: 'apple'
            });
        }

        // Step 3: Generate a server session token for subsequent API calls
        const sessionToken = generateSessionToken(user.id, 'apple');

        res.json({
            success: true,
            sessionToken,
            userId: user.id,
            email: user.email,
            name: user.name
        });

    } catch (error) {
        console.error('Apple auth error:', error);
        res.status(401).json({
            success: false,
            error: error.message || 'Apple Sign-In verification failed'
        });
    }
});

/**
 * Connect Gmail to an existing Apple Sign-In user account.
 * This is step 2 of the two-step auth flow.
 *
 * The user already signed in with Apple (has a server session token).
 * Now they're authorizing Gmail access via a separate Google OAuth flow.
 * We exchange the Google auth code for tokens and store them on the user record.
 */
app.post('/api/auth/connect-gmail', async (req, res) => {
    const { code, platform } = req.body;

    // Validate required parameters
    if (!code) {
        return res.status(400).json({
            success: false,
            error: 'Google authorization code is required'
        });
    }

    // Authenticate — requires a valid server session token (Apple user)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            success: false,
            error: 'Authorization required'
        });
    }

    const token = authHeader.substring(7);
    const sessionPayload = verifySessionToken(token);

    if (!sessionPayload) {
        return res.status(401).json({
            success: false,
            error: 'Invalid or expired session token'
        });
    }

    // Check if Gmail credentials are configured on the server
    if (!hasGmailCredentials()) {
        return res.status(503).json({
            success: false,
            error: 'Gmail credentials not configured on server'
        });
    }

    try {
        // Exchange the Google auth code via direct POST to Google's token endpoint.
        // Apple Sign-In users connect Gmail from the iOS app, so the auth code
        // was obtained with the iOS client ID + custom-scheme redirect URI.
        const tokens = await exchangeMobileAuthCode(code);

        // Fetch the Gmail user's email to store alongside the tokens.
        // Access tokens are client-agnostic, so we reuse the web oauth2Client.
        oauth2Client.setCredentials({ access_token: tokens.access_token });
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        // Store the Gmail tokens on the user record
        const user = await userStore.findById(sessionPayload.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'User not found'
            });
        }

        // Convert expires_in (seconds) to an absolute expiry_date (ms timestamp)
        // for consistent storage with the rest of the codebase.
        const expiryDate = tokens.expires_in
            ? Date.now() + (tokens.expires_in * 1000)
            : null;

        await userStore.updateUser(user.id, {
            gmailTokens: {
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token,
                expiry_date: expiryDate
            },
            gmailEmail: userInfo.data.email
        });

        // Return tokens to the app so it can use them directly for Gmail API calls
        res.json({
            success: true,
            email: userInfo.data.email,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_in: tokens.expires_in || 3600
        });

    } catch (error) {
        console.error('Connect Gmail error:', error);
        res.status(401).json({
            success: false,
            error: error.message || 'Failed to connect Gmail'
        });
    }
});

// =============================================================================
// Helper middleware for mobile authentication
// Extracts Bearer token and sets up oauth2Client for authenticated endpoints
// =============================================================================

/**
 * Middleware to handle session-based (web), Google token (mobile), and
 * server session token (Apple Sign-In) authentication.
 *
 * Priority order:
 * 1. Bearer token — try as server session JWT first (Apple users),
 *    then fall back to treating it as a Google access token
 * 2. Session cookies (web)
 *
 * Sets req.authTokens (for Gmail API calls) and optionally req.user
 * (for Apple users whose Gmail tokens are stored server-side).
 */
async function authenticateRequest(req, res, next) {
    // Check for Bearer token (mobile)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);

        // Try to verify as a server session token (issued to Apple Sign-In users)
        const sessionPayload = verifySessionToken(token);
        if (sessionPayload) {
            // Valid server session token — look up user to get Gmail tokens
            try {
                const user = await userStore.findById(sessionPayload.userId);
                if (user) {
                    req.user = user;
                    // Provide Gmail tokens if connected, otherwise leave authTokens null.
                    // Endpoints that require Gmail access should check req.authTokens.
                    req.authTokens = user.gmailTokens || null;
                    return next();
                }
            } catch (err) {
                console.error('User lookup failed:', err);
            }
            // User not found despite valid token — treat as unauthenticated
            return res.status(401).json({
                success: false,
                needsAuth: true,
                error: 'User not found'
            });
        }

        // Not a server session token — treat as a Google access token (existing behavior)
        req.authTokens = { access_token: token };
        return next();
    }

    // Fall back to session tokens (web)
    if (req.session && req.session.tokens) {
        req.authTokens = req.session.tokens;
        return next();
    }

    // No authentication found
    return res.status(401).json({
        success: false,
        needsAuth: true,
        error: 'Authentication required'
    });
}

// =============================================================================
// WEB AUTH ROUTES (original session-based authentication)
// =============================================================================

// Auth routes
app.get('/api/auth/url', (req, res) => {
    if (!hasGmailCredentials()) {
        return res.json({
            success: false,
            error: 'Gmail credentials not configured',
            needsSetup: true
        });
    }

    const authUrl = oauth2Client.generateAuthUrl({
        access_type: 'offline',
        scope: [
            'https://www.googleapis.com/auth/gmail.readonly',
            'https://www.googleapis.com/auth/gmail.modify',
            'https://www.googleapis.com/auth/gmail.send'      // Required for mailto-based unsubscribe
        ]
    });

    res.json({ success: true, authUrl });
});

app.get('/auth/google/callback', async (req, res) => {
    const { code } = req.query;

    try {
        const { tokens } = await oauth2Client.getToken(code);
        oauth2Client.setCredentials(tokens);

        // Store tokens in session
        req.session.tokens = tokens;

        res.redirect('/?auth=success');
    } catch (error) {
        console.error('Error during OAuth callback:', error);
        res.redirect('/?auth=error');
    }
});

// Get emails endpoint
// Updated to support both session (web) and Bearer token (mobile) authentication
app.get('/api/emails', authenticateRequest, async (req, res) => {
    try {
        // Use tokens from middleware (works for both web and mobile)
        oauth2Client.setCredentials(req.authTokens);
        const gmailService = new GmailService(oauth2Client);

        const emails = await gmailService.getEmailsWithUnsubscribe();

        res.json({
            success: true,
            emails: emails
        });
    } catch (error) {
        console.error('Error fetching emails:', error);

        // Check if it's an auth error
        if (error.code === 401 || error.message.includes('invalid_grant')) {
            return res.status(401).json({
                success: false,
                needsAuth: true,
                error: 'Authentication expired. Please sign in again.'
            });
        }

        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Save decision endpoint
// Updated to support both session (web) and Bearer token (mobile) authentication
app.post('/api/decision', authenticateRequest, async (req, res) => {
    try {
        const { emailId, decision } = req.body;

        // Validate required fields
        if (!emailId || !decision) {
            return res.status(400).json({
                success: false,
                error: 'emailId and decision are required'
            });
        }

        // Validate decision value
        if (!['unsubscribe', 'keep'].includes(decision)) {
            return res.status(400).json({
                success: false,
                error: 'decision must be "unsubscribe" or "keep"'
            });
        }

        // If unsubscribe, execute the actual unsubscribe via cascade
        // (RFC 8058 one-click → HTTP header URLs → HTTP body URL → mailto fallback)
        let unsubResult = null;
        if (decision === 'unsubscribe' && req.authTokens) {
            oauth2Client.setCredentials(req.authTokens);
            const gmailService = new GmailService(oauth2Client);

            // Get the email to find all unsubscribe data (headers + body)
            const emailDetails = await gmailService.getEmailDetails(emailId);
            if (emailDetails && emailDetails.unsubscribeData) {
                unsubResult = await gmailService.unsubscribe(emailId, emailDetails.unsubscribeData);
            }
        }

        // Read existing data
        const data = await fs.readFile(DATA_FILE, 'utf8');
        const jsonData = JSON.parse(data);

        // Find or create current session
        let currentSession = jsonData.sessions.find(s => !s.completed);
        if (!currentSession) {
            currentSession = {
                id: Date.now().toString(),
                startTime: new Date().toISOString(),
                decisions: [],
                completed: false
            };
            jsonData.sessions.push(currentSession);
        }

        // Add decision (include unsubscribe method used, if any)
        currentSession.decisions.push({
            emailId,
            decision,
            timestamp: new Date().toISOString(),
            unsubscribeMethod: unsubResult?.unsubscribeResult?.method || null
        });

        // Save data
        await fs.writeFile(DATA_FILE, JSON.stringify(jsonData, null, 2));

        // Return response with unsubscribe execution details
        res.json({
            success: true,
            message: decision === 'unsubscribe'
                ? (unsubResult?.unsubscribeResult?.success
                    ? 'Unsubscribed successfully'
                    : 'Unsubscribe attempted - may require manual confirmation')
                : 'Email kept',
            unsubscribeResult: decision === 'unsubscribe'
                ? unsubResult?.unsubscribeResult
                : undefined
        });
    } catch (error) {
        console.error('Error saving decision:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Logout endpoint — handles both web sessions and Apple user sessions
app.post('/api/logout', async (req, res) => {
    // Check if this is an Apple user logging out (server session token)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const sessionPayload = verifySessionToken(token);

        if (sessionPayload) {
            // Apple user — the session token will naturally expire.
            // Optionally clear Gmail tokens from user record for clean logout.
            try {
                await userStore.updateUser(sessionPayload.userId, {
                    gmailTokens: null,
                    gmailEmail: null
                });
            } catch (err) {
                console.error('Error clearing Gmail tokens on logout:', err);
            }
        }
    }

    // Destroy web session if present
    if (req.session) {
        req.session.destroy();
    }

    res.json({ success: true });
});

// Get statistics endpoint
app.get('/api/stats', async (req, res) => {
    try {
        const data = await fs.readFile(DATA_FILE, 'utf8');
        const jsonData = JSON.parse(data);

        const stats = {
            totalSessions: jsonData.sessions.length,
            completedSessions: jsonData.sessions.filter(s => s.completed).length,
            totalDecisions: jsonData.sessions.reduce((acc, s) => acc + s.decisions.length, 0),
            totalUnsubscribes: jsonData.sessions.reduce((acc, s) =>
                acc + s.decisions.filter(d => d.decision === 'unsubscribe').length, 0
            )
        };

        res.json({ success: true, stats });
    } catch (error) {
        console.error('Error getting stats:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Start server — initialize both decisions and users data files
Promise.all([initDataFile(), userStore.initUsersFile()]).then(() => {
    // Bind to 0.0.0.0 so Railway's reverse proxy can reach the container
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Junkpile server running on port ${PORT}`);
        if (!hasGmailCredentials()) {
            console.log('\n⚠️  Gmail credentials not configured!');
            console.log('Please set up your .env file with Gmail OAuth credentials.');
            console.log('See .env.example for details.\n');
        }
    });
});
