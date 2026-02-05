const { google } = require('googleapis');

class GmailService {
    constructor(oauth2Client) {
        this.oauth2Client = oauth2Client;
        this.gmail = google.gmail({ version: 'v1', auth: oauth2Client });
    }

    async getEmailsWithUnsubscribe() {
        try {
            // Search for emails with unsubscribe links in the last 30 days
            const response = await this.gmail.users.messages.list({
                userId: 'me',
                q: 'unsubscribe OR list-unsubscribe newer_than:30d',
                maxResults: 50
            });

            if (!response.data.messages) {
                return [];
            }

            // Fetch full details for each email
            const emails = await Promise.all(
                response.data.messages.map(msg => this.getEmailDetails(msg.id))
            );

            // Filter and deduplicate by sender domain
            const seenDomains = new Set();
            const uniqueEmails = [];

            for (const email of emails) {
                if (email && email.unsubscribeUrl) {
                    const domain = this.extractDomain(email.sender);
                    if (!seenDomains.has(domain)) {
                        seenDomains.add(domain);
                        uniqueEmails.push(email);
                    }
                }
            }

            return uniqueEmails;
        } catch (error) {
            console.error('Error fetching emails:', error);
            throw error;
        }
    }

    async getEmailDetails(messageId) {
        try {
            const response = await this.gmail.users.messages.get({
                userId: 'me',
                id: messageId,
                format: 'full'
            });

            const message = response.data;
            const headers = message.payload.headers;

            const getHeader = (name) => {
                const header = headers.find(h => h.name.toLowerCase() === name.toLowerCase());
                return header ? header.value : '';
            };

            const from = getHeader('From');
            const subject = getHeader('Subject');
            const listUnsubscribe = getHeader('List-Unsubscribe');

            // Extract unsubscribe URL
            const unsubscribeUrl = this.extractUnsubscribeUrl(listUnsubscribe, message.payload);

            // Get email body HTML
            const htmlBody = this.getEmailBody(message.payload);

            return {
                id: messageId,
                sender: this.cleanSender(from),
                subject: subject,
                htmlBody: htmlBody,
                unsubscribeUrl: unsubscribeUrl,
                rawHeaders: {
                    from,
                    listUnsubscribe
                }
            };
        } catch (error) {
            console.error('Error fetching email details:', error);
            return null;
        }
    }

    getEmailBody(payload) {
        let htmlBody = '';

        if (payload.parts) {
            // Multipart email
            for (const part of payload.parts) {
                if (part.mimeType === 'text/html' && part.body.data) {
                    htmlBody = Buffer.from(part.body.data, 'base64').toString('utf-8');
                    break;
                } else if (part.parts) {
                    // Nested parts
                    htmlBody = this.getEmailBody(part);
                    if (htmlBody) break;
                }
            }
        } else if (payload.body && payload.body.data) {
            // Simple email body
            if (payload.mimeType === 'text/html') {
                htmlBody = Buffer.from(payload.body.data, 'base64').toString('utf-8');
            }
        }

        return htmlBody;
    }

    extractUnsubscribeUrl(listUnsubscribeHeader, payload) {
        // Try to get from List-Unsubscribe header first
        if (listUnsubscribeHeader) {
            const urlMatch = listUnsubscribeHeader.match(/<(https?:\/\/[^>]+)>/);
            if (urlMatch) {
                return urlMatch[1];
            }
        }

        // Fallback: search in email body
        const htmlBody = this.getEmailBody(payload);
        if (htmlBody) {
            const unsubscribeMatch = htmlBody.match(/<a[^>]*href=["']([^"']*unsubscribe[^"']*)["'][^>]*>/i);
            if (unsubscribeMatch) {
                return unsubscribeMatch[1];
            }
        }

        return null;
    }

    cleanSender(from) {
        // Extract name from "Name <email@domain.com>" format
        const nameMatch = from.match(/^([^<]+)</);
        if (nameMatch) {
            return nameMatch[1].trim().replace(/['"]/g, '');
        }
        return from;
    }

    extractDomain(from) {
        const emailMatch = from.match(/[\w.-]+@([\w.-]+)/);
        return emailMatch ? emailMatch[1] : from;
    }

    async unsubscribe(messageId, unsubscribeUrl) {
        // Note: Actual unsubscribe would require opening the URL or sending POST request
        // For now, we'll just mark as read and archive
        try {
            await this.gmail.users.messages.modify({
                userId: 'me',
                id: messageId,
                requestBody: {
                    removeLabelIds: ['UNREAD'],
                    addLabelIds: []
                }
            });

            return {
                success: true,
                message: 'Email marked as processed',
                unsubscribeUrl: unsubscribeUrl
            };
        } catch (error) {
            console.error('Error processing unsubscribe:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

module.exports = GmailService;
