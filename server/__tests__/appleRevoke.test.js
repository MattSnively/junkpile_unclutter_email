/**
 * Unit tests for appleRevoke — Sign in with Apple code exchange and revocation.
 *
 * fetch is mocked; the client secret is signed with a locally generated P-256
 * key and verified for real, since Apple rejects anything with a wrong claim
 * and we would only find out in production.
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const TEAM_ID = 'TEAM123456';
const KEY_ID = 'KEY1234567';
const BUNDLE_ID = 'com.junkpile.app';

let keyPair;
let appleRevoke;

beforeAll(() => {
    keyPair = crypto.generateKeyPairSync('ec', {
        namedCurve: 'P-256',
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
    appleRevoke = require('../appleRevoke');
});

beforeEach(() => {
    process.env.APPLE_TEAM_ID = TEAM_ID;
    process.env.APPLE_KEY_ID = KEY_ID;
    process.env.APPLE_PRIVATE_KEY = keyPair.privateKey;
    delete process.env.APPLE_BUNDLE_ID;
    global.fetch = jest.fn();
});

afterEach(() => {
    delete process.env.APPLE_TEAM_ID;
    delete process.env.APPLE_KEY_ID;
    delete process.env.APPLE_PRIVATE_KEY;
});

function sentForm(call = 0) {
    const [url, options] = global.fetch.mock.calls[call];
    return { url, params: Object.fromEntries(new URLSearchParams(options.body)) };
}

describe('createClientSecret', () => {
    test('is an ES256 JWT carrying the claims Apple checks', () => {
        const secret = appleRevoke.createClientSecret();
        const decoded = jwt.verify(secret, keyPair.publicKey, {
            algorithms: ['ES256'],
            complete: true
        });

        expect(decoded.header.kid).toBe(KEY_ID);
        expect(decoded.payload).toMatchObject({
            iss: TEAM_ID,
            sub: BUNDLE_ID,
            aud: 'https://appleid.apple.com'
        });
        // Apple caps client secrets at six months; ours should be minutes
        expect(decoded.payload.exp - decoded.payload.iat).toBeLessThanOrEqual(300);
    });

    test('accepts a key stored on one line with literal \\n', () => {
        process.env.APPLE_PRIVATE_KEY = keyPair.privateKey.replace(/\n/g, '\\n');
        const secret = appleRevoke.createClientSecret();
        expect(() => jwt.verify(secret, keyPair.publicKey, { algorithms: ['ES256'] })).not.toThrow();
    });
});

describe('exchangeAuthorizationCode', () => {
    test('posts the code and returns the refresh token', async () => {
        global.fetch.mockResolvedValue({
            ok: true,
            json: async () => ({ refresh_token: 'r.apple.token', access_token: 'a' })
        });

        await expect(appleRevoke.exchangeAuthorizationCode('auth-code')).resolves.toBe('r.apple.token');

        const { url, params } = sentForm();
        expect(url).toBe('https://appleid.apple.com/auth/token');
        expect(params).toMatchObject({
            client_id: BUNDLE_ID,
            code: 'auth-code',
            grant_type: 'authorization_code'
        });
        expect(params.client_secret).toBeTruthy();
    });

    test('throws on a non-2xx response so the caller can log it', async () => {
        global.fetch.mockResolvedValue({ ok: false, status: 400 });
        await expect(appleRevoke.exchangeAuthorizationCode('used-code')).rejects.toThrow('400');
    });

    test('is a no-op without Apple credentials', async () => {
        delete process.env.APPLE_PRIVATE_KEY;
        await expect(appleRevoke.exchangeAuthorizationCode('auth-code')).resolves.toBeNull();
        expect(global.fetch).not.toHaveBeenCalled();
    });
});

describe('revokeAppleToken', () => {
    test('posts the refresh token to Apple\'s revoke endpoint', async () => {
        global.fetch.mockResolvedValue({ ok: true });

        await expect(appleRevoke.revokeAppleToken('r.apple.token')).resolves.toBe(true);

        const { url, params } = sentForm();
        expect(url).toBe('https://appleid.apple.com/auth/revoke');
        expect(params).toMatchObject({
            client_id: BUNDLE_ID,
            token: 'r.apple.token',
            token_type_hint: 'refresh_token'
        });
    });

    test('throws on a non-2xx response', async () => {
        global.fetch.mockResolvedValue({ ok: false, status: 400 });
        await expect(appleRevoke.revokeAppleToken('r.apple.token')).rejects.toThrow('400');
    });

    test('is a no-op without Apple credentials', async () => {
        delete process.env.APPLE_TEAM_ID;
        await expect(appleRevoke.revokeAppleToken('r.apple.token')).resolves.toBe(false);
        expect(global.fetch).not.toHaveBeenCalled();
    });
});
