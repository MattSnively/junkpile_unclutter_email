/**
 * Unit tests for sessionToken — the bearer tokens issued to Apple Sign-In
 * users. A forged or confused token here would hand over another user's
 * account, so the rejection paths matter more than the happy path.
 */

process.env.JWT_SECRET = 'test-jwt-secret';

const jwt = require('jsonwebtoken');
const { generateSessionToken, verifySessionToken } = require('../sessionToken');

const SECRET = 'test-jwt-secret';
const USER_ID = '11111111-2222-3333-4444-555555555555';

describe('generateSessionToken', () => {
    test('carries the user id, provider, and session type', () => {
        const decoded = jwt.verify(generateSessionToken(USER_ID, 'apple'), SECRET);

        expect(decoded).toMatchObject({ userId: USER_ID, provider: 'apple', type: 'session' });
    });

    test('sets a 7-day expiry', () => {
        const decoded = jwt.verify(generateSessionToken(USER_ID, 'apple'), SECRET);
        const sevenDays = 7 * 24 * 60 * 60;

        expect(decoded.exp - decoded.iat).toBe(sevenDays);
    });
});

describe('verifySessionToken', () => {
    test('round-trips a freshly issued token', () => {
        const payload = verifySessionToken(generateSessionToken(USER_ID, 'apple'));

        expect(payload).toMatchObject({ userId: USER_ID, provider: 'apple' });
    });

    test('rejects a token signed with a different secret', () => {
        const forged = jwt.sign({ userId: 'attacker', type: 'session' }, 'not-the-secret');

        expect(verifySessionToken(forged)).toBeNull();
    });

    test('rejects a tampered payload', () => {
        const [header, , signature] = generateSessionToken(USER_ID, 'apple').split('.');
        const swapped = Buffer.from(JSON.stringify({ userId: 'attacker', type: 'session' }))
            .toString('base64url');

        expect(verifySessionToken(`${header}.${swapped}.${signature}`)).toBeNull();
    });

    test('rejects an expired token', () => {
        const expired = jwt.sign({ userId: USER_ID, type: 'session' }, SECRET, { expiresIn: '-1s' });

        expect(verifySessionToken(expired)).toBeNull();
    });

    test('rejects a correctly signed JWT that is not a session token', () => {
        // Guards against another of our own JWTs being replayed as a session
        const otherType = jwt.sign({ userId: USER_ID, type: 'refresh' }, SECRET);

        expect(verifySessionToken(otherType)).toBeNull();
        expect(verifySessionToken(jwt.sign({ userId: USER_ID }, SECRET))).toBeNull();
    });

    test('rejects an unsigned (alg=none) token', () => {
        const unsigned = `${Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url')}.`
            + `${Buffer.from(JSON.stringify({ userId: 'attacker', type: 'session' })).toString('base64url')}.`;

        expect(verifySessionToken(unsigned)).toBeNull();
    });

    test.each([['garbage'], [''], [null], [undefined]])('rejects %p', (input) => {
        expect(verifySessionToken(input)).toBeNull();
    });
});
