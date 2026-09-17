/**
 * tokenCrypto.js — AES-256-GCM encryption for Gmail OAuth tokens at rest.
 *
 * A leaked database dump must not yield usable refresh tokens, so the token
 * blob is encrypted before it reaches Postgres and decrypted on read. The key
 * lives only in TOKEN_ENCRYPTION_KEY (32 bytes, hex). The stored value is a
 * small self-describing object so it fits the existing JSONB column and a
 * future key rotation can bump `v`.
 */

const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;

function loadKey() {
    const hex = process.env.TOKEN_ENCRYPTION_KEY;
    if (!hex || !/^[0-9a-fA-F]{64}$/.test(hex)) {
        throw new Error('TOKEN_ENCRYPTION_KEY must be 32 bytes as 64 hex chars — generate with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"');
    }
    return Buffer.from(hex, 'hex');
}

const key = loadKey();

/**
 * @param {Object|null} tokens - Plain token object, or null
 * @returns {{v: number, iv: string, tag: string, data: string}|null}
 */
function encryptTokens(tokens) {
    if (tokens == null) return null;

    const iv = crypto.randomBytes(IV_BYTES);
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    const data = Buffer.concat([
        cipher.update(JSON.stringify(tokens), 'utf8'),
        cipher.final()
    ]);

    return {
        v: 1,
        iv: iv.toString('base64'),
        tag: cipher.getAuthTag().toString('base64'),
        data: data.toString('base64')
    };
}

/**
 * @param {{v: number, iv: string, tag: string, data: string}|null} sealed
 * @returns {Object|null} The original token object, or null
 * @throws if the ciphertext or tag was tampered with
 */
function decryptTokens(sealed) {
    if (sealed == null) return null;
    if (sealed.v !== 1) {
        throw new Error(`Unsupported token envelope version ${sealed.v}`);
    }

    const decipher = crypto.createDecipheriv(ALGORITHM, key, Buffer.from(sealed.iv, 'base64'));
    decipher.setAuthTag(Buffer.from(sealed.tag, 'base64'));
    const plain = Buffer.concat([
        decipher.update(Buffer.from(sealed.data, 'base64')),
        decipher.final()
    ]);

    return JSON.parse(plain.toString('utf8'));
}

module.exports = { encryptTokens, decryptTokens };
