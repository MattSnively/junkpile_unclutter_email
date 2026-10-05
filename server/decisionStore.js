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

// Only these methods prove a request reached the sender: a one-click POST
// they accepted, or an email we sent. Anything else, including plain links
// older builds counted as success, may never have been received.
const VERIFIED_METHODS = new Set(['rfc8058', 'mailto']);

/**
 * Everything a user has already decided on, so a new batch can skip it.
 *
 * `senders` holds the senders to skip: kept, or unsubscribed with a verified
 * request. `unsubscribedAt` dates each verified unsubscribe so mail they keep
 * sending can be spotted. `unconfirmedAt` dates each unsubscribe whose request
 * may never have gone out, so those senders can come back for another try
 * instead of disappearing. A later keep overrides either.
 *
 * @param {string} userKey
 * @returns {Promise<{emailIds: Set<string>, senders: Set<string>, unsubscribedAt: Map<string, Date>, unconfirmedAt: Map<string, Date>}>}
 */
async function getDecided(userKey) {
    const { rows } = await pool.query(
        `SELECT email_id, sender_address, decision, unsubscribe_method, created_at FROM decisions
         WHERE user_key = $1 ORDER BY created_at`,
        [userKey]
    );
    const emailIds = new Set();
    const senders = new Set();
    const unsubscribedAt = new Map();
    const unconfirmedAt = new Map();
    for (const row of rows) {
        emailIds.add(row.email_id);
        if (!row.sender_address) continue;
        // Rows are oldest first, so the last write per sender is their latest decision
        unsubscribedAt.delete(row.sender_address);
        unconfirmedAt.delete(row.sender_address);
        if (row.decision === 'unsubscribe' && !VERIFIED_METHODS.has(row.unsubscribe_method)) {
            senders.delete(row.sender_address);
            unconfirmedAt.set(row.sender_address, row.created_at);
            continue;
        }
        senders.add(row.sender_address);
        if (row.decision === 'unsubscribe') {
            unsubscribedAt.set(row.sender_address, row.created_at);
        }
    }
    return { emailIds, senders, unsubscribedAt, unconfirmedAt };
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

/**
 * Removes every decision for a user. Used for account deletion.
 *
 * @param {string} userKey
 * @returns {Promise<number>} Rows deleted
 */
async function deleteByUser(userKey) {
    const { rowCount } = await pool.query('DELETE FROM decisions WHERE user_key = $1', [userKey]);
    return rowCount;
}

module.exports = { recordDecision, getDecided, getStats, deleteByUser };
