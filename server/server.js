require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { google } = require('googleapis');
const GmailService = require('./gmailService');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(session({
    secret: process.env.SESSION_SECRET || 'junkpile-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false } // Set to true if using HTTPS
}));
app.use(express.static(path.join(__dirname, '../public')));

// Data file path
const DATA_FILE = path.join(__dirname, '../data/decisions.json');

// OAuth2 Client
const oauth2Client = new google.auth.OAuth2(
    process.env.GMAIL_CLIENT_ID,
    process.env.GMAIL_CLIENT_SECRET,
    process.env.GMAIL_REDIRECT_URI || 'http://localhost:3000/auth/google/callback'
);

// Initialize data file
async function initDataFile() {
    try {
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
        // Exchange the authorization code for tokens
        const { tokens } = await oauth2Client.getToken(code);

        // Get user info to return email
        oauth2Client.setCredentials(tokens);
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        // Return tokens to the mobile app
        // The app should store these securely in Keychain (iOS) or Keystore (Android)
        res.json({
            success: true,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_in: tokens.expiry_date
                ? Math.floor((tokens.expiry_date - Date.now()) / 1000)
                : 3600,
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
 * Mobile apps call this when their access token expires.
 */
app.post('/api/auth/refresh', async (req, res) => {
    const { refresh_token } = req.body;

    // Validate required parameters
    if (!refresh_token) {
        return res.status(400).json({
            success: false,
            error: 'Refresh token is required'
        });
    }

    try {
        // Set the refresh token and request a new access token
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

    const accessToken = authHeader.substring(7); // Remove 'Bearer ' prefix

    try {
        // Set credentials and verify by fetching user info
        oauth2Client.setCredentials({ access_token: accessToken });
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        res.json({
            valid: true,
            email: userInfo.data.email,
            name: userInfo.data.name,
            picture: userInfo.data.picture
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
// Helper middleware for mobile authentication
// Extracts Bearer token and sets up oauth2Client for authenticated endpoints
// =============================================================================

/**
 * Middleware to handle both session-based (web) and token-based (mobile) auth.
 * Checks for Bearer token first, falls back to session tokens.
 */
function authenticateRequest(req, res, next) {
    // Check for Bearer token (mobile)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const accessToken = authHeader.substring(7);
        req.authTokens = { access_token: accessToken };
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
            'https://www.googleapis.com/auth/gmail.modify'
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

        // If unsubscribe, process it using tokens from middleware
        if (decision === 'unsubscribe' && req.authTokens) {
            oauth2Client.setCredentials(req.authTokens);
            const gmailService = new GmailService(oauth2Client);

            // Get the email to find unsubscribe URL
            const emailDetails = await gmailService.getEmailDetails(emailId);
            if (emailDetails && emailDetails.unsubscribeUrl) {
                await gmailService.unsubscribe(emailId, emailDetails.unsubscribeUrl);
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

        // Add decision
        currentSession.decisions.push({
            emailId,
            decision,
            timestamp: new Date().toISOString()
        });

        // Save data
        await fs.writeFile(DATA_FILE, JSON.stringify(jsonData, null, 2));

        res.json({
            success: true,
            message: decision === 'unsubscribe' ? 'Unsubscribed successfully' : 'Email kept'
        });
    } catch (error) {
        console.error('Error saving decision:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Logout endpoint
app.post('/api/logout', (req, res) => {
    req.session.destroy();
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

// Start server
initDataFile().then(() => {
    app.listen(PORT, () => {
        console.log(`Junkpile server running on http://localhost:${PORT}`);
        if (!hasGmailCredentials()) {
            console.log('\n⚠️  Gmail credentials not configured!');
            console.log('Please set up your .env file with Gmail OAuth credentials.');
            console.log('See .env.example for details.\n');
        }
    });
});
