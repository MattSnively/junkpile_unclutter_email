/**
 * apiErrors.js — Typed error codes for API responses.
 *
 * Every error body carries a stable `code` so the iOS app can pick a
 * recovery action (reconnect, retry, wait) without parsing English. The
 * older `error` message and `needsAuth` flag are kept for clients already in
 * the field; `code` is additive.
 */

const CODES = {
    AUTH_REQUIRED: 'AUTH_REQUIRED',                       // no credentials sent
    AUTH_INVALID: 'AUTH_INVALID',                         // credentials sent but not accepted
    OAUTH_TOKEN_EXPIRED: 'OAUTH_TOKEN_EXPIRED',           // Google rejected the token; reconnect Gmail
    OAUTH_SCOPE_INSUFFICIENT: 'OAUTH_SCOPE_INSUFFICIENT', // token lacks a scope this action needs
    GMAIL_NOT_CONNECTED: 'GMAIL_NOT_CONNECTED',           // Apple user has not linked Gmail yet
    RATE_LIMITED: 'RATE_LIMITED',                         // Gmail quota; carries retry_after_seconds
    EMAIL_FETCH_FAILED: 'EMAIL_FETCH_FAILED',             // Gmail API failed for a non-auth reason
    VALIDATION_ERROR: 'VALIDATION_ERROR',                 // bad request body
    NOT_FOUND: 'NOT_FOUND',
    SERVER_NOT_CONFIGURED: 'SERVER_NOT_CONFIGURED',       // missing OAuth credentials on the server
    SERVER_INTERNAL_ERROR: 'SERVER_INTERNAL_ERROR'
};

// Codes that mean "the client must re-authenticate". Drives the legacy needsAuth flag.
const AUTH_CODES = new Set([CODES.AUTH_REQUIRED, CODES.AUTH_INVALID, CODES.OAUTH_TOKEN_EXPIRED]);

/**
 * Sends a JSON error with the standard shape:
 * { success: false, code, error, needsAuth?, ...extra }
 *
 * @param {import('express').Response} res
 * @param {number} status - HTTP status
 * @param {string} code - One of CODES
 * @param {string} message - Human-readable text, kept for older clients
 * @param {Object} [extra] - Additional fields (e.g. retry_after_seconds)
 */
function sendError(res, status, code, message, extra = {}) {
    const body = { success: false, code, error: message, ...extra };
    if (AUTH_CODES.has(code)) {
        body.needsAuth = true;
    }
    return res.status(status).json(body);
}

const RATE_LIMIT_REASONS = new Set([
    'rateLimitExceeded', 'userRateLimitExceeded', 'dailyLimitExceeded', 'quotaExceeded'
]);
const DEFAULT_RETRY_AFTER_SECONDS = 60;

/**
 * Maps a googleapis (Gaxios) error to a status, code, and message.
 * Google signals rate limits as 429 or as 403 with a rate-limit reason,
 * missing scopes as 403 insufficientPermissions, and dead tokens as 401 or
 * an invalid_grant message.
 *
 * @param {Error} err
 * @returns {{status: number, code: string, message: string, extra?: Object}}
 */
function classifyGmailError(err) {
    const httpStatus = Number(err?.code ?? err?.response?.status) || 0;
    const message = String(err?.message || '');
    const reason = err?.errors?.[0]?.reason
        || err?.response?.data?.error?.errors?.[0]?.reason
        || '';

    if (httpStatus === 401 || /invalid_grant|unauthorized_client|invalid credentials/i.test(message)) {
        return {
            status: 401,
            code: CODES.OAUTH_TOKEN_EXPIRED,
            message: 'Gmail access has expired. Please reconnect Gmail.'
        };
    }

    if (httpStatus === 429 || (httpStatus === 403 && RATE_LIMIT_REASONS.has(reason))) {
        const header = Number(err?.response?.headers?.['retry-after']);
        return {
            status: 429,
            code: CODES.RATE_LIMITED,
            message: 'Gmail is rate-limiting requests. Please wait and try again.',
            extra: { retry_after_seconds: header > 0 ? header : DEFAULT_RETRY_AFTER_SECONDS }
        };
    }

    if (httpStatus === 403 || /insufficient/i.test(message)) {
        return {
            status: 403,
            code: CODES.OAUTH_SCOPE_INSUFFICIENT,
            message: 'Gmail permission is missing for this action. Please reconnect Gmail.'
        };
    }

    return {
        status: 502,
        code: CODES.EMAIL_FETCH_FAILED,
        message: 'Could not reach Gmail. Please try again.'
    };
}

/**
 * Sends the classified Gmail error.
 * @param {import('express').Response} res
 * @param {Error} err
 */
function sendGmailError(res, err) {
    const { status, code, message, extra } = classifyGmailError(err);
    return sendError(res, status, code, message, extra);
}

/**
 * Maps the free-text `error` from the unsubscribe cascade to a stable code.
 * These ride inside a 200 response's unsubscribeResult, not an HTTP error.
 *
 * @param {string|null} error
 * @returns {string|null} null when there was no failure
 */
function unsubscribeFailureCode(error) {
    if (!error) return null;
    switch (error) {
        case 'timeout': return 'UNSUBSCRIBE_FAILED_TIMEOUT';
        case 'network-error': return 'UNSUBSCRIBE_FAILED_NETWORK';
        case 'no-unsubscribe-data': return 'UNSUBSCRIBE_FAILED_NO_METHOD';
        case 'not-authenticated': return 'UNSUBSCRIBE_FAILED_NOT_AUTHENTICATED';
        case 'gmail.send scope not available': return 'UNSUBSCRIBE_FAILED_SCOPE';
        default:
            // URL validation rejections come from UnsubscribeService.validateUrl
            if (/^(Malformed URL|Disallowed protocol|URL contains embedded credentials|Private\/internal host)/.test(error)) {
                return 'UNSUBSCRIBE_FAILED_BLOCKED_URL';
            }
            return 'UNSUBSCRIBE_FAILED_REJECTED';
    }
}

module.exports = { CODES, sendError, classifyGmailError, sendGmailError, unsubscribeFailureCode };
