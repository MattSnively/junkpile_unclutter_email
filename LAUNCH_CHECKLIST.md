# Junkpile - App Store Launch Checklist

**Status as of:** February 13, 2026

---

## ✅ COMPLETED - V1.0 Must-Have Features (from PRODUCT_ROADMAP.md)

- [x] **Swipe undo** - Implemented (UndoButton.swift)
- [x] **Scroll vs. swipe conflict resolution** - Fixed in gesture work
- [x] **VoiceOver accessibility pass** - Complete
- [x] **Session complete view with forward navigation** - Implemented
- [x] **Achievement unlock display** - Working
- [x] **Dark mode support** - Full Theme system implemented
- [x] **Cold launch optimization** - Skeleton loading added
- [x] **Apple Sign-In** - Dual-provider auth complete (Apple + Google)

---

## ⚠️ IN PROGRESS / NEEDS VERIFICATION

### 1. Meaningful Error States
**Status:** Unknown - needs code review

**What to check:**
- Look at `APIService.swift` for error handling
- Verify backend returns typed error codes (not generic 500s)
- Check if client shows contextual error messages

**Required error states (from roadmap):**
- OAuth expired → "Reconnect Gmail" button
- Network timeout → "Try Again" with offline explanation
- Unsubscribe failed → "Try Again" / "Skip" options
- Rate limited → Auto-retry with countdown
- Empty inbox → Navigate to stats/achievements
- Server error → "Try Again" with exponential backoff

**Action needed:** Review error handling code and test failure scenarios

---

## 🚨 CRITICAL BLOCKERS - Must Fix Before Submission

### 2. Privacy Policy & Terms of Service - HOSTING REQUIRED

**Status:** ✅ Documents created, ❌ Not yet hosted

**Files created:**
- `PRIVACY_POLICY.md` - Markdown version
- `TERMS_OF_SERVICE.md` - Markdown version
- `web/privacy.html` - Web-ready HTML
- `web/terms.html` - Web-ready HTML

**What you need to do:**

1. **Host the documents publicly:**
   - **Option A (Recommended):** GitHub Pages
     - Enable GitHub Pages in repo settings
     - Set source to `main` branch, `/web` folder
     - URLs will be: `https://[username].github.io/[repo]/privacy.html`

   - **Option B:** Custom domain (if you own junkpile.app)
     - Upload HTML files to your web host
     - URLs: `https://junkpile.app/privacy.html` and `/terms.html`

   - **Option C:** Free hosting (Netlify/Vercel)
     - Drag-drop the `/web` folder
     - Get instant URLs

2. **Update iOS app with real URLs:**
   - Edit `SettingsView.swift` lines 331 and 347
   - Replace placeholder URLs with your actual hosted URLs
   - Test the links work in the app

3. **Fill in placeholder information** in the documents:
   - `[Your server location]` → e.g., "United States" or "AWS US-East-1"
   - `[Your State/Country]` → e.g., "California, USA"
   - `[Your Jurisdiction]` → e.g., "the State of California"
   - `[Your website URL]` → Your actual website or GitHub Pages URL
   - `[Your mailing address]` → Required in some jurisdictions (CA, EU)

4. **Set up support email:**
   - Create `support@junkpile.app` (or use a Gmail/personal email)
   - Monitor it or set up auto-responses

5. **Add to App Store Connect:**
   - Log in to App Store Connect
   - App Information → Privacy Policy URL → Add your URL
   - App Information → Support URL → Add your URL or support email

---

## 📋 APP STORE CONNECT CHECKLIST

### Required Before Submission

- [ ] **Developer account verified** (Apple Developer Program - $99/year)
- [ ] **Tax and banking info complete** (in App Store Connect)
- [ ] **Agreements signed** (Paid Applications agreement)
- [ ] **App ID registered** with correct bundle identifier

### App Metadata

- [ ] **App icon** 1024x1024 PNG (no alpha channel)
- [ ] **Screenshots** for required device sizes:
  - iPhone 6.7" (iPhone 15 Pro Max, 14 Pro Max)
  - iPhone 6.5" (iPhone 11 Pro Max, XS Max)
  - Or use "Use screenshots for all sizes" option
- [ ] **App Store description** (under 4000 characters)
- [ ] **Keywords** (100 character limit, comma-separated)
- [ ] **App category** (Utilities or Productivity recommended)
- [ ] **Age rating** (Complete questionnaire)

### Privacy & Legal (CRITICAL)

- [ ] **Privacy Policy URL** - Add your hosted URL
- [ ] **Support URL** - Add support email or website
- [ ] **Privacy Nutrition Label** - Complete data collection questionnaire in App Store Connect
  - What data you collect (email address, user ID, gamification stats)
  - Whether data is linked to user identity (YES)
  - Whether data is used for tracking (NO)

### Build Upload

- [ ] **Version number** (e.g., 1.0.0)
- [ ] **Build number** (e.g., 1)
- [ ] **Upload via Xcode or Transporter**
- [ ] **TestFlight testing** (optional but recommended)

---

## 🧪 PRE-SUBMISSION TESTING

### Functional Testing

- [ ] Test on **physical devices** (not just simulator)
  - iPhone SE (smallest screen)
  - iPhone 15 Pro (current gen)
  - Test both dark and light mode

- [ ] **Apple Sign-In flow:**
  - First-time sign-in (Apple sends name/email)
  - Subsequent sign-in (Apple sends nil for name/email)
  - "Hide My Email" relay address
  - Revoke credentials from Settings → test error handling

- [ ] **Google Sign-In flow:**
  - First-time OAuth
  - Token refresh
  - Revoke access from Google settings → test reconnect

- [ ] **Gmail connection:**
  - Test with no subscriptions
  - Test with 100+ subscriptions
  - Test with slow network
  - Test offline → verify error messages

- [ ] **Unsubscribe flow:**
  - Swipe left → verify undo appears
  - Test undo within 5 seconds
  - Let timer expire → verify unsubscribe happens
  - Test with emails that have no List-Unsubscribe header

- [ ] **Gamification:**
  - Earn XP → verify level up works
  - Unlock achievements → verify celebration animation
  - Break streak → verify reset
  - Maintain streak → verify counter updates

- [ ] **VoiceOver accessibility:**
  - Enable VoiceOver (Settings → Accessibility → VoiceOver)
  - Navigate through all screens
  - Verify swipe actions are accessible via rotor
  - Verify all buttons have accessibility labels

### Performance Testing

- [ ] **Cold launch time** < 2 seconds (on iPhone 13 or newer)
- [ ] **Crash-free sessions** > 99% (use TestFlight to measure)
- [ ] **App size** optimized (under 200MB for cellular downloads)

### Edge Cases

- [ ] **No internet connection** → verify error messages
- [ ] **Server down** → verify fallback messages
- [ ] **Token expired** → verify re-auth prompt
- [ ] **Empty inbox** → verify empty state UI
- [ ] **First-time user** → test full onboarding flow

---

## 📝 APP REVIEW PREPARATION

### Demo Account (if login required)

- [ ] Create a **test Gmail account** for reviewers
- [ ] Pre-populate with subscription emails (sign up for newsletters)
- [ ] Add credentials to App Store Connect → App Review Information

### App Review Notes

Provide clear instructions for reviewers:

```
TEST ACCOUNT CREDENTIALS:
Email: reviewer@example.com
Password: [password]

TESTING INSTRUCTIONS:
1. Sign in with the provided test account
2. Grant Gmail access when prompted (OAuth flow)
3. Swipe left to unsubscribe, right to keep
4. Swipe left and immediately tap "Undo" to test undo feature
5. View Stats tab to see gamification progress
6. Settings → Data & Privacy → Privacy Policy/Terms links

NOTES:
- App requires Gmail account with subscription emails
- Test account has 20+ pre-loaded subscription emails
- Unsubscribe may fail for some senders (not all honor requests)
- App does NOT read email content, only metadata
```

### Common Rejection Reasons (and how to avoid them)

1. **Missing Privacy Policy** → ✅ You're creating this now
2. **Privacy violations** → ✅ You clearly state no email content is read
3. **Sign in with Apple required** → ✅ You have Apple Sign-In
4. **Broken links** → Test all URLs before submission
5. **Crashes** → Test thoroughly on physical devices
6. **Missing accessibility** → ✅ VoiceOver support implemented

---

## 🚀 SUBMISSION DAY CHECKLIST

### Final Steps Before "Submit for Review"

1. [ ] **All blockers resolved** (Privacy Policy hosted, URLs updated)
2. [ ] **Test build uploaded** to App Store Connect
3. [ ] **Metadata complete** (description, keywords, screenshots)
4. [ ] **Privacy Nutrition Label filled out**
5. [ ] **Test account credentials** added to App Review Notes
6. [ ] **Links tested** (Privacy, Terms, Support email)
7. [ ] **Version/build numbers** correct
8. [ ] **Age rating** appropriate (likely 4+, check questionnaire)

### Click "Submit for Review"

**Expected timeline:**
- **In Review:** 24-48 hours (can be faster)
- **Approval/Rejection:** Usually within 24 hours of review starting
- **Total:** 1-3 days on average

**If rejected:**
- Read rejection reason carefully
- Fix the specific issue mentioned
- Respond via Resolution Center if you need clarification
- Re-submit (usually faster the second time)

---

## 📊 POST-LAUNCH MONITORING

### Week 1 After Launch

- [ ] Monitor **crash rate** (App Store Connect → Analytics)
- [ ] Check **App Store rating** (aim for 4.0+ per roadmap)
- [ ] Review **user feedback** (App Store reviews)
- [ ] Monitor **support email** for bug reports
- [ ] Track **downloads and installs**

### If Crash Rate > 1%

- [ ] Enable crash reporting (Sentry recommended in roadmap)
- [ ] Identify top crashes
- [ ] Release hotfix update ASAP

---

## 🎯 NEXT STEPS AFTER LAUNCH

From PRODUCT_ROADMAP.md Phase 1 (V1.1):

1. **Analytics instrumentation** (TelemetryDeck recommended)
2. **Crash reporting** (Sentry, not Firebase per roadmap)
3. **Push notification activation** (infrastructure ready, just enable)
4. **Onboarding rewrite** (show subscription count immediately)
5. **Error state improvements** (contextual messages)

---

## 📞 SUPPORT & RESOURCES

**If App Review rejects:**
- Read Apple's App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Check Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/

**Legal questions:**
- **Not a lawyer!** These documents are templates
- Consult a lawyer if handling EU users (GDPR) or CA users (CCPA)
- Consider Iubenda or Termly for auto-generated policies (paid services)

**Technical issues:**
- GitHub Issues: (your repo)
- Apple Developer Forums: https://developer.apple.com/forums/

---

## ✅ READY TO LAUNCH?

**Current status:**

✅ **Technical implementation:** READY (8/10 must-haves complete)
⚠️ **Error handling:** NEEDS REVIEW (verify contextual error messages exist)
🚨 **Legal documents:** NEED HOSTING (created but not yet publicly accessible)
⚠️ **App Store Connect:** UNKNOWN (need to verify setup complete)

**Time to launch:** 1-3 days after hosting legal documents and verifying error handling

**Estimated approval time:** 1-3 days after submission

---

**Good luck with your launch! 🚀**

*For questions or updates, see PRODUCT_ROADMAP.md and iOS_submission_checklist.txt*
