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
 */
async function recordDecision(userKey, { emailId, decision, unsubscribeMethod }) {
    await pool.query(
        `INSERT INTO decisions (user_key, email_id, decision, unsubscribe_method)
         VALUES ($1, $2, $3, $4)`,
        [userKey, emailId, decision, unsubscribeMethod || null]
    );
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

module.exports = { recordDecision, getStats };
