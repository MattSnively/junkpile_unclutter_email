# Junkpile iOS App — Senior UX Code Review & Backlog

**Reviewer:** Senior Dev (Code Review)
**Date:** 2026-02-05
**Verdict:** Solid architecture, but the app doesn't *feel* right yet. The bones are good — MVVM is clean, SwiftData usage is modern, gamification system is well-designed. But the UX has real problems that will hurt retention. The swipe core is fragile, accessibility is nonexistent, and gamification competes with the actual value proposition instead of supporting it.

---

## P0 — Ship Blockers (Fix Before Any Launch)

### UX-001: Swipe Undo Missing — Users Will Rage-Quit
**Files:** `EmailCardStack.swift:161`, `SwipeContainerView.swift`
**Severity:** P0 — Core feature gap
**Problem:** After swiping, `currentIndex` increments immediately with zero undo path. One accidental left-swipe unsubscribes from a newsletter the user actually reads. There is no confirmation, no toast, no recovery. The user's only recourse is to go re-subscribe manually.
**Fix:** Add a 3-second undo toast after every swipe. Cache the last decision. On undo, decrement `currentIndex`, delete the `Decision`, and re-insert the email card with a reverse animation. This is table stakes for any swipe-based app — Tinder has it, Gmail has it, every mail app has it.

### UX-002: Accidental Swipes on Scroll
**Files:** `EmailCardStack.swift:105-114`
**Severity:** P0 — Core interaction broken
**Problem:** `DragGesture` captures ANY horizontal movement on the card. When a user scrolls vertically to read a long email preview, even slight horizontal finger drift triggers a swipe. This means: reading an email = accidentally unsubscribing from it.
**Fix:** Add directional intent detection. Only register a horizontal swipe if `abs(translation.width) > abs(translation.height) * 1.5`. This filters out vertical scroll attempts. Also consider using `simultaneousGesture` with a scroll view inside the card.

### UX-003: Accessibility Is Nonexistent
**Files:** All views
**Severity:** P0 — Legal/compliance risk, 15%+ users excluded
**Problem:** Zero `accessibilityLabel` annotations across the entire app. No `accessibilityHint` on any interactive element. No Dynamic Type support (hardcoded font sizes). No `accessibilityElement` grouping. VoiceOver users hear "Button Button Button" with no context. Achievement badges, streak circles, progress bars — all invisible to assistive tech.
**Fix:** Full accessibility audit. Every interactive element needs a label. Every informational display needs a value. Every complex component needs `accessibilityElement(children: .combine)`. Test with VoiceOver enabled on a real device. This is not optional — it's an App Store review risk and an ADA consideration.

### UX-004: Auth State Not Persisted Across App Restarts
**Files:** `JunkpileApp.swift:12`, `AuthViewModel.swift`
**Severity:** P0 — Session loss
**Problem:** `AuthViewModel()` is created fresh on every app launch. Even though `KeychainService` stores tokens, the auth state check on launch may not complete before the UI renders, flashing the onboarding screen before snapping to the main view. Users see this as "I got logged out."
**Fix:** Initialize `isAuthenticated` from `KeychainService.hasStoredCredentials()` synchronously on init, then validate the token asynchronously in the background. Show a brief splash/loading state instead of flashing onboarding.

### UX-005: Gmail Connection Status is a Lie
**Files:** `SettingsView.swift:108`
**Severity:** P0 — Trust violation
**Problem:** "Connected" is hardcoded. If the OAuth token expired, was revoked, or the user changed their Google password, the app still shows green "Connected." The user tries to start a session, gets a cryptic error, and has no idea the root cause is auth expiry.
**Fix:** Actually validate the token on `SettingsView.onAppear`. Show "Connected" / "Expired — Reconnect" / "Checking..." with appropriate colors and actions.

---

## P1 — High Impact UX Issues (Fix Before Public Beta)

### UX-006: Swipe Threshold Too High, Velocity Ignored
**Files:** `EmailCardStack.swift:120-136, 178-185`, `EmailCardView.swift:29`
**Severity:** P1 — Core interaction feels sluggish
**Problem:** 100px drag threshold (~2cm on iPhone 12) is too high. Users with motor impairments or those swiping quickly find it unresponsive. Worse: velocity is *calculated* in the code but *never used* in swipe detection. A fast flick that only travels 60px doesn't register.
**Fix:** Lower threshold to 60px. Add velocity gate: if `velocity.width > 500`, complete the swipe regardless of distance. This makes the swipe feel snappy and responsive.

### UX-007: Onboarding Sells Gamification Before Value
**Files:** `OnboardingView.swift:38`
**Severity:** P1 — First impression failure
**Problem:** Page 3 of onboarding explains XP, achievements, and streaks before the user has ever swiped a single email. At this point, gamification is meaningless noise. The user came to clean their inbox, not to earn badges. Leading with gamification signals "gimmick" instead of "tool."
**Fix:** Cut onboarding to 2 screens max: (1) "Your inbox is cluttered" [pain point], (2) "Swipe to fix it" [solution]. Drop the gamification page entirely. Introduce XP and achievements organically after the user's first completed session — when the dopamine hit is real.

### UX-008: Swipe Hints Never Disappear
**Files:** `SwipeContainerView.swift:227-248`
**Severity:** P1 — Visual noise
**Problem:** "← Unsubscribe" and "Keep →" labels appear on EVERY card, even after the user has swiped 200 emails. After the first 2-3 swipes, these labels are clutter that competes with the actual email content.
**Fix:** Show hints only on the first 3 cards of the user's first session ever. Store a `hasSeenSwipeHints` flag in `AppStorage`. After that, the cards should be clean.

### UX-009: Session Complete View is a Dead End
**Files:** `SwipeContainerView.swift:306-318`
**Severity:** P1 — Broken flow
**Problem:** After completing a session, the only option is "New Session." No "Back to Home," no "View Stats," no "See Achievements." The user is trapped in a loop. If they're done for the day, they have to know to use the tab bar — which is a navigation failure.
**Fix:** Add 3 clear CTAs: "New Session" (primary), "View Stats" (secondary), "Done" (tertiary, returns to Home). Also show a brief summary: "You're on a 3-day streak! Come back tomorrow to keep it going."

### UX-010: Error Messages Are Useless
**Files:** `SwipeContainerView.swift:384`, `GoogleSignInView.swift:43-49`
**Severity:** P1 — User abandonment
**Problem:** Error states show raw backend messages like "Failed to fetch emails" with a bare retry button. The user doesn't know if the problem is their internet, their Gmail permissions, an expired token, or a server outage. No actionable guidance.
**Fix:** Parse `APIError` cases into human-friendly messages with specific recovery actions:
- Network error → "No internet connection. Check your Wi-Fi and try again."
- Auth error → "Gmail disconnected. Tap to reconnect." [links to re-auth flow]
- Server error → "Our servers are having trouble. Try again in a few minutes."
- Empty inbox → "No emails to process right now. Check back later!" [not an error]

### UX-011: No Haptic Variation — Everything Feels the Same
**Files:** `EmailCardStack.swift:154-156`, all views
**Severity:** P1 — Lack of tactile polish
**Problem:** Every swipe uses `.medium` impact haptic. Keep and Unsubscribe feel identical. Home buttons have no haptics at all. The app feels flat and unresponsive.
**Fix:** Differentiate: `.light` for Keep (gentle confirmation), `.medium` for Unsubscribe (assertive action), `.success` notification haptic for achievement unlock, `.warning` for threshold crossing during drag. Add `.light` impact on all button taps throughout the app.

### UX-012: Card Height Fixed at 450px — Breaks on Small Screens
**Files:** `EmailCardView.swift:60`
**Severity:** P1 — Device compatibility
**Problem:** `.frame(height: 450)` is hardcoded. On iPhone SE (667pt screen height), the card takes 67% of the viewport. The stacked cards behind are invisible, the progress bar is cramped, and the swipe hints overlap the card.
**Fix:** Use proportional sizing: `.frame(height: min(450, UIScreen.main.bounds.height * 0.55))`. Test on SE, Mini, and Pro Max.

### UX-013: Achievement Unlock Auto-Dismisses in 3 Seconds
**Files:** `AchievementsGalleryView.swift:295-304`, `HomeView.swift:301-303`
**Severity:** P1 — Gamification undermined
**Problem:** The one moment where gamification should shine — unlocking an achievement — auto-dismisses after 3 seconds via `DispatchQueue.main.asyncAfter`. If the user is mid-read, it vanishes. If they're not looking at the screen, they miss it entirely. Uses `DispatchQueue` instead of `Task` so it can't be cancelled if the user navigates away.
**Fix:** Remove auto-dismiss. Add explicit "Awesome!" dismiss button. Use `.task { try await Task.sleep(for: .seconds(5)); dismiss() }` with proper cancellation. Add a notification badge on the Achievements tab so users can find achievements they missed.

---

## P2 — Medium Impact Polish (Fix Before V1.0)

### UX-014: Tab State Resets on App Background
**Files:** `JunkpileApp.swift:68`
**Severity:** P2
**Problem:** `@State private var selectedTab` resets when the app is backgrounded. User mid-session on Swipe tab, gets a text, returns — they're on Home now.
**Fix:** `@AppStorage("selectedTab") private var selectedTab = "home"`.

### UX-015: 3D Rotation Too Aggressive During Swipe
**Files:** `EmailCardView.swift:61-64`
**Severity:** P2
**Problem:** `rotation3DEffect(.degrees(Double(offset.width) / 20))` = 5° rotation at threshold. After 50+ swipes this causes subtle motion sickness. Users won't attribute the nausea to the app — they'll just stop using it.
**Fix:** Reduce to `/ 40` (2.5° at threshold). Add `@Environment(\.accessibilityReduceMotion)` check to disable rotation entirely for users with Reduce Motion enabled.

### UX-016: Weekly Activity Grid Shows False Data
**Files:** `StreakView.swift:203-213`
**Severity:** P2
**Problem:** `dayCircle()` assumes if `daysAgo < currentStreak` then that day was active. This is mathematically wrong. If user was active Mon, Tue, skipped Wed, active Thu — streak is 1 but Mon/Tue show as active. The grid is lying.
**Fix:** Query `DailyActivity` records for each of the last 7 days. Show actual activity data, not streak-based assumptions.

### UX-017: Locked Achievements Provide No Progression Hints
**Files:** `AchievementsGalleryView.swift:198-203`
**Severity:** P2
**Problem:** Locked achievement detail shows description but no progress toward unlocking. User sees "Unsubscribe from 100 emails" but doesn't know they're at 87/100. The gamification system has all the data but doesn't surface it.
**Fix:** Add progress bars to locked achievements: "87 / 100 emails unsubscribed" with a fill bar. This is the single biggest gamification motivator — showing users they're close.

### UX-018: Empty Home State is a Wasteland
**Files:** `HomeView.swift`
**Severity:** P2
**Problem:** Brand new user with zero stats, zero achievements, zero streak sees: empty streak card, empty progress bar at 0%, all zeroes in stats row. The home screen screams "nothing here." No call to action.
**Fix:** First-time Home should show a large, inviting "Start Your First Session" card with illustration. Hide stats/streak/achievements until user has at least 1 completed session.

### UX-019: Stats View Has No Trending or Comparison
**Files:** `StatsView.swift`
**Severity:** P2
**Problem:** Shows "This Week" stats with no comparison to last week. User can't tell if they're improving. Static numbers don't motivate continued engagement.
**Fix:** Add week-over-week change indicators: "↑ 23% more unsubscribes than last week" or "📉 Activity down — start a session!" This is cheap to implement (just compare two date ranges) and high-impact for retention.

### UX-020: No Delete Account / Data Management
**Files:** `SettingsView.swift`
**Severity:** P2 — App Store requirement
**Problem:** No "Delete Account" option. Apple requires apps that create accounts to provide account deletion. This is an App Store rejection risk.
**Fix:** Add "Delete Account" in Settings > Data & Privacy section with confirmation dialog and API call to backend.

### UX-021: Double Swipe Race Condition
**Files:** `EmailCardStack.swift:159-164`
**Severity:** P2
**Problem:** During the 0.3s swipe-off animation, gesture recognizer is still active. Rapid swipes can fire two decisions on the same card, or skip a card entirely.
**Fix:** Add `@State private var isAnimating = false` flag. Disable gesture during animation. Re-enable on `withAnimation` completion.

### UX-022: Force-Unwrapped URLs Will Crash
**Files:** `GoogleSignInView.swift:162`, `SettingsView.swift:162`
**Severity:** P2
**Problem:** `URL(string: "...")!` force-unwraps URLs. If the string is malformed or the domain changes, the app crashes.
**Fix:** `guard let url = URL(string: "...") else { return }` everywhere.

---

## P3 — Nice to Have (V1.1+)

### UX-023: No Skeleton Loading States
Loading uses generic spinners instead of skeleton screens that match the layout. Makes perceived load time feel longer.

### UX-024: Google Sign-In Button Not Branded
Uses generic `g.circle.fill` SF Symbol instead of official Google logo. Looks unprofessional and may violate Google brand guidelines.

### UX-025: Notification Permission Not Checked Before Toggle
Streak notification toggle doesn't verify iOS notification permission. User enables toggle but notifications silently fail.

### UX-026: No Deep Linking Support
App can't be launched from notifications, emails, or URLs to specific views. Required for push notification flows.

### UX-027: Dark Mode Not Tested
Color scheme uses `.primary` which adapts, but custom colors (gray.opacity, hardcoded .black/.white) likely break in dark mode.

### UX-028: No Offline Mode
App requires network for all features. No cached email viewing or offline stats display.

### UX-029: Session History Not Deletable
Users cannot remove old sessions from stats view. Privacy concern for shared devices.

### UX-030: Streak Flame Icon is Static
The streak view's large flame icon has no animation. A subtle pulse or flicker would reinforce the "fire" metaphor.

### UX-031: Number Formatting Not Localized
XP, points, and stats display raw integers without locale-aware formatting (e.g., "1,250" vs "1.250" in German).

### UX-032: iPad Layout Not Optimized
2-column grids and fixed card heights don't adapt to iPad screen sizes. Wastes significant screen real estate.

---

## Architecture Notes for the Backlog

**What's Actually Good:**
- MVVM is clean — view models don't leak SwiftUI concerns
- SwiftData usage is modern and appropriate for the data complexity
- Keychain storage for auth tokens is correct
- Achievement system design is well-thought-out (categories, bonuses, milestones)
- Zero external dependencies — pure Apple frameworks

**What Needs Rethinking:**
- Gamification is the app's identity crisis. It should be the *seasoning*, not the *meal*. The core value is "clean your inbox fast." Everything else supports that.
- The swipe interaction is the entire product — it needs to be bulletproof, not "good enough"
- Error handling is uniformly poor across the entire service layer
- Accessibility wasn't an afterthought — it was never a thought

---

*This review represents the state of the codebase as of 2026-02-05. Items should be re-validated as fixes are applied.*
