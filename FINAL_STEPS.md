> **ARCHIVED 2026-07-13 — task tracking moved to beads.** See epic `junkpile_unclutter_email-e0z` (App Store v1.0 submission). Note: steps 1–2 are already done (legal docs live on GitHub Pages, real URLs in SettingsView). Kept for historical context; do not update.

# 🚦 FINAL 3 STEPS TO LAUNCH

## Your Status: 95% Complete! 🎯

You've built an amazing app. Here are the **only 3 things** standing between you and App Store submission:

---

## Step 1: Host Your Legal Documents (10 minutes)

### Quick Option: GitHub Pages

1. **Go to your GitHub repo settings:**
   ```
   https://github.com/[your-username]/junkpile_unclutter_email/settings/pages
   ```

2. **Enable Pages:**
   - Source: `main` branch
   - Folder: `/web`
   - Click "Save"

3. **Wait 2-3 minutes**, then test:
   ```
   https://[your-username].github.io/junkpile_unclutter_email/privacy.html
   https://[your-username].github.io/junkpile_unclutter_email/terms.html
   ```

4. **Copy those URLs** - you'll need them in Step 2

---

## Step 2: Update the iOS App (5 minutes)

**File:** `ios/Junkpile/Junkpile/Views/Settings/SettingsView.swift`

**Find these lines and replace with your URLs from Step 1:**

```swift
// Line 331 - Change this:
if let privacyURL = URL(string: "https://junkpile.app/privacy") {

// To this (use YOUR actual URL):
if let privacyURL = URL(string: "https://[your-username].github.io/junkpile_unclutter_email/privacy.html") {


// Line 347 - Change this:
if let termsURL = URL(string: "https://junkpile.app/terms") {

// To this (use YOUR actual URL):
if let termsURL = URL(string: "https://[your-username].github.io/junkpile_unclutter_email/terms.html") {
```

**Test it:**
1. Build and run on a physical device
2. Go to Settings → Data & Privacy
3. Tap "Privacy Policy" → should open in Safari
4. Tap "Terms of Service" → should open in Safari

---

## Step 3: Fill App Store Connect (30 minutes)

**Go to:** https://appstoreconnect.apple.com

### 3A. App Information Tab

- **Privacy Policy URL:** `https://[your-url]/privacy.html`
- **Support URL:** `mailto:support@junkpile.app` (or create this email first)

### 3B. Privacy Tab (Nutrition Label)

**What data you collect:**
- ✅ Contact Info → Email Address (for account)
- ✅ Identifiers → User ID (for account)
- ✅ Usage Data → Product Interaction (XP, achievements)

**What data you DON'T collect:**
- ❌ Precise location
- ❌ Browsing history
- ❌ Email content (critical!)

**Tracking:** Select **NO**

### 3C. Create a Test Gmail Account

1. Create a new Gmail account: `junkpile.tester@gmail.com`
2. Sign up for 10-20 newsletters (New York Times, Amazon, BestBuy, etc.)
3. Add credentials to App Store Connect → App Review Information:
   ```
   Email: junkpile.tester@gmail.com
   Password: [your-test-password]

   Notes: Sign in and grant Gmail access when prompted.
   Swipe left to unsubscribe, right to keep.
   Test account has 20+ subscription emails.
   ```

---

## Then You're DONE! 🎉

After those 3 steps:

1. Upload your build via Xcode (Product → Archive → Distribute)
2. Fill out basic metadata (name, description, keywords)
3. Upload 2 screenshots (any 2 screens from the app)
4. Click "Submit for Review"

**Expected approval time:** 1-3 days

---

## Don't Have Time Right Now?

**Save these for later:**

1. **Update placeholders in legal docs** (before you get big):
   - `[Your server location]` → in privacy.html line ~140
   - `[Your State/Country]` → in terms.html line ~600
   - These aren't critical for initial submission

2. **Set up professional support email:**
   - You can use `mailto:yourpersonal@gmail.com` for now
   - Set up `support@junkpile.app` later when you get a domain

3. **Perfect screenshots:**
   - You can use basic simulator screenshots for v1.0
   - Improve them in a future update

---

## Questions?

- **"Where do I host?"** → GitHub Pages (free, easiest)
- **"What if I don't have a domain?"** → Use GitHub Pages URLs
- **"What email should I use?"** → Any email you check regularly
- **"How long until approval?"** → Usually 1-3 days

---

## Quick Reference: Your Files

Created and ready to host:
- ✅ `web/privacy.html`
- ✅ `web/terms.html`

Need updating:
- ⚠️ `ios/Junkpile/Junkpile/Views/Settings/SettingsView.swift` (lines 331, 347)

For detailed info:
- 📖 `LAUNCH_SUMMARY.md` - Complete launch guide
- 📖 `LAUNCH_CHECKLIST.md` - Detailed checklist
- 📖 `web/README.md` - Hosting instructions

---

**You've got this! 🚀**
