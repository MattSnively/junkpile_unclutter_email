/**
 * appleRevoke.js — Sign in with Apple token exchange and revocation.
 *
 * App Review 5.1.1(v) requires apps offering Sign in with Apple to revoke the
 * user's Apple tokens when they delete their account. Revocation needs a
 * refresh token, which Apple only issues in exchange for the one-time
 * authorization code the app sends at sign-in — so we exchange and keep it
 * then, and spend it at deletion.
 *
 * Both calls authenticate with a client secret: a short-lived ES256 JWT signed
 * with the Sign in with Apple key (.p8) from the developer portal.
 *
 * Without APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY set, everything here
 * is a no-op so local dev and CI run without Apple credentials.
 */

const jwt = require('jsonwebtoken');

const APPLE_AUTH_BASE = 'https://appleid.apple.com';

function isConfigured() {
    return Boolean(
        process.env.APPLE_TEAM_ID &&
        process.env.APPLE_KEY_ID &&
        process.env.APPLE_PRIVATE_KEY
    );
}

// Must match the audience appleAuth.js verifies identity tokens against.
function clientId() {
    return process.env.APPLE_BUNDLE_ID || 'com.junkpile.app';
}

/**
 * Builds the client secret JWT Apple requires on /auth/token and /auth/revoke.
 * Minted per call with a 5-minute lifetime rather than cached: calls are rare
 * (sign-in and deletion), and a short-lived secret is one less thing to leak.
 */
function createClientSecret() {
    // Railway and .env files often hold the .p8 on one line with literal "\n"
    const privateKey = process.env.APPLE_PRIVATE_KEY.replace(/\\n/g, '\n');
    return jwt.sign({}, privateKey, {
        algorithm: 'ES256',
        keyid: process.env.APPLE_KEY_ID,
        issuer: process.env.APPLE_TEAM_ID,
        audience: APPLE_AUTH_BASE,
        subject: clientId(),
        expiresIn: '5m'
    });
}

async function postForm(path, params) {
    return fetch(`${APPLE_AUTH_BASE}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
            client_id: clientId(),
            client_secret: createClientSecret(),
            ...params
        }).toString()
    });
}

/**
 * Exchanges a sign-in authorization code for Apple's refresh token.
 * Codes are single-use and expire after five minutes.
 *
 * @param {string} code - authorizationCode from the iOS Sign in with Apple credential
 * @returns {Promise<string|null>} Refresh token, or null when Apple is not configured
 */
async function exchangeAuthorizationCode(code) {
    if (!isConfigured()) return null;

    const response = await postForm('/auth/token', {
        code,
        grant_type: 'authorization_code'
    });
    if (!response.ok) {
        throw new Error(`Apple token exchange returned ${response.status}`);
    }
    const body = await response.json();
    return body.refresh_token || null;
}

/**
 * Revokes a user's Apple refresh token, severing the app's link to their
 * Apple ID (it disappears from their "Sign in with Apple" app list).
 *
 * @param {string} refreshToken
 * @returns {Promise<boolean>} True if revoked, false when Apple is not configured
 */
async function revokeAppleToken(refreshToken) {
    if (!isConfigured()) return false;

    const response = await postForm('/auth/revoke', {
        token: refreshToken,
        token_type_hint: 'refresh_token'
    });
    if (!response.ok) {
        throw new Error(`Apple revoke returned ${response.status}`);
    }
    return true;
}

module.exports = {
    isConfigured,
    createClientSecret,
    exchangeAuthorizationCode,
    revokeAppleToken
};
