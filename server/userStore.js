/**
 * userStore.js — Postgres-backed user storage.
 *
 * Each user has an identity provider (Apple or Google) and optional Gmail
 * OAuth tokens for inbox access. Rows are mapped to the camelCase record
 * shape below so callers never see column names.
 *
 * User record shape:
 * {
 *   id: string (UUID),
 *   appleUserId: string | null,    // Apple's `sub` claim (stable user ID)
 *   email: string,                 // User's email (from Apple or Google)
 *   name: string | null,           // Display name
 *   authProvider: "apple" | "google",
 *   gmailTokens: {                 // Present after Gmail is connected
 *     access_token: string,
 *     refresh_token: string,
 *     expiry_date: number
 *   } | null,
 *   gmailEmail: string | null,     // Gmail address (may differ from Apple email)
 *   createdAt: string (ISO),
 *   lastLoginAt: string (ISO)
 * }
 */

const crypto = require('crypto');
const { pool } = require('./db');

// Record field -> column. Doubles as the allowlist for updateUser, so a typo
// in a caller fails loudly instead of silently being dropped.
const COLUMNS = {
    appleUserId: 'apple_user_id',
    email: 'email',
    name: 'name',
    authProvider: 'auth_provider',
    gmailTokens: 'gmail_tokens',
    gmailEmail: 'gmail_email',
    lastLoginAt: 'last_login_at'
};

function rowToUser(row) {
    if (!row) return null;
    return {
        id: row.id,
        appleUserId: row.apple_user_id,
        email: row.email,
        name: row.name,
        authProvider: row.auth_provider,
        gmailTokens: row.gmail_tokens,
        gmailEmail: row.gmail_email,
        createdAt: row.created_at.toISOString(),
        lastLoginAt: row.last_login_at.toISOString()
    };
}

/**
 * Finds a user by their Apple user ID (the `sub` claim from Apple's JWT).
 * This is the stable identifier across Apple Sign-In sessions.
 *
 * @param {string} appleUserId - Apple's user identifier
 * @returns {Promise<Object|null>} User record or null if not found
 */
async function findByAppleId(appleUserId) {
    const { rows } = await pool.query('SELECT * FROM users WHERE apple_user_id = $1', [appleUserId]);
    return rowToUser(rows[0]);
}

/**
 * Finds a user by their server-side user ID (UUID).
 *
 * @param {string} userId - Server-generated UUID
 * @returns {Promise<Object|null>} User record or null if not found
 */
async function findById(userId) {
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    return rowToUser(rows[0]);
}

/**
 * Finds a user by email address.
 * Note: email is NOT a unique identifier since Apple relay emails
 * may differ from Gmail addresses.
 *
 * @param {string} email - Email address to search for
 * @returns {Promise<Object|null>} User record or null if not found
 */
async function findByEmail(email) {
    const { rows } = await pool.query('SELECT * FROM users WHERE email = $1 LIMIT 1', [email]);
    return rowToUser(rows[0]);
}

/**
 * Creates a new user record and persists it.
 *
 * @param {Object} userData - User data to store
 * @param {string} [userData.appleUserId] - Apple's user identifier
 * @param {string} userData.email - User's email address
 * @param {string} [userData.name] - User's display name
 * @param {string} userData.authProvider - "apple" or "google"
 * @returns {Promise<Object>} The created user record with generated ID and timestamps
 */
async function createUser(userData) {
    const { rows } = await pool.query(
        `INSERT INTO users (id, apple_user_id, email, name, auth_provider, gmail_tokens, gmail_email)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [
            crypto.randomUUID(),
            userData.appleUserId || null,
            userData.email,
            userData.name || null,
            userData.authProvider,
            userData.gmailTokens || null,
            userData.gmailEmail || null
        ]
    );
    return rowToUser(rows[0]);
}

/**
 * Updates an existing user record by ID.
 * Merges the provided fields with the existing record.
 *
 * @param {string} userId - The user's server-side ID
 * @param {Object} updates - Fields to update (partial update)
 * @returns {Promise<Object|null>} Updated user record, or null if user not found
 */
async function updateUser(userId, updates) {
    const assignments = [];
    const values = [userId];

    for (const [field, value] of Object.entries(updates)) {
        const column = COLUMNS[field];
        if (!column) {
            throw new Error(`updateUser: unknown field "${field}"`);
        }
        values.push(value);
        assignments.push(`${column} = $${values.length}`);
    }

    if (assignments.length === 0) {
        return findById(userId);
    }

    const { rows } = await pool.query(
        `UPDATE users SET ${assignments.join(', ')} WHERE id = $1 RETURNING *`,
        values
    );
    return rowToUser(rows[0]);
}

/**
 * Deletes a user record by ID. Used for account deletion.
 *
 * @param {string} userId - The user's server-side ID
 * @returns {Promise<boolean>} True if user was found and deleted
 */
async function deleteUser(userId) {
    const { rowCount } = await pool.query('DELETE FROM users WHERE id = $1', [userId]);
    return rowCount > 0;
}

module.exports = {
    findByAppleId,
    findById,
    findByEmail,
    createUser,
    updateUser,
    deleteUser
};
