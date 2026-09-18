/**
 * Unit tests for apiErrors — typed error codes, Gmail error classification,
 * and unsubscribe failure codes.
 */

const { CODES, sendError, classifyGmailError, unsubscribeFailureCode } = require('../apiErrors');

function mockRes() {
    const res = {};
    res.status = jest.fn(() => res);
    res.json = jest.fn(() => res);
    return res;
}

describe('sendError', () => {
    test('emits the standard shape with code and message', () => {
        const res = mockRes();
        sendError(res, 400, CODES.VALIDATION_ERROR, 'emailId is required');

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({
            success: false,
            code: 'VALIDATION_ERROR',
            error: 'emailId is required'
        });
    });

    test('adds needsAuth for auth-class codes only', () => {
        for (const code of [CODES.AUTH_REQUIRED, CODES.AUTH_INVALID, CODES.OAUTH_TOKEN_EXPIRED]) {
            const res = mockRes();
            sendError(res, 401, code, 'x');
            expect(res.json.mock.calls[0][0].needsAuth).toBe(true);
        }
        const res = mockRes();
        sendError(res, 429, CODES.RATE_LIMITED, 'x');
        expect(res.json.mock.calls[0][0]).not.toHaveProperty('needsAuth');
    });

    test('merges extra fields', () => {
        const res = mockRes();
        sendError(res, 429, CODES.RATE_LIMITED, 'slow down', { retry_after_seconds: 30 });
        expect(res.json.mock.calls[0][0]).toMatchObject({ retry_after_seconds: 30 });
    });
});

describe('classifyGmailError', () => {
    test('401 from Google is an expired token', () => {
        expect(classifyGmailError({ code: 401, message: 'Invalid Credentials' }))
            .toMatchObject({ status: 401, code: CODES.OAUTH_TOKEN_EXPIRED });
    });

    test('invalid_grant in the message is an expired token regardless of status', () => {
        expect(classifyGmailError({ code: 400, message: 'invalid_grant: Token has been expired or revoked.' }))
            .toMatchObject({ status: 401, code: CODES.OAUTH_TOKEN_EXPIRED });
    });

    test('429 is rate limited with a default retry delay', () => {
        expect(classifyGmailError({ code: 429, message: 'Too Many Requests' }))
            .toMatchObject({ status: 429, code: CODES.RATE_LIMITED, extra: { retry_after_seconds: 60 } });
    });

    test('403 with a quota reason is rate limited and honours Retry-After', () => {
        const err = {
            code: 403,
            message: 'User-rate limit exceeded.',
            errors: [{ reason: 'userRateLimitExceeded' }],
            response: { headers: { 'retry-after': '12' } }
        };
        expect(classifyGmailError(err))
            .toMatchObject({ status: 429, code: CODES.RATE_LIMITED, extra: { retry_after_seconds: 12 } });
    });

    test('403 without a quota reason is a scope problem', () => {
        const err = { code: 403, message: 'Insufficient Permission', errors: [{ reason: 'insufficientPermissions' }] };
        expect(classifyGmailError(err))
            .toMatchObject({ status: 403, code: CODES.OAUTH_SCOPE_INSUFFICIENT });
    });

    test('nested response.status and reason are read when top-level code is absent', () => {
        const err = {
            message: 'Rate Limit Exceeded',
            response: { status: 403, data: { error: { errors: [{ reason: 'rateLimitExceeded' }] } } }
        };
        expect(classifyGmailError(err)).toMatchObject({ status: 429, code: CODES.RATE_LIMITED });
    });

    test('anything else is a fetch failure, not a 500', () => {
        expect(classifyGmailError({ code: 'ECONNRESET', message: 'socket hang up' }))
            .toMatchObject({ status: 502, code: CODES.EMAIL_FETCH_FAILED });
        expect(classifyGmailError(new Error('Backend Error')))
            .toMatchObject({ status: 502, code: CODES.EMAIL_FETCH_FAILED });
        expect(classifyGmailError(undefined))
            .toMatchObject({ status: 502, code: CODES.EMAIL_FETCH_FAILED });
    });
});

describe('unsubscribeFailureCode', () => {
    test.each([
        [null, null],
        ['', null],
        ['timeout', 'UNSUBSCRIBE_FAILED_TIMEOUT'],
        ['network-error', 'UNSUBSCRIBE_FAILED_NETWORK'],
        ['no-unsubscribe-data', 'UNSUBSCRIBE_FAILED_NO_METHOD'],
        ['not-authenticated', 'UNSUBSCRIBE_FAILED_NOT_AUTHENTICATED'],
        ['gmail.send scope not available', 'UNSUBSCRIBE_FAILED_SCOPE'],
        ['Malformed URL', 'UNSUBSCRIBE_FAILED_BLOCKED_URL'],
        ['Disallowed protocol: ftp:', 'UNSUBSCRIBE_FAILED_BLOCKED_URL'],
        ['Private/internal host not allowed', 'UNSUBSCRIBE_FAILED_BLOCKED_URL'],
        ['HTTP 500', 'UNSUBSCRIBE_FAILED_REJECTED']
    ])('%p -> %p', (input, expected) => {
        expect(unsubscribeFailureCode(input)).toBe(expected);
    });
});
