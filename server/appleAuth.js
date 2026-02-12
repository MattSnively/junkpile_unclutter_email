/**
 * appleAuth.js — Apple Sign-In JWT verification utility.
 *
 * Verifies Apple identity tokens by fetching Apple's public keys (JWKS)
 * and validating the JWT signature, issuer, and audience. Returns the
 * decoded payload containing the user's Apple ID (`sub`) and email.
 *
 * Apple's JWKS endpoint: https://appleid.apple.com/auth/keys
 * Apple's issuer: https://appleid.apple.com
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// JWKS client configured to fetch Apple's public signing keys.
// Keys are cached for 1 hour to avoid hitting Apple's endpoint on every request.
const client = jwksClient({
    jwksUri: 'https://appleid.apple.com/auth/keys',
    cache: true,
    cacheMaxAge: 3600000, // 1 hour in milliseconds
    rateLimit: true,
    jwksRequestsPerMinute: 10
});

/**
 * Retrieves the signing key from Apple's JWKS endpoint that matches
 * the `kid` (Key ID) in the JWT header.
 *
 * @param {Object} header - The decoded JWT header containing `kid`
 * @returns {Promise<string>} The public key or certificate in PEM format
 */
function getAppleSigningKey(header) {
    return new Promise((resolve, reject) => {
        client.getSigningKey(header.kid, (err, key) => {
            if (err) {
                reject(new Error(`Failed to get Apple signing key: ${err.message}`));
                return;
            }
            // getPublicKey() returns PEM-encoded key for signature verification
            const signingKey = key.getPublicKey();
            resolve(signingKey);
        });
    });
}

/**
 * Verifies an Apple identity token (JWT) and returns the decoded payload.
 *
 * Verification checks:
 * 1. Signature — matches one of Apple's current public keys
 * 2. Issuer — must be "https://appleid.apple.com"
 * 3. Audience — must match our app's bundle ID
 * 4. Expiration — token must not be expired
 *
 * @param {string} identityToken - The JWT identity token from Apple Sign-In
 * @returns {Promise<Object>} Decoded token payload with `sub`, `email`, etc.
 * @throws {Error} If the token is invalid, expired, or verification fails
 */
async function verifyAppleToken(identityToken) {
    // The expected audience is the app's bundle ID, configured via environment variable
    const bundleId = process.env.APPLE_BUNDLE_ID || 'com.junkpile.app';

    // Decode the header first (without verification) to get the `kid`
    const decodedHeader = jwt.decode(identityToken, { complete: true });
    if (!decodedHeader || !decodedHeader.header) {
        throw new Error('Invalid Apple identity token: unable to decode header');
    }

    // Fetch the matching public key from Apple's JWKS endpoint
    const signingKey = await getAppleSigningKey(decodedHeader.header);

    // Verify the token with full validation: signature, issuer, audience, expiry
    return new Promise((resolve, reject) => {
        jwt.verify(
            identityToken,
            signingKey,
            {
                algorithms: ['RS256'],       // Apple uses RS256
                issuer: 'https://appleid.apple.com',
                audience: bundleId
            },
            (err, decoded) => {
                if (err) {
                    reject(new Error(`Apple token verification failed: ${err.message}`));
                    return;
                }
                resolve(decoded);
            }
        );
    });
}

module.exports = { verifyAppleToken };
