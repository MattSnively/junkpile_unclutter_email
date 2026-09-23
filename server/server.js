require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const cors = require('cors');
const path = require('path');
const crypto = require('crypto');
const { google } = require('googleapis');
const GmailService = require('./gmailService');
const { verifyAppleToken } = require('./appleAuth');
const { exchangeAuthorizationCode, revokeAppleToken } = require('./appleRevoke');
const { generateSessionToken, verifySessionToken } = require('./sessionToken');
const db = require('./db');
const userStore = require('./userStore');
const decisionStore = require('./decisionStore');
const { CODES, sendError, sendGmailError, unsubscribeFailureCode } = require('./apiErrors');

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

/**
 * Refresh a mobile token directly with Google's token endpoint.
 * Same reason as exchangeMobileAuthCode — the googleapis library can't
 * refresh tokens issued to the public iOS client.
 *
 * @param {string} refreshToken - The refresh token from the iOS app
 * @returns {Object} Token response with access_token, expires_in, etc.
 */
async function refreshMobileToken(refreshToken) {
    const params = new URLSearchParams({
        refresh_token: refreshToken,
        client_id: process.env.GMAIL_IOS_CLIENT_ID,
        grant_type: 'refresh_token'
        // No client_secret — iOS OAuth clients are public
    });

    const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    });

    const data = await response.json();

    if (!response.ok) {
        const errMsg = data.error_description || data.error || 'Token refresh failed';
        throw new Error(errMsg);
    }

    return data;
}

// Google Sign-In users have no server-side record, so their decisions are
// keyed by Gmail address. Looking that up costs a Gmail API call, so cache it
// per access token for the token's lifetime (Google access tokens live 1h).
const GOOGLE_KEY_TTL_MS = 60 * 60 * 1000;
const googleUserKeys = new Map();

async function resolveGoogleUserKey(accessToken) {
    const cacheKey = crypto.createHash('sha256').update(accessToken).digest('hex');
    const cached = googleUserKeys.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
        return cached.userKey;
    }

    const auth = new google.auth.OAuth2();
    auth.setCredentials({ access_token: accessToken });
    const gmail = google.gmail({ version: 'v1', auth });
    const profile = await gmail.users.getProfile({ userId: 'me' });
    const userKey = `google:${profile.data.emailAddress}`;

    // Evict stale entries on the miss path so the map stays bounded by active tokens
    for (const [key, entry] of googleUserKeys) {
        if (entry.expiresAt <= Date.now()) googleUserKeys.delete(key);
    }
    googleUserKeys.set(cacheKey, { userKey, expiresAt: Date.now() + GOOGLE_KEY_TTL_MS });
    return userKey;
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
        return sendError(res, 400, CODES.VALIDATION_ERROR, 'Authorization code is required');
    }

    // Check if Gmail credentials are configured
    if (!hasGmailCredentials()) {
        return sendError(res, 503, CODES.SERVER_NOT_CONFIGURED, 'Gmail credentials not configured on server');
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
        sendError(res, 401, CODES.AUTH_INVALID, error.message || 'Failed to exchange authorization code');
    }
});

/**
 * Refresh an expired access token using the refresh token.
 * Handles both direct refresh tokens (Google users) and server-side
 * stored tokens (Apple users who connected Gmail).
 */
app.post('/api/auth/refresh', async (req, res) => {
    const { refresh_token, platform } = req.body;

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
                    return sendError(res, 400, CODES.GMAIL_NOT_CONNECTED, 'No Gmail connection found. Please connect Gmail first.');
                }

                // Use the server-stored refresh token to get a new access token.
                // Gmail tokens for Apple users were obtained via the iOS client,
                // so we must refresh via direct POST (no client secret).
                const data = await refreshMobileToken(user.gmailTokens.refresh_token);

                // Convert expires_in to absolute timestamp for storage
                const expiryDate = data.expires_in
                    ? Date.now() + (data.expires_in * 1000)
                    : null;

                // Update the stored tokens on the user record
                await userStore.updateUser(user.id, {
                    gmailTokens: {
                        ...user.gmailTokens,
                        access_token: data.access_token,
                        expiry_date: expiryDate
                    }
                });

                return res.json({
                    success: true,
                    access_token: data.access_token,
                    expires_in: data.expires_in || 3600
                });

            } catch (error) {
                console.error('Apple user token refresh error:', error);
                return sendError(res, 401, CODES.OAUTH_TOKEN_EXPIRED, 'Failed to refresh Gmail token. Please reconnect Gmail.');
            }
        }
    }

    // Google user — use the client-provided refresh token
    if (!refresh_token) {
        return sendError(res, 400, CODES.VALIDATION_ERROR, 'Refresh token is required');
    }

    try {
        // iOS tokens were issued to the public iOS client, so we must refresh
        // via direct POST (same as exchangeMobileAuthCode). Web tokens use the
        // googleapis library with the web client secret.
        if (platform === 'ios') {
            const data = await refreshMobileToken(refresh_token);
            return res.json({
                success: true,
                access_token: data.access_token,
                expires_in: data.expires_in || 3600
            });
        }

        // Web client refresh (existing behavior)
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
        sendError(res, 401, CODES.OAUTH_TOKEN_EXPIRED, 'Failed to refresh token. Please sign in again.');
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
        return sendError(res, 401, CODES.AUTH_REQUIRED, 'No authorization token provided', { valid: false });
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
        return sendError(res, 401, CODES.AUTH_INVALID, 'Session token is valid but user not found', { valid: false });
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
        sendError(res, 401, CODES.OAUTH_TOKEN_EXPIRED, 'Token is invalid or expired', { valid: false });
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
        return sendError(res, 400, CODES.VALIDATION_ERROR, 'Apple identity token is required');
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

        // Keep Apple's refresh token so account deletion can revoke it
        // (App Review 5.1.1(v)). The iOS app sends a fresh code on every
        // sign-in, so users who predate this pick one up next time. Never
        // blocks sign-in: a failure here only costs us the revoke later.
        if (authorizationCode) {
            try {
                const refreshToken = await exchangeAuthorizationCode(authorizationCode);
                if (refreshToken) {
                    user = await userStore.updateUser(user.id, {
                        appleTokens: { refresh_token: refreshToken }
                    });
                }
            } catch (error) {
                console.error('Apple authorization code exchange failed:', error.message);
            }
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
        sendError(res, 401, CODES.AUTH_INVALID, error.message || 'Apple Sign-In verification failed');
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
        return sendError(res, 400, CODES.VALIDATION_ERROR, 'Google authorization code is required');
    }

    // Authenticate — requires a valid server session token (Apple user)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return sendError(res, 401, CODES.AUTH_REQUIRED, 'Authorization required');
    }

    const token = authHeader.substring(7);
    const sessionPayload = verifySessionToken(token);

    if (!sessionPayload) {
        return sendError(res, 401, CODES.AUTH_INVALID, 'Invalid or expired session token');
    }

    // Check if Gmail credentials are configured on the server
    if (!hasGmailCredentials()) {
        return sendError(res, 503, CODES.SERVER_NOT_CONFIGURED, 'Gmail credentials not configured on server');
    }

    try {
        // Exchange the Google auth code via direct POST to Google's token endpoint.
        // Apple Sign-In users connect Gmail from the iOS app, so the auth code
        // was obtained with the iOS client ID + custom-scheme redirect URI.
        const tokens = await exchangeMobileAuthCode(code);

        // Fetch the Gmail user's email address.
        // The connect-gmail flow only requests Gmail scopes (no email/profile),
        // so we can't use oauth2.userinfo. Use gmail.users.getProfile instead,
        // which only requires the gmail.readonly scope.
        oauth2Client.setCredentials({ access_token: tokens.access_token });
        const gmail = google.gmail({ version: 'v1', auth: oauth2Client });
        const profile = await gmail.users.getProfile({ userId: 'me' });
        const gmailEmail = profile.data.emailAddress;

        // Store the Gmail tokens on the user record
        const user = await userStore.findById(sessionPayload.userId);
        if (!user) {
            return sendError(res, 404, CODES.NOT_FOUND, 'User not found');
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
            gmailEmail: gmailEmail
        });

        // Return tokens to the app so it can use them directly for Gmail API calls
        res.json({
            success: true,
            email: gmailEmail,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_in: tokens.expires_in || 3600
        });

    } catch (error) {
        console.error('Connect Gmail error:', error);
        sendError(res, 401, CODES.AUTH_INVALID, error.message || 'Failed to connect Gmail');
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
                    req.userKey = user.id;
                    // Provide Gmail tokens if connected, otherwise leave authTokens null.
                    // Endpoints that require Gmail access should check req.authTokens.
                    req.authTokens = user.gmailTokens || null;
                    return next();
                }
            } catch (err) {
                console.error('User lookup failed:', err);
            }
            // User not found despite valid token — treat as unauthenticated
            return sendError(res, 401, CODES.AUTH_INVALID, 'User not found');
        }

        // Not a server session token — treat as a Google access token (existing behavior).
        // Explicitly null out refresh_token so the googleapis library won't try to
        // auto-refresh using the web client credentials (which can't refresh iOS tokens).
        req.authTokens = { access_token: token, refresh_token: null };
        return resolveGoogleUserKey(token)
            .then(userKey => { req.userKey = userKey; next(); })
            .catch(() => sendError(res, 401, CODES.OAUTH_TOKEN_EXPIRED, 'Authentication expired. Please sign in again.'));
    }

    // Fall back to session tokens (web)
    if (req.session && req.session.tokens) {
        req.authTokens = req.session.tokens;
        return resolveGoogleUserKey(req.session.tokens.access_token)
            .then(userKey => { req.userKey = userKey; next(); })
            .catch(() => sendError(res, 401, CODES.OAUTH_TOKEN_EXPIRED, 'Authentication expired. Please sign in again.'));
    }

    // No authentication found
    return sendError(res, 401, CODES.AUTH_REQUIRED, 'Authentication required');
}

/**
 * Guards routes that need Gmail access. An Apple user who signed in but never
 * connected Gmail has no tokens; without this the Gmail call fails and gets
 * reported as an unreachable-Gmail error, so the app tells them to retry when
 * what they actually need is to connect Gmail.
 */
function requireGmail(req, res, next) {
    if (!req.authTokens?.access_token) {
        return sendError(res, 400, CODES.GMAIL_NOT_CONNECTED, 'Connect Gmail to continue.');
    }
    next();
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
app.get('/api/emails', authenticateRequest, requireGmail, async (req, res) => {
    try {
        // Use tokens from middleware (works for both web and mobile)
        oauth2Client.setCredentials(req.authTokens);
        const gmailService = new GmailService(oauth2Client);

        // Skip anything this user already decided on, otherwise the same
        // senders come back every session until newer mail displaces them.
        const decided = await decisionStore.getDecided(req.userKey);
        const emails = await gmailService.getEmailsWithUnsubscribe({
            excludeIds: decided.emailIds,
            excludeSenders: decided.senders
        });

        res.json({
            success: true,
            emails: emails
        });
    } catch (error) {
        console.error('Error fetching emails:', error);
        sendGmailError(res, error);
    }
});

// Save decision endpoint
// Updated to support both session (web) and Bearer token (mobile) authentication
app.post('/api/decision', authenticateRequest, async (req, res) => {
    try {
        const { emailId, decision } = req.body;

        // Validate required fields
        if (!emailId || !decision) {
            return sendError(res, 400, CODES.VALIDATION_ERROR, 'emailId and decision are required');
        }

        // Validate decision value
        if (!['unsubscribe', 'keep'].includes(decision)) {
            return sendError(res, 400, CODES.VALIDATION_ERROR, 'decision must be "unsubscribe" or "keep"');
        }

        // If unsubscribe, execute the actual unsubscribe via cascade
        // (RFC 8058 one-click → HTTP header URLs → HTTP body URL → mailto fallback)
        let unsubResult = null;
        // Sender address is stored with the decision so later batches can skip
        // this sender entirely, not just this one message.
        let senderAddress = null;
        if (req.authTokens) {
            oauth2Client.setCredentials(req.authTokens);
            const gmailService = new GmailService(oauth2Client);

            // Gmail failures here are the caller's token or quota, not our bug,
            // so classify them instead of letting them fall through to a 500.
            try {
                if (decision === 'unsubscribe') {
                    // Get the email to find all unsubscribe data (headers + body)
                    const emailDetails = await gmailService.getEmailDetails(emailId);
                    if (emailDetails) {
                        senderAddress = gmailService.extractSenderAddress(emailDetails.rawHeaders.from);
                        if (emailDetails.unsubscribeData) {
                            unsubResult = await gmailService.unsubscribe(emailId, emailDetails.unsubscribeData);
                        }
                    }
                } else {
                    senderAddress = await gmailService.getSenderAddress(emailId);
                }
            } catch (error) {
                console.error('Gmail error during decision:', error);
                return sendGmailError(res, error);
            }
        }

        // Clients distinguish confirmed/attempted/failed from this result, so an
        // unsubscribe decision must always carry one — an omitted field is
        // ambiguous on the client. Cover the paths where the cascade never ran.
        if (decision === 'unsubscribe' && !unsubResult?.unsubscribeResult) {
            unsubResult = {
                unsubscribeResult: {
                    success: false,
                    method: null,
                    attempted: [],
                    error: req.authTokens ? 'no-unsubscribe-data' : 'not-authenticated'
                }
            };
        }

        // Stable code alongside the free-text error so the app can pick a recovery action
        if (unsubResult?.unsubscribeResult) {
            unsubResult.unsubscribeResult.code = unsubscribeFailureCode(unsubResult.unsubscribeResult.error);
        }

        // Record decision (include unsubscribe method used, if any)
        await decisionStore.recordDecision(req.userKey, {
            emailId,
            decision,
            unsubscribeMethod: unsubResult?.unsubscribeResult?.method || null,
            senderAddress
        });

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
        sendError(res, 500, CODES.SERVER_INTERNAL_ERROR, 'Something went wrong on our side. Please try again.');
    }
});

/**
 * Approximate subscription count for onboarding. Scans a bounded sample of
 * recent mail, so it answers quickly and is honest about being a floor
 * rather than a full inbox tally.
 */
app.get('/api/subscriptions/count', authenticateRequest, requireGmail, async (req, res) => {
    try {
        oauth2Client.setCredentials(req.authTokens);
        const gmailService = new GmailService(oauth2Client);

        const decided = await decisionStore.getDecided(req.userKey);
        const result = await gmailService.countUnsubscribeSenders({ excludeSenders: decided.senders });

        res.json({
            success: true,
            count: result.uniqueSenders,
            // The count is a floor unless the scan exhausted the matches
            isMinimum: result.scanned > 0 && result.totalMatchesEstimate > result.scanned,
            scanned: result.scanned
        });
    } catch (error) {
        console.error('Error counting subscriptions:', error);
        sendGmailError(res, error);
    }
});

/**
 * Revokes a Google OAuth grant. Either token works: revoking an access token
 * also revokes its refresh token. Best-effort — a failure here must not keep
 * the user's data on our side, so callers log and continue.
 *
 * @param {string} token - Access or refresh token
 */
async function revokeGoogleToken(token) {
    const response = await fetch('https://oauth2.googleapis.com/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ token }).toString()
    });
    if (!response.ok) {
        throw new Error(`Google revoke returned ${response.status}`);
    }
}

/**
 * Permanently delete the caller's account: revoke the Google and Apple grants, remove
 * their decisions, and remove the user row (Apple users only; Google users
 * have none). Required for App Review — the iOS Settings screen calls this
 * after a double confirmation and then signs out locally.
 */
app.delete('/api/account', authenticateRequest, async (req, res) => {
    try {
        const token = req.authTokens?.refresh_token || req.authTokens?.access_token;
        if (token) {
            try {
                await revokeGoogleToken(token);
            } catch (error) {
                console.error('Google token revoke failed during account deletion:', error.message);
            }
        }

        const appleRefreshToken = req.user?.appleTokens?.refresh_token;
        if (appleRefreshToken) {
            try {
                await revokeAppleToken(appleRefreshToken);
            } catch (error) {
                console.error('Apple token revoke failed during account deletion:', error.message);
            }
        } else if (req.user?.authProvider === 'apple') {
            console.warn('Account deletion: no stored Apple refresh token to revoke');
        }

        const decisionsRemoved = await decisionStore.deleteByUser(req.userKey);
        const userRemoved = req.user ? await userStore.deleteUser(req.user.id) : false;

        // The Google-token cache would otherwise keep resolving a revoked token
        if (req.authTokens?.access_token) {
            googleUserKeys.delete(crypto.createHash('sha256').update(req.authTokens.access_token).digest('hex'));
        }

        console.log(`Account deleted: decisions=${decisionsRemoved} userRow=${userRemoved}`);
        res.json({ success: true, message: 'Account deleted' });
    } catch (error) {
        console.error('Error deleting account:', error);
        sendError(res, 500, CODES.SERVER_INTERNAL_ERROR, 'Could not delete your account. Please try again.');
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

// Get statistics endpoint — per user, so it needs the same auth as decisions
app.get('/api/stats', authenticateRequest, async (req, res) => {
    try {
        const stats = await decisionStore.getStats(req.userKey);

        res.json({ success: true, stats });
    } catch (error) {
        console.error('Error getting stats:', error);
        sendError(res, 500, CODES.SERVER_INTERNAL_ERROR, 'Something went wrong on our side. Please try again.');
    }
});

// Start server once the schema exists — a half-booted server would 500 on every request
db.initSchema().then(async () => {
    const sealed = await userStore.encryptLegacyTokens();
    if (sealed > 0) {
        console.log(`Encrypted ${sealed} legacy plaintext Gmail token row(s)`);
    }

    // Bind to 0.0.0.0 so Railway's reverse proxy can reach the container
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Unpile server running on port ${PORT}`);
        if (!hasGmailCredentials()) {
            console.log('\n⚠️  Gmail credentials not configured!');
            console.log('Please set up your .env file with Gmail OAuth credentials.');
            console.log('See .env.example for details.\n');
        }
    });
});
