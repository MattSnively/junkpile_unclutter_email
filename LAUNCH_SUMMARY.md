# 🚀 Junkpile Launch Summary

**Date:** February 13, 2026
**Status:** Ready for final pre-launch steps

---

## ✅ What's DONE

### V1.0 Must-Have Features (from Product Roadmap)

| Feature | Status | Evidence |
|---------|--------|----------|
| Swipe undo with 5-second timer | ✅ Complete | `UndoButton.swift`, `pendingDecision` in SwipeViewModel |
| Scroll vs. swipe conflict resolution | ✅ Complete | Gesture work in commit d5a0bca |
| Meaningful error states | ✅ Complete | `UserFacingError` struct with 6 error types, contextual messages |
| Session complete view | ✅ Complete | `SwipeContainerView.swift` with forward navigation |
| Achievement unlock display | ✅ Complete | Gamification system implemented |
| Onboarding flow | ✅ Complete | Apple + Google sign-in flows |
| VoiceOver accessibility | ✅ Complete | Full accessibility labels and rotor actions |
| Crash rate monitoring | ✅ Infrastructure ready | Error handling in place, ready for Sentry |
| Cold launch optimization | ✅ Complete | Skeleton loading views |
| Privacy Policy & Terms | ✅ Documents created | Markdown + HTML versions ready to host |

### Bonus Features (beyond V1.0 requirements)

- ✅ **Dark mode support** - Full adaptive theme system (`Theme.swift`)
- ✅ **Sign in with Apple** - Dual-provider auth (Apple + Google)
- ✅ **Apple credential revocation handling** - Checks credential state
- ✅ **Session tokens for Apple users** - 7-day JWT tokens
- ✅ **Gmail connection status checker** - Real-time validation
- ✅ **Account deletion flow** - Full GDPR-compliant data deletion

---

## 🚨 CRITICAL: What You Need to Do BEFORE Launch

### 1. Host Legal Documents (REQUIRED)

**What:** The Privacy Policy and Terms of Service need to be publicly accessible.

**Files already created:**
- ✅ `PRIVACY_POLICY.md` (Markdown version)
- ✅ `TERMS_OF_SERVICE.md` (Markdown version)
- ✅ `web/privacy.html` (Web-ready)
- ✅ `web/terms.html` (Web-ready)

**Action required:**

**Option A: GitHub Pages (Recommended - FREE)**
```bash
# 1. Enable GitHub Pages
# Go to: Repo Settings → Pages
# Source: main branch, /web folder
# Save

# 2. Your URLs will be:
# https://[your-username].github.io/junkpile_unclutter_email/privacy.html
# https://[your-username].github.io/junkpile_unclutter_email/terms.html

# 3. Wait 2-3 minutes for deployment
# 4. Test the URLs in a browser
```

**Option B: Custom domain (if you own junkpile.app)**
```bash
# 1. Upload web/privacy.html and web/terms.html to your web host
# 2. URLs: https://junkpile.app/privacy.html and /terms.html
# 3. Test in browser
```

**Option C: Netlify/Vercel (FREE)**
```bash
# 1. Sign up at netlify.com or vercel.com
# 2. Drag-drop the /web folder
# 3. Get instant URLs
```

### 2. Update iOS App with Real URLs

**File:** `ios/Junkpile/Junkpile/Views/Settings/SettingsView.swift`

**Lines to update:**
```swift
// Line 331 - Update with your actual URL
if let privacyURL = URL(string: "https://YOUR-ACTUAL-URL/privacy.html") {

// Line 347 - Update with your actual URL
if let termsURL = URL(string: "https://YOUR-ACTUAL-URL/terms.html") {
```

**After updating:**
1. Build and run the app on a physical device
2. Go to Settings → Data & Privacy
3. Tap "Privacy Policy" and "Terms of Service"
4. Verify both links open correctly in Safari

### 3. Fill in Document Placeholders

**In both `PRIVACY_POLICY.md` and `web/privacy.html`:**
- Replace `[Your server location]` with your actual server location (e.g., "United States" or "AWS US-East-1")
- Replace `[Your website URL]` with your actual website or GitHub Pages URL
- Replace `[Your mailing address]` with your mailing address (required in some jurisdictions like CA/EU)

**In both `TERMS_OF_SERVICE.md` and `web/terms.html`:**
- Replace `[Your State/Country]` with governing law jurisdiction (e.g., "California, USA")
- Replace `[Your Jurisdiction]` with court jurisdiction (e.g., "the State of California")
- Replace `[Your website URL]` with your actual website
- Replace `[Your mailing address]` with your mailing address (if required)

### 4. Set Up Support Email

**Email used in documents:** `support@junkpile.app`

**Options:**
1. **Create a professional email:** Register the domain and set up `support@junkpile.app`
2. **Use Gmail/personal:** Update all references to your actual email (e.g., `yourname@gmail.com`)
3. **Set up forwarding:** Forward `support@junkpile.app` → your personal email

**Where it's referenced:**
- Privacy Policy
- Terms of Service
- SettingsView.swift (line 457 - "Send Feedback" link)
- App Store Connect (Support URL field)

### 5. App Store Connect Setup

**Go to:** https://appstoreconnect.apple.com

**Required information:**

1. **App Information tab:**
   - Privacy Policy URL: `https://[your-url]/privacy.html`
   - Support URL: `https://[your-url]/terms.html` OR `mailto:support@junkpile.app`
   - Marketing URL (optional): Your website

2. **Privacy tab (Privacy Nutrition Label):**
   - **Data collected:**
     - Contact Info → Email Address (linked to user, used for app functionality)
     - Identifiers → User ID (linked to user, used for app functionality)
     - Usage Data → Product Interaction (linked to user, used for analytics)
   - **Data NOT collected:**
     - ❌ Email content
     - ❌ Browsing history
     - ❌ Search history
     - ❌ Location
     - ❌ Contacts
   - **Tracking:** NO (do not track users across apps/websites)

3. **App Review Information:**
   - **First Name:** Your first name
   - **Last Name:** Your last name
   - **Phone Number:** Your phone number
   - **Email:** Your support email
   - **Demo Account Credentials:**
     ```
     Email: [create a test Gmail account with subscriptions]
     Password: [password]

     Notes: Test account has 20+ subscription emails pre-loaded.
     Sign in, grant Gmail access, and swipe to test unsubscribe flow.
     ```

4. **Age Rating:**
   - Complete the questionnaire (likely 4+)
   - No violence, no profanity, no mature content

---

## 📝 Pre-Submission Testing Checklist

### Functional Tests

Run through these on a physical device:

- [ ] **Fresh install:**
  - Delete app from device
  - Install from Xcode
  - Complete onboarding from scratch

- [ ] **Apple Sign-In flow:**
  - Sign in with Apple (first time)
  - Revoke credentials from iOS Settings → Apple ID → Sign in with Apple → Junkpile → Stop Using Apple ID
  - Reopen app → verify error handling
  - Sign in again → verify works with nil name/email

- [ ] **Google Sign-In flow:**
  - Sign in with Google
  - Revoke from https://myaccount.google.com/permissions
  - Reopen app → verify reconnect prompt

- [ ] **Gmail connection:**
  - Load emails → verify cards display
  - Test with no subscriptions → verify empty state
  - Toggle airplane mode → verify network error message

- [ ] **Swipe and undo:**
  - Swipe left → verify undo button appears
  - Tap undo immediately → verify email returns
  - Swipe left again → wait 5 seconds → verify undo expires
  - Check countdown ring animation is smooth

- [ ] **Gamification:**
  - Make decisions → verify XP increments
  - Unlock achievement → verify celebration animation
  - Break streak → come back next day → verify reset
  - Settings → verify profile shows correct stats

- [ ] **VoiceOver:**
  - Enable VoiceOver (Settings → Accessibility → VoiceOver)
  - Navigate all screens
  - Verify swipe actions in rotor menu
  - Turn off VoiceOver

- [ ] **Legal links:**
  - Settings → Privacy Policy → verify opens in Safari
  - Settings → Terms of Service → verify opens in Safari

### Edge Cases

- [ ] **No internet during onboarding** → verify error message
- [ ] **Token expires mid-session** → verify re-auth prompt
- [ ] **Delete account** → verify clears all data and returns to sign-in
- [ ] **First-time user** → complete full onboarding, process 10 emails

---

## 🎯 Submission Steps

### 1. Upload Build

```bash
# In Xcode:
# 1. Select "Any iOS Device (arm64)" target
# 2. Product → Archive
# 3. Wait for archive to complete
# 4. Distribute App → App Store Connect → Upload
# 5. Wait for processing (10-30 minutes)
```

### 2. Create App Store Version

1. Go to App Store Connect → My Apps → Junkpile
2. Click ➕ next to "iOS App" in sidebar
3. Version Number: `1.0.0`
4. Select your uploaded build

### 3. Fill Out Metadata

- **App Name:** Junkpile
- **Subtitle:** (Optional, 30 chars) "Email cleanup, gamified"
- **Description:** (See below for suggested copy)
- **Keywords:** `email,unsubscribe,inbox,cleanup,productivity,gamification`
- **Support URL:** Your hosted URL or support email
- **Marketing URL:** (Optional) Your website

**Suggested App Description:**
```
Junkpile is the game you play for five minutes a day that permanently fixes your email.

Swipe right to keep. Swipe left to unsubscribe. It's that simple.

No more drowning in newsletters you forgot you signed up for. No more clicking "unsubscribe" at the bottom of every email. Junkpile makes email cleanup fast, fun, and actually kind of addicting.

FEATURES:
• Swipe interface - Like Tinder, but for email cleanup
• Gamification - Earn XP, unlock achievements, maintain streaks
• Privacy-first - We NEVER read your email content, only metadata
• Undo - Changed your mind? Undo within 5 seconds
• Dark mode - Easy on your eyes, day or night

HOW IT WORKS:
1. Connect your Gmail account
2. Swipe through subscription emails
3. We send unsubscribe requests on your behalf
4. Your inbox gets cleaner every day

PRIVACY:
• We only access email sender names, subjects, and unsubscribe links
• We NEVER read the content of your emails
• We NEVER sell your data to anyone
• All authentication is done via secure OAuth

Whether you have 10 subscriptions or 1,000, Junkpile makes inbox zero achievable. Download now and reclaim your inbox.
```

### 4. Upload Screenshots

**Required sizes:**
- iPhone 6.7" (1290 x 2796) - iPhone 15 Pro Max
- iPhone 6.5" (1242 x 2688) - iPhone 11 Pro Max

**Suggested screenshots:**
1. Swipe interface showing an email card
2. Achievement unlock celebration
3. Stats view showing progress
4. Profile view with level/XP
5. Empty inbox success state

**Tools to create screenshots:**
- Use Xcode's simulator
- Take screenshots at required sizes
- Add text overlays in Preview or Figma (optional)

### 5. Submit for Review

1. Review all information
2. Click "Add for Review" at top right
3. Click "Submit for Review"
4. Wait for "Waiting for Review" status

**Expected timeline:**
- Waiting for Review: 0-48 hours
- In Review: 1-24 hours
- Decision: Approved or Rejected

---

## 📊 After Submission

### If APPROVED ✅

1. **Celebrate!** 🎉
2. App will be available within 24 hours
3. Monitor:
   - Downloads (App Store Connect → Analytics)
   - Crashes (Xcode → Organizer → Crashes)
   - Ratings (App Store Connect → Ratings & Reviews)
   - Support email for bug reports

### If REJECTED ❌

**Common reasons:**
1. **Privacy Policy not accessible** → Verify URL works
2. **Demo account doesn't work** → Test credentials again
3. **Crashes during review** → Check crash logs in Organizer
4. **Misleading screenshots** → Ensure screenshots show actual app
5. **Sign in with Apple issues** → Verify Apple Sign-In is working

**How to respond:**
1. Read rejection message carefully
2. Fix the specific issue mentioned
3. Respond via Resolution Center if unclear
4. Re-submit (usually faster second time)

---

## 🎯 Immediate Next Steps (Phase 1, after launch)

From PRODUCT_ROADMAP.md:

1. **Enable crash reporting** (Sentry - $26/month or free tier)
2. **Add analytics** (TelemetryDeck - $99/year)
3. **Activate push notifications** (infrastructure is ready)
4. **Monitor crash rate** (must stay below 1% per roadmap)
5. **Gather user feedback** (App Store reviews, support email)

---

## 📞 Support Resources

**Apple Developer:**
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- Technical Support: https://developer.apple.com/contact/

**Legal:**
- **Not a lawyer disclaimer:** These documents are templates
- Consult a lawyer if handling EU (GDPR) or California (CCPA) users
- Consider Iubenda or Termly for auto-generated policies (paid)

**Community:**
- Apple Developer Forums: https://developer.apple.com/forums/
- Reddit r/iOSProgramming: https://reddit.com/r/iOSProgramming

---

## ✅ Final Pre-Launch Checklist

Complete these before clicking "Submit for Review":

- [ ] Legal documents hosted publicly and URLs tested
- [ ] iOS app updated with real URLs
- [ ] Support email set up and monitored
- [ ] App Store Connect metadata complete
- [ ] Privacy Nutrition Label filled out accurately
- [ ] Demo account created with test data
- [ ] Screenshots uploaded for all required sizes
- [ ] Build uploaded and processing complete
- [ ] All placeholders in legal docs filled in
- [ ] Physical device testing complete
- [ ] VoiceOver testing complete
- [ ] All links in app tested and working

---

## 🎉 You're Almost There!

**Current Status:**
- ✅ App is technically complete
- ✅ Legal documents created
- ⏳ Legal documents need hosting (~10 minutes)
- ⏳ iOS app needs URL updates (~5 minutes)
- ⏳ App Store Connect setup (~30 minutes)
- ⏳ Testing and screenshots (~1-2 hours)

**Estimated time to submission:** 2-3 hours of focused work

**Estimated time to approval:** 1-3 days after submission

---

**Questions? Check:**
- `LAUNCH_CHECKLIST.md` - Detailed step-by-step guide
- `PRODUCT_ROADMAP.md` - Full product vision and post-launch plans
- `iOS_submission_checklist.txt` - iOS-specific requirements
- `web/README.md` - Legal document hosting instructions

**Good luck! You've built something awesome. 🚀**
