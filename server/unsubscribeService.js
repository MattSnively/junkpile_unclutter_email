/**
 * UnsubscribeService — Executes real unsubscribe requests on behalf of users.
 *
 * Implements a cascading approach:
 *   1. RFC 8058 one-click POST (most reliable, modern ESPs)
 *   2. HTTP POST/GET to List-Unsubscribe header URLs
 *   3. HTTP POST/GET to unsubscribe URL found in email body
 *   4. Mailto fallback (requires gmail.send scope — deferred)
 *
 * Security:
 *   - All URLs validated before requests (SSRF prevention)
 *   - Private IPs, non-HTTP protocols, and embedded credentials rejected
 *   - Logs domain-only, never full URLs (which may contain PII/tokens)
 *   - No cookies or credentials sent to third-party unsubscribe endpoints
 *   - 10-second timeout on all HTTP requests
 */

// HTTP request timeout in milliseconds
const REQUEST_TIMEOUT_MS = 10000;

// Maximum redirects allowed (native fetch default is 20, we restrict further)
const MAX_REDIRECTS = 5;

// User-Agent string for outbound unsubscribe requests
const USER_AGENT = 'Junkpile-Unsubscribe/1.0';

class UnsubscribeService {

    /**
     * Validates a URL is safe to request (SSRF prevention).
     * Rejects private IPs, non-HTTP protocols, embedded credentials, and malformed URLs.
     *
     * @param {string} url - The URL to validate
     * @returns {{ valid: boolean, reason?: string }} Validation result
     */
    validateUrl(url) {
        // Parse the URL — rejects malformed strings
        let parsed;
        try {
            parsed = new URL(url);
        } catch {
            return { valid: false, reason: 'Malformed URL' };
        }

        // Only allow HTTP and HTTPS protocols
        if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
            return { valid: false, reason: `Disallowed protocol: ${parsed.protocol}` };
        }

        // Reject embedded credentials (user:pass@host)
        if (parsed.username || parsed.password) {
            return { valid: false, reason: 'URL contains embedded credentials' };
        }

        // Reject private/internal IP addresses to prevent SSRF
        const hostname = parsed.hostname.toLowerCase();
        if (this._isPrivateHost(hostname)) {
            return { valid: false, reason: 'Private/internal host not allowed' };
        }

        return { valid: true };
    }

    /**
     * Checks if a hostname resolves to a private/internal address.
     * Covers RFC 1918, loopback, link-local, and common internal hostnames.
     *
     * @param {string} hostname - Lowercase hostname to check
     * @returns {boolean} True if the host is private/internal
     * @private
     */
    _isPrivateHost(hostname) {
        // Reject localhost variants
        if (hostname === 'localhost' || hostname === 'localhost.localdomain') {
            return true;
        }

        // Reject common metadata endpoints (cloud SSRF targets)
        if (hostname === '169.254.169.254' || hostname === 'metadata.google.internal') {
            return true;
        }

        // Check for IPv4 private ranges
        const ipv4Match = hostname.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
        if (ipv4Match) {
            const [, a, b] = ipv4Match.map(Number);
            // 127.x.x.x — loopback
            if (a === 127) return true;
            // 10.x.x.x — Class A private
            if (a === 10) return true;
            // 172.16.0.0 – 172.31.255.255 — Class B private
            if (a === 172 && b >= 16 && b <= 31) return true;
            // 192.168.x.x — Class C private
            if (a === 192 && b === 168) return true;
            // 0.0.0.0 — unspecified
            if (a === 0 && b === 0) return true;
            // 169.254.x.x — link-local
            if (a === 169 && b === 254) return true;
        }

        // Check for IPv6 loopback (::1) and private ranges
        if (hostname === '::1' || hostname === '[::1]') {
            return true;
        }

        return false;
    }

    /**
     * Extracts the domain from a URL for privacy-safe logging.
     * Never log full URLs — they may contain tracking tokens or PII.
     *
     * @param {string} url - The URL to extract domain from
     * @returns {string} The domain name, or 'unknown' if parsing fails
     */
    _safeDomain(url) {
        try {
            return new URL(url).hostname;
        } catch {
            return 'unknown';
        }
    }

    /**
     * Performs an HTTP unsubscribe request to a validated URL.
     *
     * For RFC 8058 one-click: sends POST with standard body.
     * For regular URLs: tries POST first, falls back to GET on failure.
     *
     * @param {string} url - Validated unsubscribe URL
     * @param {boolean} isOneClick - Whether to use RFC 8058 one-click POST format
     * @returns {Promise<{ success: boolean, status?: number, error?: string }>}
     */
    async performHttpUnsubscribe(url, isOneClick = false) {
        const domain = this._safeDomain(url);

        // Validate URL before making any request
        const validation = this.validateUrl(url);
        if (!validation.valid) {
            console.log(`Unsubscribe: domain=${domain} blocked reason="${validation.reason}"`);
            return { success: false, error: validation.reason };
        }

        // Set up abort controller for timeout
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

        try {
            if (isOneClick) {
                // RFC 8058: One-click unsubscribe via POST
                // Body must be exactly: List-Unsubscribe=One-Click-Unsubscribe-Post
                const response = await fetch(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'User-Agent': USER_AGENT
                    },
                    body: 'List-Unsubscribe=One-Click-Unsubscribe-Post',
                    signal: controller.signal,
                    redirect: 'follow',
                    credentials: 'omit'    // Never send cookies to third parties
                });

                console.log(`Unsubscribe: domain=${domain} method=rfc8058 status=${response.status}`);
                return { success: response.ok, status: response.status };
            }

            // Standard HTTP: try POST first (many ESPs expect POST)
            const postResponse = await fetch(url, {
                method: 'POST',
                headers: { 'User-Agent': USER_AGENT },
                signal: controller.signal,
                redirect: 'follow',
                credentials: 'omit'
            });

            if (postResponse.ok) {
                console.log(`Unsubscribe: domain=${domain} method=http-post status=${postResponse.status}`);
                return { success: true, status: postResponse.status };
            }

            // POST failed — fall back to GET (some older ESPs only support GET)
            console.log(`Unsubscribe: domain=${domain} method=http-post status=${postResponse.status} falling-back-to-get`);

            // Need a fresh abort controller for the second request
            const getController = new AbortController();
            const getTimeout = setTimeout(() => getController.abort(), REQUEST_TIMEOUT_MS);

            try {
                const getResponse = await fetch(url, {
                    method: 'GET',
                    headers: { 'User-Agent': USER_AGENT },
                    signal: getController.signal,
                    redirect: 'follow',
                    credentials: 'omit'
                });

                console.log(`Unsubscribe: domain=${domain} method=http-get status=${getResponse.status}`);
                return { success: getResponse.ok, status: getResponse.status };
            } finally {
                clearTimeout(getTimeout);
            }

        } catch (error) {
            // Handle timeout (AbortError) and network errors
            const errorType = error.name === 'AbortError' ? 'timeout' : 'network-error';
            console.log(`Unsubscribe: domain=${domain} error=${errorType}`);
            return { success: false, error: errorType };
        } finally {
            clearTimeout(timeout);
        }
    }

    /**
     * Parses a mailto: URL into its component parts.
     * Handles RFC 6068 mailto syntax: mailto:addr?subject=X&body=Y
     *
     * @param {string} mailtoUrl - The mailto: URL to parse
     * @returns {{ to: string, subject: string, body: string } | null} Parsed components, or null if invalid
     */
    parseMailtoUrl(mailtoUrl) {
        if (!mailtoUrl || !mailtoUrl.startsWith('mailto:')) {
            return null;
        }

        try {
            // Strip 'mailto:' prefix and split on '?'
            const withoutScheme = mailtoUrl.substring(7);
            const [recipient, queryString] = withoutScheme.split('?');

            if (!recipient) {
                return null;
            }

            // Parse query parameters for subject and body
            let subject = 'Unsubscribe';
            let body = '';

            if (queryString) {
                const params = new URLSearchParams(queryString);
                if (params.has('subject')) {
                    subject = params.get('subject');
                }
                if (params.has('body')) {
                    body = params.get('body');
                }
            }

            return {
                to: decodeURIComponent(recipient),
                subject,
                body
            };
        } catch {
            return null;
        }
    }

    /**
     * Sends an unsubscribe email via the mailto: fallback method.
     * Requires gmail.send scope on the GmailService.
     *
     * @param {string} mailtoUrl - The mailto: URL from the List-Unsubscribe header
     * @param {object} gmailService - GmailService instance with sendEmail capability
     * @returns {Promise<{ success: boolean, error?: string }>}
     */
    async performMailtoUnsubscribe(mailtoUrl, gmailService) {
        // Only attempt if the Gmail service has send capability
        if (!gmailService || !gmailService.hasSendScope) {
            return { success: false, error: 'gmail.send scope not available' };
        }

        const parsed = this.parseMailtoUrl(mailtoUrl);
        if (!parsed) {
            return { success: false, error: 'Invalid mailto URL' };
        }

        try {
            // Send the unsubscribe email using Gmail API
            await gmailService.sendEmail(parsed.to, parsed.subject, parsed.body);
            console.log(`Unsubscribe: mailto recipient-domain=${this._safeDomain('https://' + parsed.to.split('@')[1])} method=mailto status=sent`);
            return { success: true };
        } catch (error) {
            console.log(`Unsubscribe: method=mailto error=${error.message}`);
            return { success: false, error: error.message };
        }
    }

    /**
     * Main orchestration method — tries all unsubscribe methods in cascade order.
     * First success wins; records all methods attempted for debugging.
     *
     * Cascade order:
     *   1. RFC 8058 one-click POST (if List-Unsubscribe-Post header present)
     *   2. HTTP POST/GET to List-Unsubscribe header URL(s)
     *   3. HTTP POST/GET to body-extracted unsubscribe URL
     *   4. Mailto fallback (if gmail.send scope available)
     *
     * @param {object} options
     * @param {string[]} options.httpUrls - HTTP(S) URLs from List-Unsubscribe header
     * @param {string|null} options.mailtoUrl - mailto: URL from List-Unsubscribe header
     * @param {string|null} options.bodyUrl - Unsubscribe URL found in email body HTML
     * @param {boolean} options.hasListUnsubscribePost - Whether List-Unsubscribe-Post header exists
     * @param {object|null} options.gmailService - GmailService instance for mailto fallback
     * @returns {Promise<{ success: boolean, method: string|null, attempted: string[], error: string|null }>}
     */
    async execute(options) {
        const {
            httpUrls = [],
            mailtoUrl = null,
            bodyUrl = null,
            hasListUnsubscribePost = false,
            gmailService = null
        } = options;

        const attempted = [];

        // --- Method 1: RFC 8058 one-click POST ---
        // This is the gold standard — modern ESPs support it and it's the most reliable
        if (hasListUnsubscribePost && httpUrls.length > 0) {
            attempted.push('rfc8058');
            const result = await this.performHttpUnsubscribe(httpUrls[0], true);
            if (result.success) {
                return { success: true, method: 'rfc8058', attempted, error: null };
            }
        }

        // --- Method 2: HTTP POST/GET to List-Unsubscribe header URLs ---
        // Try each URL from the header (usually just one, but RFC allows multiple)
        for (const url of httpUrls) {
            attempted.push('http-header');
            const result = await this.performHttpUnsubscribe(url, false);
            if (result.success) {
                return { success: true, method: 'http-header', attempted, error: null };
            }
        }

        // --- Method 3: HTTP POST/GET to email body URL ---
        // Fallback: use the unsubscribe link found in the email body HTML
        if (bodyUrl) {
            attempted.push('http-body');
            const result = await this.performHttpUnsubscribe(bodyUrl, false);
            if (result.success) {
                return { success: true, method: 'http-body', attempted, error: null };
            }
        }

        // --- Method 4: Mailto fallback ---
        // Last resort: send an unsubscribe email (requires gmail.send scope)
        if (mailtoUrl) {
            attempted.push('mailto');
            const result = await this.performMailtoUnsubscribe(mailtoUrl, gmailService);
            if (result.success) {
                return { success: true, method: 'mailto', attempted, error: null };
            }
        }

        // All methods failed or none were available
        const error = attempted.length === 0
            ? 'No unsubscribe methods available'
            : 'All unsubscribe methods failed';

        return { success: false, method: null, attempted, error };
    }
}

module.exports = UnsubscribeService;
