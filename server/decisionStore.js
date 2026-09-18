/**
 * decisionStore.js — Postgres-backed swipe decision history.
 *
 * Decisions are keyed by a user key rather than a users.id foreign key
 * because Google Sign-In users have no users row: they authenticate with a
 * raw Google access token, so their key is derived from their Gmail address.
 * Apple users key on their users.id.
 */

const { pool } = require('./db');

/**
 * Records one swipe decision.
 *
 * @param {string} userKey - Owner of the decision (see module comment)
 * @param {Object} entry
 * @param {string} entry.emailId - Gmail message ID
 * @param {"unsubscribe"|"keep"} entry.decision
 * @param {string|null} [entry.unsubscribeMethod] - Cascade method that succeeded, if any
 * @param {string|null} [entry.senderAddress] - Lowercased sender address, for future dedupe
 */
async function recordDecision(userKey, { emailId, decision, unsubscribeMethod, senderAddress }) {
    await pool.query(
        `INSERT INTO decisions (user_key, email_id, decision, unsubscribe_method, sender_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [userKey, emailId, decision, unsubscribeMethod || null, senderAddress || null]
    );
}

/**
 * Everything a user has already decided on, so a new batch can skip it.
 *
 * @param {string} userKey
 * @returns {Promise<{emailIds: Set<string>, senders: Set<string>}>}
 */
async function getDecided(userKey) {
    const { rows } = await pool.query(
        'SELECT email_id, sender_address FROM decisions WHERE user_key = $1',
        [userKey]
    );
    const emailIds = new Set();
    const senders = new Set();
    for (const row of rows) {
        emailIds.add(row.email_id);
        if (row.sender_address) senders.add(row.sender_address);
    }
    return { emailIds, senders };
}

/**
 * Aggregate counts for one user.
 *
 * @param {string} userKey
 * @returns {Promise<{totalDecisions: number, totalUnsubscribes: number}>}
 */
async function getStats(userKey) {
    const { rows } = await pool.query(
        `SELECT COUNT(*)::int AS total_decisions,
                COUNT(*) FILTER (WHERE decision = 'unsubscribe')::int AS total_unsubscribes
         FROM decisions WHERE user_key = $1`,
        [userKey]
    );
    return {
        totalDecisions: rows[0].total_decisions,
        totalUnsubscribes: rows[0].total_unsubscribes
    };
}

module.exports = { recordDecision, getDecided, getStats };
