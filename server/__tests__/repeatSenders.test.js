/**
 * Tests for the CAN-SPAM grace window used to flag senders who keep
 * emailing after an unsubscribe.
 */

const { addBusinessDays, repeatSenderWindows } = require('../repeatSenders');

const utc = (iso) => new Date(`${iso}T14:32:41Z`);

describe('addBusinessDays', () => {
    test('10 business days from a Thursday lands on the Thursday two weeks later', () => {
        // The Ranger Station unsubscribe: Thu 2026-09-24 -> Thu 2026-10-08
        expect(addBusinessDays(utc('2026-09-24'), 10).toISOString()).toBe(utc('2026-10-08').toISOString());
    });

    test('skips the weekend', () => {
        expect(addBusinessDays(utc('2026-09-25'), 1).toISOString()).toBe(utc('2026-09-28').toISOString());
    });

    test('from a Saturday, the first business day is Monday', () => {
        expect(addBusinessDays(utc('2026-09-26'), 1).toISOString()).toBe(utc('2026-09-28').toISOString());
    });

    test('does not modify the input date', () => {
        const date = utc('2026-09-24');
        addBusinessDays(date, 10);
        expect(date.toISOString()).toBe(utc('2026-09-24').toISOString());
    });
});

describe('repeatSenderWindows', () => {
    test('pairs each sender with its unsubscribe date and deadline', () => {
        const windows = repeatSenderWindows(new Map([['news@rangerstation.test', utc('2026-09-24')]]));
        expect(windows.get('news@rangerstation.test')).toEqual({
            unsubscribedAt: utc('2026-09-24'),
            deadline: utc('2026-10-08')
        });
    });
});
