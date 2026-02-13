/**
 * Unit tests for UnsubscribeService.
 *
 * Tests cover:
 *   - URL validation and SSRF prevention
 *   - RFC 8058 one-click POST execution
 *   - HTTP POST/GET fallback logic
 *   - Mailto URL parsing
 *   - Mailto execution with scope checking
 *   - Full cascade orchestration
 */

const UnsubscribeService = require('../unsubscribeService');

// Mock global fetch for HTTP request tests
const originalFetch = global.fetch;

afterEach(() => {
    // Restore real fetch after each test to prevent cross-test contamination
    global.fetch = originalFetch;
});

describe('UnsubscribeService', () => {
    let service;

    beforeEach(() => {
        service = new UnsubscribeService();
        // Silence console.log during tests to keep output clean
        jest.spyOn(console, 'log').mockImplementation(() => {});
        jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => {
        jest.restoreAllMocks();
    });

    // =====================================================================
    // URL Validation — SSRF Prevention
    // =====================================================================
    describe('validateUrl', () => {
        it('accepts valid HTTPS URLs', () => {
            const result = service.validateUrl('https://example.com/unsubscribe?token=abc');
            expect(result.valid).toBe(true);
        });

        it('accepts valid HTTP URLs', () => {
            const result = service.validateUrl('http://example.com/unsubscribe');
            expect(result.valid).toBe(true);
        });

        it('rejects javascript: protocol', () => {
            const result = service.validateUrl('javascript:alert(1)');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/protocol/i);
        });

        it('rejects data: protocol', () => {
            const result = service.validateUrl('data:text/html,<h1>test</h1>');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/protocol/i);
        });

        it('rejects file: protocol', () => {
            const result = service.validateUrl('file:///etc/passwd');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/protocol/i);
        });

        it('rejects malformed URLs', () => {
            const result = service.validateUrl('not-a-url');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/malformed/i);
        });

        it('rejects empty string', () => {
            const result = service.validateUrl('');
            expect(result.valid).toBe(false);
        });

        it('rejects URLs with embedded credentials', () => {
            const result = service.validateUrl('https://user:pass@example.com/unsub');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/credentials/i);
        });

        // Private IP ranges (SSRF targets)
        it('rejects localhost', () => {
            const result = service.validateUrl('http://localhost/unsub');
            expect(result.valid).toBe(false);
            expect(result.reason).toMatch(/private/i);
        });

        it('rejects 127.0.0.1 (loopback)', () => {
            const result = service.validateUrl('http://127.0.0.1/unsub');
            expect(result.valid).toBe(false);
        });

        it('rejects 10.x.x.x (Class A private)', () => {
            const result = service.validateUrl('http://10.0.0.1/unsub');
            expect(result.valid).toBe(false);
        });

        it('rejects 172.16.x.x (Class B private)', () => {
            const result = service.validateUrl('http://172.16.0.1/unsub');
            expect(result.valid).toBe(false);
        });

        it('rejects 172.31.x.x (Class B private upper bound)', () => {
            const result = service.validateUrl('http://172.31.255.255/unsub');
            expect(result.valid).toBe(false);
        });

        it('allows 172.32.x.x (outside private range)', () => {
            const result = service.validateUrl('http://172.32.0.1/unsub');
            expect(result.valid).toBe(true);
        });

        it('rejects 192.168.x.x (Class C private)', () => {
            const result = service.validateUrl('http://192.168.1.1/unsub');
            expect(result.valid).toBe(false);
        });

        it('rejects 0.0.0.0', () => {
            const result = service.validateUrl('http://0.0.0.0/unsub');
            expect(result.valid).toBe(false);
        });

        it('rejects 169.254.169.254 (cloud metadata endpoint)', () => {
            const result = service.validateUrl('http://169.254.169.254/latest/meta-data');
            expect(result.valid).toBe(false);
        });

        it('rejects metadata.google.internal', () => {
            const result = service.validateUrl('http://metadata.google.internal/computeMetadata');
            expect(result.valid).toBe(false);
        });

        it('rejects IPv6 loopback ::1', () => {
            const result = service.validateUrl('http://[::1]/unsub');
            expect(result.valid).toBe(false);
        });
    });

    // =====================================================================
    // Mailto URL Parsing
    // =====================================================================
    describe('parseMailtoUrl', () => {
        it('parses a simple mailto URL', () => {
            const result = service.parseMailtoUrl('mailto:unsub@example.com');
            expect(result).toEqual({
                to: 'unsub@example.com',
                subject: 'Unsubscribe',
                body: ''
            });
        });

        it('parses mailto URL with subject parameter', () => {
            const result = service.parseMailtoUrl('mailto:unsub@example.com?subject=Unsubscribe%20Me');
            expect(result).toEqual({
                to: 'unsub@example.com',
                subject: 'Unsubscribe Me',
                body: ''
            });
        });

        it('parses mailto URL with subject and body parameters', () => {
            const result = service.parseMailtoUrl(
                'mailto:unsub@example.com?subject=Remove&body=Please%20remove%20me'
            );
            expect(result).toEqual({
                to: 'unsub@example.com',
                subject: 'Remove',
                body: 'Please remove me'
            });
        });

        it('returns null for non-mailto URL', () => {
            expect(service.parseMailtoUrl('https://example.com')).toBeNull();
        });

        it('returns null for null input', () => {
            expect(service.parseMailtoUrl(null)).toBeNull();
        });

        it('returns null for empty string', () => {
            expect(service.parseMailtoUrl('')).toBeNull();
        });

        it('returns null for mailto with no recipient', () => {
            expect(service.parseMailtoUrl('mailto:')).toBeNull();
        });
    });

    // =====================================================================
    // HTTP Unsubscribe Execution
    // =====================================================================
    describe('performHttpUnsubscribe', () => {
        it('sends RFC 8058 one-click POST with correct body', async () => {
            // Mock fetch to capture the request details
            global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 });

            const result = await service.performHttpUnsubscribe(
                'https://example.com/unsub', true
            );

            expect(result.success).toBe(true);
            expect(result.status).toBe(200);

            // Verify the request was a POST with RFC 8058 body
            expect(global.fetch).toHaveBeenCalledWith(
                'https://example.com/unsub',
                expect.objectContaining({
                    method: 'POST',
                    body: 'List-Unsubscribe=One-Click-Unsubscribe-Post',
                    credentials: 'omit',
                    headers: expect.objectContaining({
                        'Content-Type': 'application/x-www-form-urlencoded'
                    })
                })
            );
        });

        it('falls back to GET when POST returns 405', async () => {
            // First call (POST) returns 405, second call (GET) returns 200
            global.fetch = jest.fn()
                .mockResolvedValueOnce({ ok: false, status: 405 })
                .mockResolvedValueOnce({ ok: true, status: 200 });

            const result = await service.performHttpUnsubscribe(
                'https://example.com/unsub', false
            );

            expect(result.success).toBe(true);
            expect(global.fetch).toHaveBeenCalledTimes(2);

            // Verify second call was GET
            expect(global.fetch.mock.calls[1][1].method).toBe('GET');
        });

        it('returns failure when both POST and GET fail', async () => {
            global.fetch = jest.fn()
                .mockResolvedValueOnce({ ok: false, status: 500 })
                .mockResolvedValueOnce({ ok: false, status: 500 });

            const result = await service.performHttpUnsubscribe(
                'https://example.com/unsub', false
            );

            expect(result.success).toBe(false);
        });

        it('returns failure on network timeout', async () => {
            // Simulate an AbortError (timeout)
            const abortError = new Error('Aborted');
            abortError.name = 'AbortError';
            global.fetch = jest.fn().mockRejectedValue(abortError);

            const result = await service.performHttpUnsubscribe(
                'https://example.com/unsub', true
            );

            expect(result.success).toBe(false);
            expect(result.error).toBe('timeout');
        });

        it('returns failure on network error', async () => {
            global.fetch = jest.fn().mockRejectedValue(new Error('ECONNREFUSED'));

            const result = await service.performHttpUnsubscribe(
                'https://example.com/unsub', false
            );

            expect(result.success).toBe(false);
            expect(result.error).toBe('network-error');
        });

        it('rejects private IP URLs before making requests', async () => {
            global.fetch = jest.fn();

            const result = await service.performHttpUnsubscribe(
                'http://192.168.1.1/unsub', false
            );

            expect(result.success).toBe(false);
            // fetch should never have been called
            expect(global.fetch).not.toHaveBeenCalled();
        });

        it('sends no cookies/credentials to third-party URLs', async () => {
            global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 });

            await service.performHttpUnsubscribe('https://example.com/unsub', false);

            expect(global.fetch).toHaveBeenCalledWith(
                expect.any(String),
                expect.objectContaining({ credentials: 'omit' })
            );
        });
    });

    // =====================================================================
    // Mailto Unsubscribe Execution
    // =====================================================================
    describe('performMailtoUnsubscribe', () => {
        it('skips when gmailService is null', async () => {
            const result = await service.performMailtoUnsubscribe(
                'mailto:unsub@example.com', null
            );
            expect(result.success).toBe(false);
            expect(result.error).toMatch(/scope/i);
        });

        it('skips when gmailService lacks send scope', async () => {
            const mockGmail = { hasSendScope: false };
            const result = await service.performMailtoUnsubscribe(
                'mailto:unsub@example.com', mockGmail
            );
            expect(result.success).toBe(false);
            expect(result.error).toMatch(/scope/i);
        });

        it('calls sendEmail with correct params when scope available', async () => {
            const mockGmail = {
                hasSendScope: true,
                sendEmail: jest.fn().mockResolvedValue(undefined)
            };

            const result = await service.performMailtoUnsubscribe(
                'mailto:unsub@example.com?subject=Remove%20Me', mockGmail
            );

            expect(result.success).toBe(true);
            expect(mockGmail.sendEmail).toHaveBeenCalledWith(
                'unsub@example.com', 'Remove Me', ''
            );
        });

        it('returns failure on invalid mailto URL', async () => {
            const mockGmail = { hasSendScope: true };
            const result = await service.performMailtoUnsubscribe('not-mailto', mockGmail);
            expect(result.success).toBe(false);
        });
    });

    // =====================================================================
    // Full Cascade Orchestration
    // =====================================================================
    describe('execute', () => {
        it('tries RFC 8058 first when List-Unsubscribe-Post header exists', async () => {
            global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 });

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                mailtoUrl: 'mailto:unsub@example.com',
                bodyUrl: 'https://example.com/body-unsub',
                hasListUnsubscribePost: true,
                gmailService: null
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('rfc8058');
            expect(result.attempted).toContain('rfc8058');
            // Should have stopped after first success — only one fetch call for RFC 8058
            expect(global.fetch).toHaveBeenCalledTimes(1);
        });

        it('falls through to http-header when RFC 8058 fails', async () => {
            // First call: RFC 8058 POST → 400
            // Second call: HTTP POST → 200
            global.fetch = jest.fn()
                .mockResolvedValueOnce({ ok: false, status: 400 })
                .mockResolvedValueOnce({ ok: true, status: 200 });

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                hasListUnsubscribePost: true,
                gmailService: null
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('http-header');
            expect(result.attempted).toEqual(['rfc8058', 'http-header']);
        });

        it('falls through to body URL when header URLs fail', async () => {
            // RFC 8058 POST → fail, HTTP POST → fail, HTTP GET → fail, body POST → 200
            global.fetch = jest.fn()
                .mockResolvedValueOnce({ ok: false, status: 500 })   // RFC 8058
                .mockResolvedValueOnce({ ok: false, status: 500 })   // header POST
                .mockResolvedValueOnce({ ok: false, status: 500 })   // header GET
                .mockResolvedValueOnce({ ok: true, status: 200 });   // body POST

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                bodyUrl: 'https://example.com/body-unsub',
                hasListUnsubscribePost: true,
                gmailService: null
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('http-body');
        });

        it('tries mailto as last resort', async () => {
            // All HTTP methods fail
            global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 500 });

            const mockGmail = {
                hasSendScope: true,
                sendEmail: jest.fn().mockResolvedValue(undefined)
            };

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                mailtoUrl: 'mailto:unsub@example.com',
                hasListUnsubscribePost: true,
                gmailService: mockGmail
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('mailto');
            expect(result.attempted).toContain('mailto');
        });

        it('returns failure when all methods fail', async () => {
            global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 500 });

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                mailtoUrl: 'mailto:unsub@example.com',
                bodyUrl: 'https://example.com/body-unsub',
                hasListUnsubscribePost: true,
                gmailService: null  // No send scope → mailto skipped
            });

            expect(result.success).toBe(false);
            expect(result.method).toBeNull();
            expect(result.error).toMatch(/failed/i);
        });

        it('returns failure when no methods available', async () => {
            const result = await service.execute({
                httpUrls: [],
                mailtoUrl: null,
                bodyUrl: null,
                hasListUnsubscribePost: false,
                gmailService: null
            });

            expect(result.success).toBe(false);
            expect(result.attempted).toEqual([]);
            expect(result.error).toMatch(/no unsubscribe methods/i);
        });

        it('works with only a body URL (no headers)', async () => {
            global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 });

            const result = await service.execute({
                httpUrls: [],
                bodyUrl: 'https://example.com/body-unsub',
                hasListUnsubscribePost: false,
                gmailService: null
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('http-body');
        });

        it('skips RFC 8058 when hasListUnsubscribePost is false', async () => {
            global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 });

            const result = await service.execute({
                httpUrls: ['https://example.com/unsub'],
                hasListUnsubscribePost: false,
                gmailService: null
            });

            expect(result.success).toBe(true);
            expect(result.method).toBe('http-header');
            // Should NOT have attempted rfc8058
            expect(result.attempted).not.toContain('rfc8058');
        });
    });

    // =====================================================================
    // Privacy-Safe Logging
    // =====================================================================
    describe('_safeDomain', () => {
        it('extracts domain from HTTPS URL', () => {
            expect(service._safeDomain('https://mail.example.com/unsub?token=secret'))
                .toBe('mail.example.com');
        });

        it('returns unknown for invalid URL', () => {
            expect(service._safeDomain('not-a-url')).toBe('unknown');
        });
    });
});
