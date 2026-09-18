/**
 * Unit tests for appleAuth — verification of Apple Sign-In identity tokens.
 *
 * Apple's JWKS endpoint is mocked with a locally generated RSA keypair, so
 * signatures are really verified rather than stubbed past. Accepting a token
 * that fails any of these checks would let a caller sign in as anyone.
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const mockGetSigningKey = jest.fn();
jest.mock('jwks-rsa', () => () => ({ getSigningKey: mockGetSigningKey }));

const BUNDLE_ID = 'com.junkpile.app';
const ISSUER = 'https://appleid.apple.com';
const APPLE_USER_ID = '001234.abcdef.5678';

let keyPair;
let otherKeyPair;
let verifyAppleToken;

function signToken(payload, { key = keyPair.privateKey, ...options } = {}) {
    return jwt.sign(payload, key, {
        algorithm: 'RS256',
        issuer: ISSUER,
        audience: BUNDLE_ID,
        expiresIn: '10m',
        keyid: 'test-kid',
        ...options
    });
}

beforeAll(() => {
    const generate = () => crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
    keyPair = generate();
    otherKeyPair = generate();

    process.env.APPLE_BUNDLE_ID = BUNDLE_ID;
    ({ verifyAppleToken } = require('../appleAuth'));
});

beforeEach(() => {
    mockGetSigningKey.mockReset();
    mockGetSigningKey.mockImplementation((kid, callback) =>
        callback(null, { getPublicKey: () => keyPair.publicKey }));
});

describe('verifyAppleToken', () => {
    test('returns the payload for a valid token', async () => {
        const decoded = await verifyAppleToken(signToken({ sub: APPLE_USER_ID, email: 'a@privaterelay.appleid.com' }));

        expect(decoded).toMatchObject({
            sub: APPLE_USER_ID,
            email: 'a@privaterelay.appleid.com',
            iss: ISSUER,
            aud: BUNDLE_ID
        });
    });

    test('looks up the signing key by the kid in the token header', async () => {
        await verifyAppleToken(signToken({ sub: APPLE_USER_ID }));

        expect(mockGetSigningKey).toHaveBeenCalledWith('test-kid', expect.any(Function));
    });

    test('rejects a token signed by a different key', async () => {
        const forged = signToken({ sub: 'attacker' }, { key: otherKeyPair.privateKey });

        await expect(verifyAppleToken(forged)).rejects.toThrow('Apple token verification failed');
    });

    test('rejects a token minted for another app', async () => {
        const wrongAudience = signToken({ sub: APPLE_USER_ID }, { audience: 'com.someone.else' });

        await expect(verifyAppleToken(wrongAudience)).rejects.toThrow('Apple token verification failed');
    });

    test('rejects a token from another issuer', async () => {
        const wrongIssuer = signToken({ sub: APPLE_USER_ID }, { issuer: 'https://evil.example.com' });

        await expect(verifyAppleToken(wrongIssuer)).rejects.toThrow('Apple token verification failed');
    });

    test('rejects an expired token', async () => {
        const expired = signToken({ sub: APPLE_USER_ID }, { expiresIn: '-1s' });

        await expect(verifyAppleToken(expired)).rejects.toThrow('Apple token verification failed');
    });

    test('rejects an HS256 token signed with Apple\'s public key', async () => {
        // Algorithm confusion: treat the public key as an HMAC secret and the
        // attacker can mint tokens. jsonwebtoken v9 refuses a PEM as an HMAC
        // key, so this passes even without our allowlist — the RS512 case below
        // is what pins the allowlist itself.
        const confused = jwt.sign({ sub: 'attacker' }, keyPair.publicKey, {
            algorithm: 'HS256',
            issuer: ISSUER,
            audience: BUNDLE_ID,
            expiresIn: '10m',
            keyid: 'test-kid'
        });

        await expect(verifyAppleToken(confused)).rejects.toThrow('Apple token verification failed');
    });

    test('accepts RS256 only, not other RSA algorithms', async () => {
        // Fails if the algorithms allowlist is widened or dropped
        const rs512 = signToken({ sub: APPLE_USER_ID }, { algorithm: 'RS512' });

        await expect(verifyAppleToken(rs512)).rejects.toThrow('Apple token verification failed');
    });

    test('rejects a token whose header cannot be decoded', async () => {
        await expect(verifyAppleToken('not-a-jwt')).rejects.toThrow('unable to decode header');
    });

    test('surfaces a JWKS lookup failure', async () => {
        mockGetSigningKey.mockImplementation((kid, callback) => callback(new Error('network down')));

        await expect(verifyAppleToken(signToken({ sub: APPLE_USER_ID })))
            .rejects.toThrow('Failed to get Apple signing key: network down');
    });
});
