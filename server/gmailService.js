const { google } = require('googleapis');
const UnsubscribeService = require('./unsubscribeService');

/**
 * GmailService — Handles all Gmail API interactions.
 *
 * Responsible for:
 *   - Fetching emails with unsubscribe options
 *   - Extracting unsubscribe data from headers and body (RFC 2369, RFC 8058)
 *   - Executing unsubscribe actions (delegates to UnsubscribeService)
 *   - Sending emails via Gmail API (for mailto-based unsubscribe)
 */
class GmailService {
    constructor(oauth2Client) {
        this.oauth2Client = oauth2Client;
        this.gmail = google.gmail({ version: 'v1', auth: oauth2Client });
    }

    /**
     * Checks if the current OAuth credentials include gmail.send scope.
     * Required for mailto-based unsubscribe. Currently returns false
     * because gmail.send is not yet requested (deferred to a follow-up release).
     *
     * @returns {boolean} True if send capability is available
     */
    get hasSendScope() {
        // gmail.send scope is deferred — will be enabled in a future release
        // when it's added to the OAuth scope array in server.js.
        // At that point, this getter should check the actual token scopes.
        try {
            const credentials = this.oauth2Client.credentials;
            if (credentials && credentials.scope) {
                return credentials.scope.includes('https://www.googleapis.com/auth/gmail.send');
            }
        } catch {
            // Scope info not available — assume no send capability
        }
        return false;
    }

    /**
     * Fetches emails that contain unsubscribe options from the user's inbox.
     * Searches for emails with "unsubscribe" or "list-unsubscribe" in the last 30 days,
     * skips anything the user has already decided on, and deduplicates by
     * sender domain (one email per sender). Pages through Gmail results until
     * the batch is full or the scan cap is reached, because the newest matches
     * are mostly senders the user has already handled.
     *
     * @param {Object} [options]
     * @param {Set<string>} [options.excludeIds] - Message IDs already decided
     * @param {Set<string>} [options.excludeSenders] - Sender addresses already decided
     * @param {number} [options.limit=20] - Batch size to return
     * @param {number} [options.maxScan=200] - Upper bound on messages examined
     * @returns {Promise<Array>} Array of email objects with unsubscribe data
     */
    async getEmailsWithUnsubscribe({ excludeIds = new Set(), excludeSenders = new Set(), limit = 20, maxScan = 200 } = {}) {
        try {
            const seenSenders = new Set(excludeSenders);
            const uniqueEmails = [];
            let pageToken;
            let scanned = 0;

            do {
                // Search for emails with unsubscribe links in the last 30 days
                const response = await this.gmail.users.messages.list({
                    userId: 'me',
                    q: 'unsubscribe OR list-unsubscribe newer_than:30d',
                    maxResults: 50,
                    pageToken
                });

                const messages = response.data.messages || [];
                scanned += messages.length;

                // Skip decided IDs before paying for a details fetch
                const emails = await Promise.all(
                    messages
                        .filter(msg => !excludeIds.has(msg.id))
                        .map(msg => this.getEmailDetails(msg.id))
                );

                for (const email of emails) {
                    if (email && email.unsubscribeUrl) {
                        const sender = this.extractSenderAddress(email.rawHeaders.from);
                        if (!seenSenders.has(sender)) {
                            seenSenders.add(sender);
                            uniqueEmails.push(email);
                            if (uniqueEmails.length >= limit) break;
                        }
                    }
                }

                pageToken = response.data.nextPageToken;
            } while (pageToken && uniqueEmails.length < limit && scanned < maxScan);

            return uniqueEmails;
        } catch (error) {
            console.error('Error fetching emails:', error);
            throw error;
        }
    }

    /**
     * Resolves the sender address of a message from its From header alone.
     * Used when recording a "keep" decision, where the full message is not
     * otherwise fetched.
     *
     * @param {string} messageId - Gmail message ID
     * @returns {Promise<string|null>} Lowercased sender address, or null on error
     */
    async getSenderAddress(messageId) {
        try {
            const response = await this.gmail.users.messages.get({
                userId: 'me',
                id: messageId,
                format: 'metadata',
                metadataHeaders: ['From']
            });
            const from = (response.data.payload?.headers || [])
                .find(h => h.name.toLowerCase() === 'from');
            return from ? this.extractSenderAddress(from.value) : null;
        } catch (error) {
            console.error('Error fetching sender for message:', error.message);
            return null;
        }
    }

    /**
     * Fetches full details for a single email by message ID.
     * Extracts headers, body, and all unsubscribe-related data.
     *
     * @param {string} messageId - Gmail message ID
     * @returns {Promise<object|null>} Email details object, or null on error
     */
    async getEmailDetails(messageId) {
        try {
            const response = await this.gmail.users.messages.get({
                userId: 'me',
                id: messageId,
                format: 'full'
            });

            const message = response.data;
            const headers = message.payload.headers;

            // Helper to find a header by name (case-insensitive)
            const getHeader = (name) => {
                const header = headers.find(h => h.name.toLowerCase() === name.toLowerCase());
                return header ? header.value : '';
            };

            const from = getHeader('From');
            const subject = getHeader('Subject');
            const listUnsubscribe = getHeader('List-Unsubscribe');
            const listUnsubscribePost = getHeader('List-Unsubscribe-Post');

            // Extract all unsubscribe data from headers and body
            const unsubscribeData = this.extractUnsubscribeData(
                listUnsubscribe,
                listUnsubscribePost,
                message.payload
            );

            // Get email body HTML for display
            const htmlBody = this.getEmailBody(message.payload);

            return {
                id: messageId,
                sender: this.cleanSender(from),
                subject: subject,
                htmlBody: htmlBody,
                // Gmail API's pre-sanitized snippet — plain text with no HTML/CSS.
                // Used as the primary preview text on iOS to avoid CSS leakage.
                snippet: message.snippet || '',
                // primaryUrl maintains backward compatibility with iOS app
                unsubscribeUrl: unsubscribeData.primaryUrl,
                // Full unsubscribe data for server-side execution
                unsubscribeData: unsubscribeData,
                rawHeaders: {
                    from,
                    listUnsubscribe,
                    listUnsubscribePost
                }
            };
        } catch (error) {
            console.error('Error fetching email details:', error);
            return null;
        }
    }

    /**
     * Extracts the HTML body from an email payload.
     * Handles multipart emails (searches parts for text/html) and simple emails.
     *
     * @param {object} payload - Gmail message payload
     * @returns {string} HTML body content, or empty string if not found
     */
    getEmailBody(payload) {
        let htmlBody = '';

        if (payload.parts) {
            // Multipart email — search for text/html part
            for (const part of payload.parts) {
                if (part.mimeType === 'text/html' && part.body.data) {
                    htmlBody = Buffer.from(part.body.data, 'base64').toString('utf-8');
                    break;
                } else if (part.parts) {
                    // Nested parts (e.g., multipart/alternative inside multipart/mixed)
                    htmlBody = this.getEmailBody(part);
                    if (htmlBody) break;
                }
            }
        } else if (payload.body && payload.body.data) {
            // Simple (non-multipart) email body
            if (payload.mimeType === 'text/html') {
                htmlBody = Buffer.from(payload.body.data, 'base64').toString('utf-8');
            }
        }

        return htmlBody;
    }

    /**
     * Extracts all unsubscribe-related data from email headers and body.
     *
     * Parses the List-Unsubscribe header (RFC 2369) for both HTTP and mailto URLs,
     * checks for the List-Unsubscribe-Post header (RFC 8058), and falls back to
     * searching the HTML body for unsubscribe links.
     *
     * @param {string} listUnsubscribeHeader - Value of the List-Unsubscribe header
     * @param {string} listUnsubscribePostHeader - Value of the List-Unsubscribe-Post header
     * @param {object} payload - Gmail message payload (for body fallback)
     * @returns {object} Structured unsubscribe data:
     *   - httpUrls: string[] — HTTP(S) URLs from the header
     *   - mailtoUrl: string|null — First mailto: URL from the header
     *   - bodyUrl: string|null — URL from email body HTML (fallback)
     *   - hasListUnsubscribePost: boolean — RFC 8058 support
     *   - primaryUrl: string|null — Best available URL for display/backward compat
     */
    extractUnsubscribeData(listUnsubscribeHeader, listUnsubscribePostHeader, payload) {
        const httpUrls = [];
        let mailtoUrl = null;
        let bodyUrl = null;

        // Parse all URLs from the List-Unsubscribe header (RFC 2369)
        // Format: <url1>, <url2>, ... — angle-bracket delimited, comma-separated
        if (listUnsubscribeHeader) {
            const urlMatches = listUnsubscribeHeader.matchAll(/<([^>]+)>/g);
            for (const match of urlMatches) {
                const url = match[1].trim();
                if (/^https?:\/\//i.test(url)) {
                    // HTTP or HTTPS URL
                    httpUrls.push(url);
                } else if (/^mailto:/i.test(url) && !mailtoUrl) {
                    // mailto URL — keep only the first one
                    mailtoUrl = url;
                }
            }
        }

        // Fallback: search the email body HTML for an unsubscribe link
        // Only used if no header URLs were found
        if (httpUrls.length === 0 && !mailtoUrl) {
            const htmlBody = this.getEmailBody(payload);
            if (htmlBody) {
                const unsubscribeMatch = htmlBody.match(
                    /<a[^>]*href=["']([^"']*unsubscribe[^"']*)["'][^>]*>/i
                );
                if (unsubscribeMatch) {
                    bodyUrl = unsubscribeMatch[1];
                }
            }
        }

        // Check for RFC 8058 List-Unsubscribe-Post header
        // Value is typically: "List-Unsubscribe=One-Click-Unsubscribe-Post"
        const hasListUnsubscribePost = !!(
            listUnsubscribePostHeader &&
            listUnsubscribePostHeader.trim().length > 0
        );

        // Primary URL for backward compatibility with iOS app:
        // prefer first HTTP URL from header, then body URL
        const primaryUrl = httpUrls[0] || bodyUrl || null;

        return {
            httpUrls,
            mailtoUrl,
            bodyUrl,
            hasListUnsubscribePost,
            primaryUrl
        };
    }

    /**
     * Cleans a "From" header to extract just the sender name.
     * Strips email address portion and surrounding quotes.
     * Example: '"Newsletter Team" <news@example.com>' → 'Newsletter Team'
     *
     * @param {string} from - Raw From header value
     * @returns {string} Cleaned sender name
     */
    cleanSender(from) {
        // Extract name from "Name <email@domain.com>" format
        const nameMatch = from.match(/^([^<]+)</);
        if (nameMatch) {
            return nameMatch[1].trim().replace(/['"]/g, '');
        }
        return from;
    }

    /**
     * Extracts the domain from a sender string for deduplication.
     *
     * @param {string} from - Sender string (may contain name and email)
     * @returns {string} Domain portion of the email address
     */
    extractDomain(from) {
        const emailMatch = from.match(/[\w.-]+@([\w.-]+)/);
        return emailMatch ? emailMatch[1] : from;
    }

    /**
     * Extracts the full sender address for dedupe against past decisions.
     * The address, not the domain, is the identity of a mailing list:
     * platforms like Substack put many unrelated newsletters on one domain.
     *
     * @param {string} from - Raw From header value
     * @returns {string} Lowercased address, or the input when no address is found
     */
    extractSenderAddress(from) {
        const emailMatch = from.match(/[\w.+-]+@[\w.-]+/);
        return (emailMatch ? emailMatch[0] : from).toLowerCase();
    }

    /**
     * Executes the unsubscribe action for an email.
     *
     * Delegates to UnsubscribeService for the actual HTTP/mailto execution,
     * then always marks the email as read regardless of unsubscribe outcome.
     * This ensures the email is processed even if unsubscribe fails.
     *
     * @param {string} messageId - Gmail message ID
     * @param {object} unsubscribeData - Structured data from extractUnsubscribeData()
     * @returns {Promise<object>} Result with processing status and unsubscribe details
     */
    async unsubscribe(messageId, unsubscribeData) {
        const unsubService = new UnsubscribeService();

        // Step 1: Execute actual unsubscribe via the cascade
        let unsubscribeResult;
        try {
            unsubscribeResult = await unsubService.execute({
                httpUrls: unsubscribeData.httpUrls || [],
                mailtoUrl: unsubscribeData.mailtoUrl || null,
                bodyUrl: unsubscribeData.bodyUrl || null,
                hasListUnsubscribePost: unsubscribeData.hasListUnsubscribePost || false,
                gmailService: this     // Pass self for mailto fallback (if scope available)
            });
        } catch (error) {
            // Unsubscribe execution failed — log but don't block email processing
            console.error('Error during unsubscribe execution:', error.message);
            unsubscribeResult = {
                success: false,
                method: null,
                attempted: [],
                error: error.message
            };
        }

        // Step 2: Always mark the email as read (preserves original behavior)
        try {
            await this.gmail.users.messages.modify({
                userId: 'me',
                id: messageId,
                requestBody: {
                    removeLabelIds: ['UNREAD'],
                    addLabelIds: []
                }
            });
        } catch (error) {
            console.error('Error marking email as read:', error.message);
        }

        // Step 3: Return combined result
        return {
            success: true,    // The email "processing" always succeeds
            unsubscribeResult: unsubscribeResult,
            message: unsubscribeResult.success
                ? `Unsubscribed via ${unsubscribeResult.method}`
                : 'Email processed but unsubscribe may not have completed'
        };
    }

    /**
     * Sends an email via Gmail API.
     * Used by UnsubscribeService for mailto-based unsubscribe.
     * Requires gmail.send scope in the OAuth credentials.
     *
     * @param {string} to - Recipient email address
     * @param {string} subject - Email subject (defaults to 'Unsubscribe')
     * @param {string} body - Email body (can be empty for unsubscribe requests)
     * @returns {Promise<void>}
     */
    async sendEmail(to, subject, body) {
        // Construct a minimal RFC 2822 email message
        const emailLines = [
            `To: ${to}`,
            `Subject: ${subject || 'Unsubscribe'}`,
            'Content-Type: text/plain; charset=utf-8',
            '',
            body || ''
        ];
        const rawEmail = emailLines.join('\r\n');

        // Base64url encode the raw message (required by Gmail API)
        const encodedMessage = Buffer.from(rawEmail)
            .toString('base64')
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/, '');

        // Send via Gmail API
        await this.gmail.users.messages.send({
            userId: 'me',
            requestBody: { raw: encodedMessage }
        });
    }
}

module.exports = GmailService;
