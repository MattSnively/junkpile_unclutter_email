/**
 * sessionToken.js — Server-side JWT session token utilities.
 *
 * After verifying an Apple identity token, we issue our own longer-lived
 * session token (7-day expiry). Apple identity tokens are short-lived
 * (~10 minutes), so this gives the iOS app a stable bearer token for
 * subsequent API requests without needing to re-authenticate with Apple.
 *
 * The JWT_SECRET environment variable MUST be set in production.
 */

const jwt = require('jsonwebtoken');

// Secret used to sign and verify server session tokens.
// Falls back to a development-only default — MUST be overridden in production.
const JWT_SECRET = process.env.JWT_SECRET || 'junkpile-dev-jwt-secret';

// Session tokens expire after 7 days. Users will need to re-authenticate after this.
const TOKEN_EXPIRY = '7d';

/**
 * Generates a signed JWT session token for an authenticated user.
 *
 * The token payload contains only the user ID and auth provider —
 * enough to look up the full user record on each request.
 *
 * @param {string} userId - The server-side user ID (UUID)
 * @param {string} provider - The auth provider ("apple" or "google")
 * @returns {string} Signed JWT session token
 */
function generateSessionToken(userId, provider) {
    const payload = {
        userId,
        provider,
        type: 'session' // Distinguishes this from Apple identity tokens
    };

    return jwt.sign(payload, JWT_SECRET, { expiresIn: TOKEN_EXPIRY });
}

/**
 * Verifies a server session token and returns the decoded payload.
 *
 * @param {string} token - The JWT session token to verify
 * @returns {Object|null} Decoded payload if valid, null if invalid/expired
 */
function verifySessionToken(token) {
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        // Ensure this is actually a session token (not some other JWT)
        if (decoded.type !== 'session') {
            return null;
        }
        return decoded;
    } catch {
        // Token is invalid, expired, or tampered with
        return null;
    }
}

module.exports = { generateSessionToken, verifySessionToken };
