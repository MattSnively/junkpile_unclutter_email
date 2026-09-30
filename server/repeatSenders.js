/**
 * repeatSenders.js — spotting senders who keep emailing after an unsubscribe.
 *
 * Mail stopping is the only real proof an unsubscribe worked. CAN-SPAM gives
 * senders 10 business days to honor a request, so mail that arrives after
 * that window means the sender is likely ignoring it.
 */

const GRACE_BUSINESS_DAYS = 10;

/**
 * Adds weekdays to a date, skipping Saturdays and Sundays. Public holidays
 * are ignored: a day early is harmless here, it only brings a warning forward.
 * Works in UTC so the result doesn't depend on the server's time zone.
 *
 * @param {Date} date
 * @param {number} days
 * @returns {Date}
 */
function addBusinessDays(date, days) {
    const result = new Date(date.getTime());
    let remaining = days;
    while (remaining > 0) {
        result.setUTCDate(result.getUTCDate() + 1);
        const weekday = result.getUTCDay();
        if (weekday !== 0 && weekday !== 6) remaining -= 1;
    }
    return result;
}

/**
 * For each unsubscribed sender, when they unsubscribed and after when new
 * mail from them counts as ignoring the request.
 *
 * @param {Map<string, Date>} unsubscribedAt - Sender address -> latest unsubscribe
 * @returns {Map<string, {unsubscribedAt: Date, deadline: Date}>}
 */
function repeatSenderWindows(unsubscribedAt) {
    const windows = new Map();
    for (const [sender, date] of unsubscribedAt) {
        windows.set(sender, { unsubscribedAt: date, deadline: addBusinessDays(date, GRACE_BUSINESS_DAYS) });
    }
    return windows;
}

module.exports = { GRACE_BUSINESS_DAYS, addBusinessDays, repeatSenderWindows };
