/**
 * userStore.js — Simple JSON file-based user storage.
 *
 * Stores user records in data/users.json, matching the existing pattern
 * used by data/decisions.json. Each user has an identity provider
 * (Apple or Google) and optional Gmail OAuth tokens for inbox access.
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

const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// User data file path — stored alongside decisions.json in the data/ directory
const USERS_FILE = path.join(__dirname, '../data/users.json');

/**
 * Ensures the users.json file exists. Creates it with an empty array if missing.
 * Called once at server startup.
 */
async function initUsersFile() {
    try {
        // Ensure the data/ directory exists (gitignored, won't be in the repo)
        const dataDir = path.dirname(USERS_FILE);
        await fs.mkdir(dataDir, { recursive: true });

        await fs.access(USERS_FILE);
    } catch {
        // File doesn't exist — create it with empty users array
        await fs.writeFile(USERS_FILE, JSON.stringify({ users: [] }, null, 2));
    }
}

/**
 * Reads all users from the JSON file.
 * @returns {Promise<Array>} Array of user objects
 */
async function readUsers() {
    const data = await fs.readFile(USERS_FILE, 'utf8');
    const parsed = JSON.parse(data);
    return parsed.users || [];
}

/**
 * Writes the full users array back to the JSON file.
 * @param {Array} users - Complete array of user objects to persist
 */
async function writeUsers(users) {
    await fs.writeFile(USERS_FILE, JSON.stringify({ users }, null, 2));
}

/**
 * Finds a user by their Apple user ID (the `sub` claim from Apple's JWT).
 * This is the stable identifier across Apple Sign-In sessions.
 *
 * @param {string} appleUserId - Apple's user identifier
 * @returns {Promise<Object|null>} User record or null if not found
 */
async function findByAppleId(appleUserId) {
    const users = await readUsers();
    return users.find(u => u.appleUserId === appleUserId) || null;
}

/**
 * Finds a user by their server-side user ID (UUID).
 *
 * @param {string} userId - Server-generated UUID
 * @returns {Promise<Object|null>} User record or null if not found
 */
async function findById(userId) {
    const users = await readUsers();
    return users.find(u => u.id === userId) || null;
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
    const users = await readUsers();
    return users.find(u => u.email === email) || null;
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
    const users = await readUsers();

    const newUser = {
        id: crypto.randomUUID(),
        appleUserId: userData.appleUserId || null,
        email: userData.email,
        name: userData.name || null,
        authProvider: userData.authProvider,
        gmailTokens: userData.gmailTokens || null,
        gmailEmail: userData.gmailEmail || null,
        createdAt: new Date().toISOString(),
        lastLoginAt: new Date().toISOString()
    };

    users.push(newUser);
    await writeUsers(users);
    return newUser;
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
    const users = await readUsers();
    const index = users.findIndex(u => u.id === userId);

    if (index === -1) {
        return null;
    }

    // Merge updates into existing record (shallow merge)
    users[index] = { ...users[index], ...updates };
    await writeUsers(users);
    return users[index];
}

/**
 * Deletes a user record by ID. Used for account deletion.
 *
 * @param {string} userId - The user's server-side ID
 * @returns {Promise<boolean>} True if user was found and deleted
 */
async function deleteUser(userId) {
    const users = await readUsers();
    const filtered = users.filter(u => u.id !== userId);

    if (filtered.length === users.length) {
        return false; // User not found
    }

    await writeUsers(filtered);
    return true;
}

module.exports = {
    initUsersFile,
    findByAppleId,
    findById,
    findByEmail,
    createUser,
    updateUser,
    deleteUser
};
