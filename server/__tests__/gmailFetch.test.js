/**
 * Tests for GmailService batch building: paging, decided-sender exclusion,
 * and sender-address extraction. The Gmail client is stubbed.
 */

const GmailService = require('../gmailService');

/**
 * Builds a fake inbox. Each message is { id, from, unsub } and pages are
 * served in the given order with nextPageToken links between them.
 */
function stubGmail(service, pages) {
    const byId = new Map();
    for (const page of pages) for (const m of page) byId.set(m.id, m);

    const listCalls = [];
    service.gmail = {
        users: {
            messages: {
                list: jest.fn(async ({ pageToken }) => {
                    const index = pageToken ? Number(pageToken) : 0;
                    listCalls.push(index);
                    const page = pages[index] || [];
                    const next = index + 1 < pages.length ? String(index + 1) : undefined;
                    return { data: { messages: page.map(m => ({ id: m.id })), nextPageToken: next } };
                }),
                get: jest.fn(async ({ id, format }) => {
                    const m = byId.get(id);
                    const headers = [{ name: 'From', value: m.from }];
                    if (format === 'metadata') {
                        return { data: { payload: { headers } } };
                    }
                    if (m.unsub !== false) {
                        headers.push({ name: 'List-Unsubscribe', value: '<https://example.com/u>' });
                    }
                    return { data: { snippet: '', payload: { headers, mimeType: 'text/plain', body: {} } } };
                })
            }
        }
    };
    return { listCalls, get: service.gmail.users.messages.get };
}

describe('GmailService batch building', () => {
    let service;

    beforeEach(() => {
        service = new GmailService({ credentials: {} });
        jest.spyOn(console, 'log').mockImplementation(() => {});
        jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => jest.restoreAllMocks());

    test('dedupes by sender address within a batch', async () => {
        stubGmail(service, [[
            { id: 'a', from: 'News <news@one.com>' },
            { id: 'b', from: 'News <NEWS@one.com>' },
            { id: 'c', from: 'Other <other@two.com>' }
        ]]);

        const emails = await service.getEmailsWithUnsubscribe();
        expect(emails.map(e => e.id)).toEqual(['a', 'c']);
    });

    test('skips decided message IDs without fetching them', async () => {
        const { get } = stubGmail(service, [[
            { id: 'a', from: 'a@one.com' },
            { id: 'b', from: 'b@two.com' }
        ]]);

        const emails = await service.getEmailsWithUnsubscribe({ excludeIds: new Set(['a']) });
        expect(emails.map(e => e.id)).toEqual(['b']);
        expect(get).not.toHaveBeenCalledWith(expect.objectContaining({ id: 'a' }));
    });

    test('skips decided senders even when the message is new', async () => {
        stubGmail(service, [[
            { id: 'new-msg', from: 'Weekly <weekly@one.com>' },
            { id: 'other', from: 'other@two.com' }
        ]]);

        const emails = await service.getEmailsWithUnsubscribe({ excludeSenders: new Set(['weekly@one.com']) });
        expect(emails.map(e => e.id)).toEqual(['other']);
    });

    test('pages until the batch is full', async () => {
        const page = (n) => Array.from({ length: 3 }, (_, i) => ({ id: `${n}-${i}`, from: `s${n}${i}@x.com` }));
        const { listCalls } = stubGmail(service, [page(0), page(1), page(2)]);

        const emails = await service.getEmailsWithUnsubscribe({ limit: 5 });
        expect(emails).toHaveLength(5);
        expect(listCalls).toEqual([0, 1]);
    });

    test('stops at the scan cap when everything is already decided', async () => {
        const page = (n) => Array.from({ length: 3 }, (_, i) => ({ id: `${n}-${i}`, from: `s@x.com` }));
        const { listCalls } = stubGmail(service, [page(0), page(1), page(2), page(3)]);

        const emails = await service.getEmailsWithUnsubscribe({
            excludeSenders: new Set(['s@x.com']), limit: 20, maxScan: 6
        });
        expect(emails).toEqual([]);
        expect(listCalls).toEqual([0, 1]);
    });

    test('returns an empty batch when the inbox has no matches', async () => {
        service.gmail = { users: { messages: { list: jest.fn(async () => ({ data: {} })) } } };
        expect(await service.getEmailsWithUnsubscribe()).toEqual([]);
    });

    test('ignores messages without an unsubscribe option', async () => {
        stubGmail(service, [[
            { id: 'a', from: 'a@one.com', unsub: false },
            { id: 'b', from: 'b@two.com' }
        ]]);
        const emails = await service.getEmailsWithUnsubscribe();
        expect(emails.map(e => e.id)).toEqual(['b']);
    });

    test('getSenderAddress reads only the From header', async () => {
        const { get } = stubGmail(service, [[{ id: 'a', from: 'Name <Person+tag@Example.com>' }]]);
        expect(await service.getSenderAddress('a')).toBe('person+tag@example.com');
        expect(get).toHaveBeenCalledWith(expect.objectContaining({ format: 'metadata', metadataHeaders: ['From'] }));
    });

    test('getSenderAddress returns null when Gmail fails', async () => {
        service.gmail = { users: { messages: { get: jest.fn(async () => { throw new Error('boom'); }) } } };
        expect(await service.getSenderAddress('a')).toBeNull();
    });
});

describe('countUnsubscribeSenders', () => {
    let service;

    beforeEach(() => {
        service = new GmailService({ credentials: {} });
        jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => jest.restoreAllMocks());

    test('counts distinct senders, case-insensitively', async () => {
        stubGmail(service, [[
            { id: 'a', from: 'One <news@one.com>' },
            { id: 'b', from: 'One Again <NEWS@one.com>' },
            { id: 'c', from: 'Two <hi@two.com>' }
        ]]);

        const result = await service.countUnsubscribeSenders();
        expect(result).toMatchObject({ uniqueSenders: 2, scanned: 3 });
    });

    test('excludes senders the user already decided on', async () => {
        stubGmail(service, [[
            { id: 'a', from: 'news@one.com' },
            { id: 'b', from: 'hi@two.com' }
        ]]);

        const result = await service.countUnsubscribeSenders({ excludeSenders: new Set(['news@one.com']) });
        expect(result.uniqueSenders).toBe(1);
    });

    test('does not scale the sample up to the match estimate', async () => {
        const service2 = new GmailService({ credentials: {} });
        service2.gmail = {
            users: {
                messages: {
                    list: jest.fn(async () => ({ data: { messages: [{ id: 'a' }], resultSizeEstimate: 900 } })),
                    get: jest.fn(async () => ({ data: { payload: { headers: [{ name: 'From', value: 'a@x.com' }] } } }))
                }
            }
        };

        const result = await service2.countUnsubscribeSenders();
        expect(result).toEqual({ uniqueSenders: 1, scanned: 1, totalMatchesEstimate: 900 });
    });

    test('returns zero for an inbox with no matches', async () => {
        service.gmail = { users: { messages: { list: jest.fn(async () => ({ data: {} })) } } };
        expect(await service.countUnsubscribeSenders()).toEqual({
            uniqueSenders: 0, scanned: 0, totalMatchesEstimate: 0
        });
    });

    test('skips messages whose sender could not be read', async () => {
        service.gmail = {
            users: {
                messages: {
                    list: jest.fn(async () => ({ data: { messages: [{ id: 'a' }, { id: 'b' }], resultSizeEstimate: 2 } })),
                    get: jest.fn(async ({ id }) => {
                        if (id === 'a') throw new Error('boom');
                        return { data: { payload: { headers: [{ name: 'From', value: 'b@x.com' }] } } };
                    })
                }
            }
        };

        const result = await service.countUnsubscribeSenders();
        expect(result).toMatchObject({ uniqueSenders: 1, scanned: 2 });
    });
});

describe('extractSenderAddress', () => {
    const service = new GmailService({ credentials: {} });

    test.each([
        ['Name <news@Example.com>', 'news@example.com'],
        ['plain@example.com', 'plain@example.com'],
        ['"Quoted, Name" <a.b+c@sub.example.co.uk>', 'a.b+c@sub.example.co.uk'],
        ['no address here', 'no address here']
    ])('%p -> %p', (input, expected) => {
        expect(service.extractSenderAddress(input)).toBe(expected);
    });
});
