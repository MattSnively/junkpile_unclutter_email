/**
 * Unit tests for GmailService — header parsing and unsubscribe data extraction.
 *
 * Tests cover:
 *   - extractUnsubscribeData() with various List-Unsubscribe header formats
 *   - RFC 8058 List-Unsubscribe-Post header detection
 *   - Email body fallback parsing
 *   - Backward-compatible primaryUrl selection
 */

const GmailService = require('../gmailService');

describe('GmailService', () => {
    let service;

    beforeEach(() => {
        // Create GmailService with a mock OAuth client (not making real API calls)
        const mockOauth = { credentials: {} };
        service = new GmailService(mockOauth);
        // Silence console output during tests
        jest.spyOn(console, 'log').mockImplementation(() => {});
        jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => {
        jest.restoreAllMocks();
    });

    // =====================================================================
    // extractUnsubscribeData — Header Parsing
    // =====================================================================
    describe('extractUnsubscribeData', () => {

        // Helper: create a minimal payload with optional HTML body
        function makePayload(htmlBody = '') {
            if (!htmlBody) return { headers: [] };
            const encoded = Buffer.from(htmlBody).toString('base64');
            return {
                mimeType: 'text/html',
                body: { data: encoded },
                headers: []
            };
        }

        it('extracts a single HTTP URL from List-Unsubscribe header', () => {
            const result = service.extractUnsubscribeData(
                '<https://example.com/unsubscribe?id=123>',
                '',
                makePayload()
            );

            expect(result.httpUrls).toEqual(['https://example.com/unsubscribe?id=123']);
            expect(result.mailtoUrl).toBeNull();
            expect(result.primaryUrl).toBe('https://example.com/unsubscribe?id=123');
        });

        it('extracts a single mailto URL from List-Unsubscribe header', () => {
            const result = service.extractUnsubscribeData(
                '<mailto:unsubscribe@example.com>',
                '',
                makePayload()
            );

            expect(result.httpUrls).toEqual([]);
            expect(result.mailtoUrl).toBe('mailto:unsubscribe@example.com');
            expect(result.primaryUrl).toBeNull();  // No HTTP URL → primaryUrl is null
        });

        it('extracts both HTTP and mailto URLs from combined header', () => {
            const result = service.extractUnsubscribeData(
                '<mailto:unsub@example.com>, <https://example.com/unsub>',
                '',
                makePayload()
            );

            expect(result.httpUrls).toEqual(['https://example.com/unsub']);
            expect(result.mailtoUrl).toBe('mailto:unsub@example.com');
            expect(result.primaryUrl).toBe('https://example.com/unsub');
        });

        it('extracts multiple HTTP URLs from header', () => {
            const result = service.extractUnsubscribeData(
                '<https://a.com/unsub>, <https://b.com/unsub>',
                '',
                makePayload()
            );

            expect(result.httpUrls).toEqual([
                'https://a.com/unsub',
                'https://b.com/unsub'
            ]);
            // Primary URL is the first HTTP URL
            expect(result.primaryUrl).toBe('https://a.com/unsub');
        });

        it('keeps only the first mailto URL when multiple present', () => {
            const result = service.extractUnsubscribeData(
                '<mailto:first@example.com>, <mailto:second@example.com>',
                '',
                makePayload()
            );

            expect(result.mailtoUrl).toBe('mailto:first@example.com');
        });

        it('detects List-Unsubscribe-Post header (RFC 8058)', () => {
            const result = service.extractUnsubscribeData(
                '<https://example.com/unsub>',
                'List-Unsubscribe=One-Click-Unsubscribe-Post',
                makePayload()
            );

            expect(result.hasListUnsubscribePost).toBe(true);
        });

        it('sets hasListUnsubscribePost to false when header missing', () => {
            const result = service.extractUnsubscribeData(
                '<https://example.com/unsub>',
                '',
                makePayload()
            );

            expect(result.hasListUnsubscribePost).toBe(false);
        });

        it('sets hasListUnsubscribePost to false when header is null', () => {
            const result = service.extractUnsubscribeData(
                '<https://example.com/unsub>',
                null,
                makePayload()
            );

            expect(result.hasListUnsubscribePost).toBe(false);
        });

        it('returns empty results for empty header', () => {
            const result = service.extractUnsubscribeData('', '', makePayload());

            expect(result.httpUrls).toEqual([]);
            expect(result.mailtoUrl).toBeNull();
            expect(result.primaryUrl).toBeNull();
        });

        it('returns empty results for null header', () => {
            const result = service.extractUnsubscribeData(null, null, makePayload());

            expect(result.httpUrls).toEqual([]);
            expect(result.mailtoUrl).toBeNull();
            expect(result.primaryUrl).toBeNull();
        });

        it('handles malformed header without angle brackets', () => {
            // Some poorly-formatted headers omit angle brackets
            const result = service.extractUnsubscribeData(
                'https://example.com/unsub',
                '',
                makePayload()
            );

            // Should not extract anything — RFC requires angle brackets
            expect(result.httpUrls).toEqual([]);
        });

        it('handles header with extra whitespace', () => {
            const result = service.extractUnsubscribeData(
                '  < https://example.com/unsub >  ,  < mailto:unsub@example.com >  ',
                '',
                makePayload()
            );

            // URLs should be trimmed
            expect(result.httpUrls.length).toBe(1);
            expect(result.httpUrls[0]).toBe('https://example.com/unsub');
            expect(result.mailtoUrl).toBe('mailto:unsub@example.com');
        });

        it('handles http (non-HTTPS) URLs', () => {
            const result = service.extractUnsubscribeData(
                '<http://example.com/unsub>',
                '',
                makePayload()
            );

            expect(result.httpUrls).toEqual(['http://example.com/unsub']);
        });
    });

    // =====================================================================
    // extractUnsubscribeData — Email Body Fallback
    // =====================================================================
    describe('extractUnsubscribeData — body fallback', () => {

        function makePayload(htmlBody) {
            const encoded = Buffer.from(htmlBody).toString('base64');
            return {
                mimeType: 'text/html',
                body: { data: encoded },
                headers: []
            };
        }

        it('extracts unsubscribe link from email body when no header', () => {
            const html = '<html><body><a href="https://example.com/unsubscribe?id=456">Unsubscribe</a></body></html>';
            const result = service.extractUnsubscribeData('', '', makePayload(html));

            expect(result.bodyUrl).toBe('https://example.com/unsubscribe?id=456');
            expect(result.primaryUrl).toBe('https://example.com/unsubscribe?id=456');
        });

        it('does NOT fall back to body when header URLs exist', () => {
            const html = '<html><body><a href="https://body.com/unsubscribe">Unsubscribe</a></body></html>';
            const result = service.extractUnsubscribeData(
                '<https://header.com/unsub>',
                '',
                makePayload(html)
            );

            // Body URL should not be extracted when header has URLs
            expect(result.bodyUrl).toBeNull();
            expect(result.primaryUrl).toBe('https://header.com/unsub');
        });

        it('does NOT fall back to body when mailto header exists', () => {
            const html = '<html><body><a href="https://body.com/unsubscribe">Unsubscribe</a></body></html>';
            const result = service.extractUnsubscribeData(
                '<mailto:unsub@example.com>',
                '',
                makePayload(html)
            );

            expect(result.bodyUrl).toBeNull();
        });

        it('returns null bodyUrl when body has no unsubscribe link', () => {
            const html = '<html><body><a href="https://example.com/contact">Contact Us</a></body></html>';
            const result = service.extractUnsubscribeData('', '', makePayload(html));

            expect(result.bodyUrl).toBeNull();
            expect(result.primaryUrl).toBeNull();
        });

        it('handles case-insensitive "unsubscribe" in body links', () => {
            const html = '<a href="https://example.com/Unsubscribe">Click here</a>';
            const result = service.extractUnsubscribeData('', '', makePayload(html));

            expect(result.bodyUrl).toBe('https://example.com/Unsubscribe');
        });
    });

    // =====================================================================
    // cleanSender
    // =====================================================================
    describe('cleanSender', () => {
        it('extracts name from "Name <email>" format', () => {
            expect(service.cleanSender('"Newsletter" <news@example.com>'))
                .toBe('Newsletter');
        });

        it('returns raw string when no angle bracket format', () => {
            expect(service.cleanSender('plain@example.com'))
                .toBe('plain@example.com');
        });

        it('strips surrounding quotes from name', () => {
            expect(service.cleanSender("'My Store' <store@example.com>"))
                .toBe('My Store');
        });
    });

    // =====================================================================
    // extractDomain
    // =====================================================================
    describe('extractDomain', () => {
        it('extracts domain from email address', () => {
            expect(service.extractDomain('user@example.com')).toBe('example.com');
        });

        it('extracts domain from "Name <email>" format', () => {
            expect(service.extractDomain('Store <store@shop.example.com>'))
                .toBe('shop.example.com');
        });

        it('returns input when no email found', () => {
            expect(service.extractDomain('no-email-here')).toBe('no-email-here');
        });
    });

    // =====================================================================
    // hasSendScope
    // =====================================================================
    describe('hasSendScope', () => {
        it('returns false when no scope info available', () => {
            expect(service.hasSendScope).toBe(false);
        });

        it('returns false when gmail.send not in scopes', () => {
            service.oauth2Client.credentials = {
                scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.modify'
            };
            expect(service.hasSendScope).toBe(false);
        });

        it('returns true when gmail.send is in scopes', () => {
            service.oauth2Client.credentials = {
                scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send'
            };
            expect(service.hasSendScope).toBe(true);
        });
    });
});
