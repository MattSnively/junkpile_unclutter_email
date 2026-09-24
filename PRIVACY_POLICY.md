# Privacy Policy for Unpile

**Last Updated: September 23, 2026**

## Introduction

Unpile ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use the Unpile mobile application (the "App").

**Our Core Privacy Commitment: We only touch your email to help you unsubscribe. We never store your messages, and we never sell, share, or analyze your email data for advertising.**

## Information We Do NOT Collect or Do

- **We DO NOT store the content of your emails**
- **We DO NOT analyze your email content for advertising or profiling**
- **We DO NOT sell your data to third parties**
- **We DO NOT share your email data with anyone, except the unsubscribe request itself (see "Unsubscribe Requests" below)**
- **We DO NOT use your email data for machine learning or AI training**
- **We DO NOT delete your emails**

## Email Data We Process But Do Not Store

To find subscription emails and show them to you, our servers read messages from your Gmail account that mention unsubscribing, from the last 30 days:

- **Message headers** — sender, subject, and the List-Unsubscribe headers senders include for this purpose
- **Message body** — scanned for an unsubscribe link when the headers don't provide one, and used for the short preview shown on each card

This processing happens in memory while you use the App. We do not save message bodies, subjects, or previews on our servers.

## Information We Store

### On Our Servers

**Account information**
- **User ID** (an internal ID, plus your Apple user identifier if you sign in with Apple)
- **Email address** and **name** (name only if Apple provides it on first sign-in)
- **Connected Gmail address** (Apple Sign-In users who connect Gmail)

**Your swipe decisions**
For each email you keep or unsubscribe from, we store:
- The Gmail message ID
- The sender's email address
- Your decision (keep or unsubscribe) and which unsubscribe method was used
- When you made it

We use these records so the App doesn't show you the same email or sender again, and to calculate your statistics. They do not include subjects or message content.

**Authentication tokens (Apple Sign-In users only)**
- **Gmail access and refresh tokens**, so we can reach Gmail on your behalf. These are encrypted at rest (AES-256-GCM).
- **Apple refresh token**, kept only so we can revoke your Sign in with Apple link when you delete your account. It is also encrypted at rest.
- **Session tokens** that expire after 7 days. These are signed and are not stored in our database.

If you sign in with Google, your Google tokens stay on your device. We receive your access token with each request and don't store it.

### On Your Device

The App stores your progress locally on your iPhone: XP, level, achievements, streaks, session history, and a record of your decisions (sender, subject, and unsubscribe result). Authentication tokens are stored in the iOS Keychain. Deleting the App removes this data from your device.

## How We Use Your Gmail Access

Unpile requests these Google permissions:

| Permission | Why we need it |
|---|---|
| `gmail.readonly` | To find subscription emails and read their unsubscribe information |
| `gmail.modify` | To mark an email as read after you unsubscribe from it |
| `gmail.send` | To send an unsubscribe email on your behalf when a sender only accepts unsubscribes by email |

You can decline `gmail.send` on Google's consent screen. If you do, Unpile skips senders that can only be unsubscribed by email.

We do not use these permissions to delete emails, to send any email other than an unsubscribe request you asked for, or to access any other Google service.

### Google API Services User Data Policy

Unpile's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements. We use Gmail data only to provide the App's unsubscribe features to you. We do not transfer it to others except as needed to carry out your unsubscribe request, for security, or to comply with law. We do not use it for advertising, and no human reads it unless you ask us to for support, it's needed for security, or the law requires it.

## Unsubscribe Requests

When you swipe left to unsubscribe, Unpile contacts the sender using the method the sender provided:
- **A web request** from our servers to the sender's unsubscribe link, or
- **An unsubscribe email** sent from your Gmail account to the address the sender listed (these appear in your Sent folder)

Either way, the sender learns that your address asked to unsubscribe. That is how unsubscribing works. We don't send the sender anything else about you.

## Data Storage and Security

- **Hosting:** Our servers and database run on Railway in the United States (US West).
- **In transit:** All traffic between the App and our servers uses HTTPS/TLS.
- **At rest:** OAuth tokens are encrypted before they reach the database.
- **Authentication:** Sign in with Apple and Google OAuth 2.0. Unpile never sees or stores your passwords.
- **Logs:** Server logs record the sender's domain and the result of an unsubscribe attempt, not your address or message content.

### Data Retention
- **Message content, subjects, previews:** Not stored
- **Account data and swipe decisions:** Kept until you delete your account
- **Session tokens:** Expire after 7 days

## Third-Party Services

- **Apple (Sign in with Apple):** provides a user identifier, your email (or a private relay address), and your name on first sign-in. [Apple Privacy Policy](https://www.apple.com/legal/privacy/)
- **Google (Sign-In and Gmail API):** provides your email address and the access tokens described above. [Google Privacy Policy](https://policies.google.com/privacy)
- **Railway:** hosts our servers and database.
- **Analytics:** We use only Apple's built-in App Analytics (App Store Connect), and we don't use third-party analytics or crash-reporting SDKs. If that changes, we will update this policy first.

## Your Privacy Rights

### Access and Deletion
- **Access your data:** Email support@junkpile.app to request a copy of the data we store about you.
- **Delete your account:** In the App, go to Settings > Delete Account. This permanently deletes your account and swipe decisions from our servers. It also revokes Unpile's access to your Google account and, if you used Sign in with Apple, your Apple ID link.

### Revoke Access Without Deleting
- **Google/Gmail:** Remove Unpile at https://myaccount.google.com/permissions
- **Sign in with Apple:** iOS Settings > [your name] > Sign-In & Security > Sign in with Apple > Unpile > Stop Using

### Notifications
Streak and session reminders are local notifications scheduled on your device. Turn them off in the App (Settings > Notifications) or in iOS Settings > Notifications > Unpile.

## Children's Privacy

Unpile is not directed to children under 13, and we do not knowingly collect personal information from them. If you believe a child under 13 has used Unpile, please contact support@junkpile.app.

## Data Sharing and Disclosure

We will never sell your personal information or email data. We disclose information only:
- **To carry out an unsubscribe you requested**, as described above
- **For legal compliance:** if required by law, court order, or government request
- **For safety and security:** to protect the rights, property, or safety of Unpile, our users, or the public
- **In a business transfer:** if Unpile is merged or sold, your data may transfer to the new owner. You will be notified first and can delete your account before the transfer.

## International Data Transfers

Our servers are located in the United States. If you use Unpile from elsewhere, your data is transferred to and processed there. We comply with applicable data protection laws, including GDPR (for users in the EU) and CCPA (for California residents).

## Changes to This Privacy Policy

When we update this policy, we will change the "Last Updated" date above. For material changes, we will also notify you in the App. Continuing to use the App after a change means you accept the updated policy.

## Contact Us

**Email:** support@junkpile.app
**Website:** [WEBSITE — to be added]
**Mail:** [MAILING ADDRESS — if required by jurisdiction]

---

## Summary

✅ **We DO:**
- Read subscription emails from the last 30 days to find unsubscribe options and show you a preview
- Store your account, your keep/unsubscribe decisions (message ID and sender address), and, for Apple Sign-In users, encrypted Gmail tokens
- Send an unsubscribe request or email on your behalf when you swipe left

❌ **We DO NOT:**
- Store your email content, subjects, or previews on our servers
- Delete your emails
- Sell your data, or use your email for advertising, profiling, or AI training

🔒 **Your Control:**
- Delete your account and all server data anytime (Settings > Delete Account)
- Revoke Gmail access anytime (Google Account settings)
- Decline the send permission, and Unpile will skip email-only unsubscribes

**Questions? Email support@junkpile.app**
