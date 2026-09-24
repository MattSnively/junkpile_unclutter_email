const crypto = require('crypto');
const { google } = require('googleapis');

function createOAuthClient() {
    return new google.auth.OAuth2(
        process.env.GMAIL_CLIENT_ID,
        process.env.GMAIL_CLIENT_SECRET,
        process.env.GMAIL_REDIRECT_URI || 'http://localhost:3000/auth/google/callback'
    );
}

/**
 * A fresh OAuth2 client carrying one request's tokens. googleapis reads
 * credentials when each API call is sent, so setting them on a shared client
 * lets an overlapping request from another user swap in their token between
 * our set and our call — returning the wrong inbox.
 *
 * @param {Object} tokens - { access_token, refresh_token?, ... }
 * @returns {OAuth2Client}
 */
function oauthClientFor(tokens) {
    const client = createOAuthClient();
    client.setCredentials(tokens);
    return client;
}

// sha256(access_token) -> { scope, expiresAt }. Lives as long as the token, so
// each token costs one tokeninfo call rather than one per request.
const grantedScopes = new Map();

function tokenKey(accessToken) {
    return crypto.createHash('sha256').update(accessToken).digest('hex');
}

/**
 * Returns the tokens with `scope` filled in, so GmailService can tell whether
 * the user granted gmail.send (they can decline it on the consent screen).
 * Google Sign-In users only ever hand us a bare access token, so the scope is
 * looked up from Google's tokeninfo endpoint when it isn't already stored.
 *
 * Never throws: if the lookup fails, the tokens come back unchanged and the
 * mailto fallback simply stays off for this request.
 *
 * @param {Object|null} tokens - { access_token, scope?, ... }
 * @returns {Promise<Object|null>}
 */
async function withGrantedScope(tokens) {
    if (!tokens?.access_token || tokens.scope) return tokens;

    const key = tokenKey(tokens.access_token);
    const cached = grantedScopes.get(key);
    if (cached && cached.expiresAt > Date.now()) {
        return { ...tokens, scope: cached.scope };
    }

    try {
        const response = await fetch(
            `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(tokens.access_token)}`
        );
        if (!response.ok) return tokens;
        const info = await response.json();
        if (!info.scope) return tokens;

        for (const [cachedKey, entry] of grantedScopes) {
            if (entry.expiresAt <= Date.now()) grantedScopes.delete(cachedKey);
        }
        const lifetimeMs = (Number(info.expires_in) || 0) * 1000;
        grantedScopes.set(key, { scope: info.scope, expiresAt: Date.now() + lifetimeMs });
        return { ...tokens, scope: info.scope };
    } catch (error) {
        console.error('Scope lookup failed:', error.message);
        return tokens;
    }
}

module.exports = { createOAuthClient, oauthClientFor, withGrantedScope };
