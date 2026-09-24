/**
 * Guards against Gmail credentials leaking between concurrent requests.
 *
 * A single shared OAuth2 client once carried each request's token; because
 * googleapis reads credentials when a call is sent, an overlapping request
 * from another user could swap in their token and receive the wrong inbox.
 */

const fs = require('fs');
const path = require('path');
const { oauthClientFor } = require('../oauthClient');

async function bearer(client) {
    const headers = await client.getRequestHeaders();
    return typeof headers.get === 'function' ? headers.get('authorization') : headers.Authorization;
}

test('overlapping requests each keep their own token', async () => {
    async function handle(user, delayMs) {
        const client = oauthClientFor({ access_token: `token-of-${user}` });
        await new Promise(resolve => setTimeout(resolve, delayMs));
        return bearer(client);
    }

    const [alice, bob] = await Promise.all([handle('alice', 30), handle('bob', 5)]);

    expect(alice).toBe('Bearer token-of-alice');
    expect(bob).toBe('Bearer token-of-bob');
});

// The helper only helps if routes use it; a source check is the cheapest way
// to stop someone reintroducing setCredentials on the shared client.
test('server.js never puts user credentials on the shared client', () => {
    const source = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
    expect(source).not.toMatch(/oauth2Client\.setCredentials/);
    expect(source).not.toMatch(/new GmailService\(oauth2Client\)/);
    expect(source).not.toMatch(/auth:\s*oauth2Client\b/);
});

describe('withGrantedScope', () => {
    const { withGrantedScope } = require('../oauthClient');
    const SEND = 'https://www.googleapis.com/auth/gmail.send';

    beforeEach(() => {
        global.fetch = jest.fn();
        jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    test('keeps a scope that was stored at connect time', async () => {
        const tokens = { access_token: 'stored', scope: SEND };
        await expect(withGrantedScope(tokens)).resolves.toBe(tokens);
        expect(global.fetch).not.toHaveBeenCalled();
    });

    test('looks the scope up once per token and caches it', async () => {
        global.fetch.mockResolvedValue({ ok: true, json: async () => ({ scope: SEND, expires_in: '3599' }) });

        const first = await withGrantedScope({ access_token: 'bare-token' });
        const second = await withGrantedScope({ access_token: 'bare-token' });

        expect(first.scope).toBe(SEND);
        expect(second.scope).toBe(SEND);
        expect(global.fetch).toHaveBeenCalledTimes(1);
        expect(global.fetch.mock.calls[0][0]).toContain('tokeninfo?access_token=bare-token');
    });

    test('falls back to the tokens unchanged when the lookup fails', async () => {
        global.fetch.mockResolvedValue({ ok: false, status: 400 });
        const tokens = { access_token: 'expired-token' };
        await expect(withGrantedScope(tokens)).resolves.toBe(tokens);

        global.fetch.mockRejectedValue(new Error('network down'));
        const other = { access_token: 'offline-token' };
        await expect(withGrantedScope(other)).resolves.toBe(other);
    });

    test('passes through missing tokens', async () => {
        await expect(withGrantedScope(null)).resolves.toBeNull();
    });
});
