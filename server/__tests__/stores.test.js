/**
 * Integration tests for userStore and decisionStore against a real Postgres.
 *
 * Runs only when TEST_DATABASE_URL is set (CI provides a service container;
 * locally: docker run -e POSTGRES_PASSWORD=unpile -e POSTGRES_DB=unpile_test -p 5433:5432 postgres:16-alpine
 * then TEST_DATABASE_URL=postgres://postgres:unpile@localhost:5433/unpile_test npm test).
 */

const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
const describeWithDb = TEST_DATABASE_URL ? describe : describe.skip;

describeWithDb('stores (Postgres)', () => {
    let db, userStore, decisionStore;

    beforeAll(async () => {
        process.env.DATABASE_URL = TEST_DATABASE_URL;
        db = require('../db');
        userStore = require('../userStore');
        decisionStore = require('../decisionStore');
        await db.initSchema();
    });

    beforeEach(async () => {
        await db.pool.query('TRUNCATE users, decisions');
    });

    afterAll(async () => {
        await db.pool.end();
    });

    describe('userStore', () => {
        test('createUser returns the camelCase record shape with ISO timestamps', async () => {
            const user = await userStore.createUser({
                appleUserId: 'apple-sub-1',
                email: 'a@privaterelay.appleid.com',
                name: 'Ada',
                authProvider: 'apple'
            });

            expect(user.id).toMatch(/^[0-9a-f-]{36}$/);
            expect(user).toMatchObject({
                appleUserId: 'apple-sub-1',
                email: 'a@privaterelay.appleid.com',
                name: 'Ada',
                authProvider: 'apple',
                gmailTokens: null,
                gmailEmail: null
            });
            expect(new Date(user.createdAt).toISOString()).toBe(user.createdAt);
            expect(new Date(user.lastLoginAt).toISOString()).toBe(user.lastLoginAt);
        });

        test('findByAppleId and findById round-trip; unknown ids return null', async () => {
            const created = await userStore.createUser({
                appleUserId: 'apple-sub-2', email: 'b@example.com', authProvider: 'apple'
            });

            expect(await userStore.findByAppleId('apple-sub-2')).toEqual(created);
            expect(await userStore.findById(created.id)).toEqual(created);
            expect(await userStore.findByAppleId('nope')).toBeNull();
            expect(await userStore.findById('00000000-0000-0000-0000-000000000000')).toBeNull();
        });

        test('findByEmail matches on email', async () => {
            const created = await userStore.createUser({
                email: 'c@example.com', authProvider: 'google'
            });
            expect(await userStore.findByEmail('c@example.com')).toEqual(created);
            expect(await userStore.findByEmail('missing@example.com')).toBeNull();
        });

        test('updateUser merges partial fields and preserves the JSON token blob', async () => {
            const created = await userStore.createUser({
                appleUserId: 'apple-sub-3', email: 'd@example.com', authProvider: 'apple'
            });
            const tokens = { access_token: 'at', refresh_token: 'rt', expiry_date: 1234 };

            const updated = await userStore.updateUser(created.id, {
                gmailTokens: tokens,
                gmailEmail: 'd@gmail.com'
            });

            expect(updated.gmailTokens).toEqual(tokens);
            expect(updated.gmailEmail).toBe('d@gmail.com');
            expect(updated.name).toBeNull();
            expect(await userStore.findById(created.id)).toEqual(updated);
        });

        test('updateUser rejects fields that are not columns', async () => {
            const created = await userStore.createUser({ email: 'e@example.com', authProvider: 'google' });
            await expect(userStore.updateUser(created.id, { isAdmin: true })).rejects.toThrow('unknown field');
        });

        test('updateUser returns null for a missing user', async () => {
            const result = await userStore.updateUser('00000000-0000-0000-0000-000000000000', { name: 'x' });
            expect(result).toBeNull();
        });

        test('deleteUser reports whether a row was removed', async () => {
            const created = await userStore.createUser({ email: 'f@example.com', authProvider: 'google' });
            expect(await userStore.deleteUser(created.id)).toBe(true);
            expect(await userStore.deleteUser(created.id)).toBe(false);
            expect(await userStore.findById(created.id)).toBeNull();
        });

        test('appleUserId is unique', async () => {
            await userStore.createUser({ appleUserId: 'dup', email: 'g@example.com', authProvider: 'apple' });
            await expect(
                userStore.createUser({ appleUserId: 'dup', email: 'h@example.com', authProvider: 'apple' })
            ).rejects.toThrow();
        });
    });

    describe('decisionStore', () => {
        test('stats are scoped to the user key', async () => {
            await decisionStore.recordDecision('user-1', { emailId: 'm1', decision: 'unsubscribe', unsubscribeMethod: 'one-click' });
            await decisionStore.recordDecision('user-1', { emailId: 'm2', decision: 'keep' });
            await decisionStore.recordDecision('user-1', { emailId: 'm3', decision: 'unsubscribe', unsubscribeMethod: null });
            await decisionStore.recordDecision('google:other@gmail.com', { emailId: 'm9', decision: 'unsubscribe' });

            expect(await decisionStore.getStats('user-1')).toEqual({ totalDecisions: 3, totalUnsubscribes: 2 });
            expect(await decisionStore.getStats('google:other@gmail.com')).toEqual({ totalDecisions: 1, totalUnsubscribes: 1 });
            expect(await decisionStore.getStats('nobody')).toEqual({ totalDecisions: 0, totalUnsubscribes: 0 });
        });
    });
});
