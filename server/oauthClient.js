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

module.exports = { createOAuthClient, oauthClientFor };
