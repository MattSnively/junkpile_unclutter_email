/**
 * Unit tests for tokenCrypto — AES-256-GCM envelope for Gmail tokens.
 */

process.env.TOKEN_ENCRYPTION_KEY = 'a'.repeat(64);
const { encryptTokens, decryptTokens } = require('../tokenCrypto');

describe('tokenCrypto', () => {
    const tokens = { access_token: 'ya29.abc', refresh_token: '1//rt', expiry_date: 1758000000000 };

    test('round-trips a token object', () => {
        expect(decryptTokens(encryptTokens(tokens))).toEqual(tokens);
    });

    test('envelope carries no plaintext and uses a fresh IV each time', () => {
        const a = encryptTokens(tokens);
        const b = encryptTokens(tokens);

        expect(a).toEqual({ v: 1, iv: expect.any(String), tag: expect.any(String), data: expect.any(String) });
        expect(JSON.stringify(a)).not.toContain('ya29');
        expect(JSON.stringify(a)).not.toContain('1//rt');
        expect(a.iv).not.toBe(b.iv);
        expect(a.data).not.toBe(b.data);
    });

    test('null passes through both directions', () => {
        expect(encryptTokens(null)).toBeNull();
        expect(decryptTokens(null)).toBeNull();
    });

    test('tampered ciphertext fails authentication', () => {
        const sealed = encryptTokens(tokens);
        const bytes = Buffer.from(sealed.data, 'base64');
        bytes[0] ^= 0xff;
        sealed.data = bytes.toString('base64');

        expect(() => decryptTokens(sealed)).toThrow();
    });

    test('tampered tag fails authentication', () => {
        const sealed = encryptTokens(tokens);
        const bytes = Buffer.from(sealed.tag, 'base64');
        bytes[0] ^= 0xff;
        sealed.tag = bytes.toString('base64');

        expect(() => decryptTokens(sealed)).toThrow();
    });

    test('rejects an unknown envelope version', () => {
        const sealed = { ...encryptTokens(tokens), v: 2 };
        expect(() => decryptTokens(sealed)).toThrow('Unsupported token envelope version');
    });
});

describe('tokenCrypto key validation', () => {
    test('refuses to load without a 64-hex-char key', () => {
        jest.isolateModules(() => {
            process.env.TOKEN_ENCRYPTION_KEY = 'too-short';
            expect(() => require('../tokenCrypto')).toThrow('TOKEN_ENCRYPTION_KEY');
        });
        process.env.TOKEN_ENCRYPTION_KEY = 'a'.repeat(64);
    });
});
