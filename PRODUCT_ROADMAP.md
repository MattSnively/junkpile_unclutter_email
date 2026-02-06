# Junkpile: Product Roadmap

**Document Owner:** Product
**Last Updated:** 2026-02-05
**Status:** Draft for Review
**Audience:** Engineering, Design, Leadership

---

## 1. Product Vision & Strategy

### Product Vision

**Junkpile is the game you play for five minutes a day that permanently fixes your email.**

### Strategic Pillars

**1. Compulsive Simplicity**
Every interaction must feel faster and more satisfying than the last. The core loop (swipe left, swipe right) is sacred. If a feature adds friction to swiping, it does not ship. Inbox Zero is the destination; Junkpile is the dopamine-fueled vehicle.

**2. Earned Trust**
Unroll.me proved that users will abandon an email tool the instant they suspect data exploitation. Junkpile will never sell, analyze, or monetize user email data. Privacy is not a feature — it is the foundation. We will be loud about this in marketing and transparent in our architecture.

**3. Habitual Engagement**
The app succeeds when users open it daily by instinct, not obligation. Gamification is the retention engine, not the product. The streaks, XP, and achievements exist to make the boring act of email hygiene feel like progress. When the inbox is clean, the game shifts to maintenance mode — not silence.

### Anti-Goals (What Junkpile Is NOT)

- **Not an email client.** We will never display email bodies, support composing, or replace Mail/Gmail. We are a single-purpose unsubscribe tool.
- **Not a data company.** We will never sell user email metadata, build advertising profiles, or share data with third parties. Revenue comes from users, not data buyers.
- **Not a productivity suite.** No task management, no calendar integration, no "snooze this email," no read-later queues. Other apps do this. We do one thing.
- **Not a social network.** Competitive features (if built) will be lightweight and opt-in. No follower graphs, no public profiles, no feed. Leaderboards are the ceiling.
- **Not cross-platform.** Android is not on this roadmap. iOS-first, iOS-deep. We will consider Android only after proving product-market fit and securing funding that specifically targets it.

---

## 2. V1.0 Release Criteria

### Must-Have for App Store Launch

| # | Item | Rationale |
|---|------|-----------|
| 1 | **Swipe undo** (shake-to-undo + floating undo button with 5-second timer) | Without undo, a single accidental swipe unsubscribes users from email they want. This is a trust-destroying bug. Non-negotiable. |
| 2 | **Scroll vs. swipe conflict resolution** | If users accidentally unsubscribe while trying to read a card, they will churn on day one. Fix the gesture recognizer priority so vertical scroll never triggers horizontal swipe. |
| 3 | **Meaningful error states** | Replace every generic "Something went wrong" with contextual copy and a recovery action. Minimum: OAuth failure, network timeout, unsubscribe processing failure, rate limiting, empty inbox state. |
| 4 | **Session complete view with forward navigation** | The current dead-end kills session flow. After completing a batch, show stats and offer: "Load more," "View achievements," "Share progress," or "Done for today." |
| 5 | **Achievement unlock display fix** | Auto-dismiss after minimum 4 seconds, or hold until user taps. Add a confetti/haptic moment. Achievements are the reward — do not rush them. |
| 6 | **Onboarding rewrite** | Current flow leads with gamification. New flow: (1) "Your inbox has X subscriptions," (2) "Swipe left to unsubscribe, right to keep," (3) demo swipe on a fake card, (4) "You'll earn XP and level up as you go." Value first, game second. |
| 7 | **VoiceOver accessibility pass** | Every interactive element must have an accessibility label. Swipe actions must be available via the rotor. This is an App Store Review risk and a legal liability. |
| 8 | **Crash rate below 1%** | Measured across 1,000+ sessions in TestFlight. |
| 9 | **Cold launch under 2 seconds** | On iPhone 13 or newer. Users expect instant. |
| 10 | **Privacy Policy and Terms of Service** | Legally required for App Store submission. Must clearly state: no data selling, what we access, how long we retain. |

### Acceptable Known Issues at V1.0

- **Gmail only.** Outlook/Yahoo can wait. Gmail is ~60% of US consumer email. Ship where the users are.
- **No iPad layout optimization.** iPhone-only launch is fine. iPad users can run the iPhone app. Optimization comes in Phase 3.
- **No push notifications.** Infrastructure is ready, but the notification content strategy is not. Shipping bad notifications is worse than shipping none. Defer to V1.1.
- **No Apple Watch app.** Zero urgency. This is a "sit on the couch" app, not a glanceable utility.
- **No dark mode polish.** If it works (SwiftUI handles basics), ship it. Pixel-perfect dark mode tuning is Phase 1.
- **No widgets.** They are a retention tool, not a launch requirement.
- **Achievement gallery may feel sparse.** 21 achievements across 5 categories is enough to start. Users will not exhaust them in week one.
- **No analytics beyond basic Apple App Analytics.** We will instrument properly in Phase 1. For launch, Apple's built-in metrics plus TestFlight feedback are sufficient.

### Quality Bar

| Metric | V1.0 Minimum | V1.1 Target |
|--------|-------------|-------------|
| Crash-free sessions | 99% | 99.5% |
| Cold launch time | < 2.0s | < 1.5s |
| Swipe response latency | < 100ms | < 50ms |
| Unsubscribe success rate | > 85% | > 90% |
| VoiceOver coverage | 100% interactive elements | Full WCAG 2.1 AA |
| App Store rating floor | 4.0 (pull from store if below for >7 days) | 4.3 |

---

## 3. Phased Roadmap

---

### Phase 1: Foundation (V1.0 --> V1.1)

**Timeline:** Launch + 6 weeks
**Theme:** Fix what is broken, measure everything, earn the right to build new features.

---

#### 1.1 — Swipe Undo System

**Description:** Implement shake-to-undo and a floating "Undo" button with a 5-second countdown timer after every left-swipe (unsubscribe). The unsubscribe API call is deferred until the timer expires.

**User Story:** As a user who accidentally swiped left on an email I want to keep, I want to undo that action within a few seconds so that I do not lose a subscription I care about.

**Priority:** Must

**Dependencies:** Requires refactoring the swipe action handler to use a deferred execution model. The backend unsubscribe endpoint must support cancellation or the mobile client must simply delay the API call.

**Risks:** If the backend processes unsubscribes synchronously and immediately, we need a queue/delay mechanism server-side. Verify backend behavior before implementation.

**Success Metric:** Undo usage rate between 3-8% of all left-swipes (below 3% means the feature is undiscoverable; above 8% means users are swiping recklessly because undo exists).

---

#### 1.2 — Gesture Conflict Resolution

**Description:** Fix the scroll-vs-swipe conflict by implementing a gesture recognizer priority system. Vertical movement beyond 15 points before horizontal movement locks into scroll mode. Horizontal movement first locks into swipe mode. Add a subtle haptic tap when swipe mode engages so the user knows they are committing to a directional action.

**User Story:** As a user scrolling through email details on a card, I want the app to distinguish between my scroll and my swipe so that I do not accidentally unsubscribe.

**Priority:** Must

**Dependencies:** None. Pure client-side gesture work.

**Risks:** Low. Well-understood iOS pattern (Tinder, Bumble, and every card-swiping app has solved this).

**Success Metric:** Undo usage rate decreases after this ships (fewer accidental swipes means fewer undos needed). Track undo rate before and after.

---

#### 1.3 — Contextual Error States

**Description:** Replace all generic error alerts with specific, actionable error screens. Each error state gets: (a) a plain-language explanation of what happened, (b) a specific recovery action (retry, re-authenticate, check connection), and (c) a support contact path for persistent failures.

**Error states to implement:**

| Error | Copy | Action |
|-------|------|--------|
| OAuth expired | "Your Gmail connection expired. This happens every few weeks for security." | "Reconnect Gmail" button |
| Network timeout | "Looks like your connection dropped." | "Try Again" button + offline queue explanation |
| Unsubscribe failed | "We couldn't unsubscribe you from [sender]. Some senders make this hard." | "Try Again" / "Report Issue" / "Skip" |
| Rate limited | "Gmail is asking us to slow down. This will resolve in a few minutes." | Auto-retry with countdown timer |
| Empty inbox | "You've seen everything! Check back tomorrow for new subscriptions." | Navigate to stats/achievements |
| Server error | "Our servers are having a moment. Your progress is saved." | "Try Again" with exponential backoff |

**User Story:** As a user who encounters an error, I want to understand what went wrong and what I can do about it so that I do not feel frustrated or lose trust in the app.

**Priority:** Must

**Dependencies:** Backend must return typed error codes, not generic 500s. Coordinate with backend team to standardize error response format.

**Risks:** Backend error taxonomy may not exist yet. If the backend returns undifferentiated errors, the client can only distinguish network-level failures from server-level failures. This is still better than the current state.

**Success Metric:** Support ticket volume related to "app not working" decreases by 50% after implementation.

---

#### 1.4 — Session Complete Redesign

**Description:** Replace the dead-end session complete screen with a hub that shows: (a) session stats (emails processed, unsubscribed, time spent, XP earned), (b) progress toward next level/achievement, (c) navigation options: "Load More Emails," "View Achievements," "Share Session," "Done."

**User Story:** As a user who just finished a swiping session, I want to see what I accomplished and choose what to do next so that I feel rewarded and can continue engaging if I want to.

**Priority:** Must

**Dependencies:** None.

**Risks:** None.

**Success Metric:** 30% of users who see session complete tap "Load More" or "View Achievements" (currently 0% because there are no navigation options).

---

#### 1.5 — Achievement Unlock Display Improvement

**Description:** Achievement unlock notifications hold on screen for minimum 4 seconds or until user taps to dismiss. Add celebration animation (confetti particle effect), haptic feedback (success pattern), and a "Share" button on the unlock card. Queued unlocks (if multiple trigger at once) display sequentially, not stacked.

**User Story:** As a user who just unlocked an achievement, I want to savor the moment and optionally share it so that I feel rewarded for my effort.

**Priority:** Must

**Dependencies:** None.

**Risks:** Multiple simultaneous achievement unlocks (e.g., "First Unsubscribe" + "5 in a Row" during onboarding) need a queue system so they do not overlap or get lost.

**Success Metric:** Achievement share rate > 5% of all unlocks.

---

#### 1.6 — Onboarding Rewrite

**Description:** New onboarding flow in 4 screens: (1) Connect Gmail and show "You have X subscriptions" (real number, immediate value), (2) Interactive tutorial: practice swipe on a fake card, (3) Brief gamification explainer: "Earn XP, level up, unlock achievements," (4) First real session begins. Remove all gamification detail from onboarding — users will discover it naturally.

**User Story:** As a new user, I want to understand immediately what Junkpile does for me and how to use it so that I can start cleaning my inbox within 60 seconds of downloading.

**Priority:** Must

**Dependencies:** Backend must support a fast "subscription count" endpoint that returns an approximate count within 3 seconds of OAuth completion. If the full email scan takes longer, show a loading state with a progress indicator, then reveal the count with a dramatic animation.

**Risks:** If the initial email scan is slow (>10 seconds), users will drop off during onboarding. Backend optimization of the initial scan is a hard dependency.

**Success Metric:** Onboarding completion rate > 80% (industry benchmark for simple auth-gated apps). Currently unmeasured — this is also why we need analytics.

---

#### 1.7 — VoiceOver Accessibility Audit and Fix

**Description:** Full audit of every screen for VoiceOver compatibility. Every interactive element gets an accessibility label. Swipe actions are available via the VoiceOver rotor with custom actions ("Unsubscribe" and "Keep"). Charts in the stats view get accessibility descriptions. Achievement gallery is navigable.

**User Story:** As a VoiceOver user, I want to use Junkpile with the same ease as a sighted user so that I can manage my email subscriptions independently.

**Priority:** Must

**Dependencies:** None.

**Risks:** SwiftUI accessibility is generally good by default, but custom gesture recognizers (our card swipe) require explicit accessibility action overrides. Budget 1 week for the swipe accessibility work specifically.

**Success Metric:** 100% of interactive elements pass VoiceOver testing. Test with at least 2 VoiceOver users during TestFlight.

---

#### 1.8 — Analytics Instrumentation

**Description:** Implement event-based analytics tracking across the entire app. No third-party SDK — use a lightweight custom solution that sends events to our own backend, or adopt TelemetryDeck (privacy-first, EU-hosted, indie-friendly). Events to track from day one:

**Core Events:**
- `app_opened` (cold/warm, source: notification/widget/organic)
- `session_started`, `session_completed`, `session_abandoned`
- `card_swiped` (direction, time_on_card, sender_domain)
- `undo_triggered`, `undo_completed`, `undo_expired`
- `achievement_unlocked` (achievement_id)
- `achievement_shared`
- `error_encountered` (error_type, screen)
- `onboarding_step_completed` (step_number)
- `onboarding_completed`, `onboarding_abandoned` (at_step)
- `settings_changed` (setting_name, old_value, new_value)

**User Story:** As the product team, I want to understand how users interact with every feature so that I can make data-informed decisions about what to build next.

**Priority:** Must

**Dependencies:** Decision on analytics provider. Recommendation: **TelemetryDeck** for V1.x (privacy-first, no user tracking, GDPR compliant out of the box, $99/year for indie tier). Migrate to Mixpanel or Amplitude only if we need cohort analysis at scale (Phase 3+).

**Risks:** Over-instrumentation creates noise. Start with the event list above and expand only when a specific product question cannot be answered.

**Success Metric:** 100% of core user actions are tracked within 2 weeks of V1.1 launch. First data-driven product decision made within 30 days.

---

#### 1.9 — Crash Reporting

**Description:** Integrate crash reporting and performance monitoring. Recommendation: **Firebase Crashlytics** (free, best-in-class for iOS, real-time alerts). Alternative if we want to avoid Google entirely: **Sentry** (privacy-conscious, $26/month developer tier).

**User Story:** As the engineering team, I want real-time crash reports with stack traces and device context so that I can fix stability issues before they reach critical mass.

**Priority:** Must

**Dependencies:** None. Standalone integration.

**Risks:** Firebase Crashlytics requires the Firebase SDK, which adds ~4MB to binary size and introduces a Google dependency. If the "no external dependencies" principle is sacred, use Sentry instead. **Recommendation: Use Sentry.** It aligns with the privacy-first brand and avoids the optics of shipping Google's SDK in an app that accesses Gmail data.

**Success Metric:** Mean time from crash occurrence to developer awareness < 1 hour.

---

#### 1.10 — Push Notification Infrastructure Activation

**Description:** Activate push notifications with three notification types at launch. No more, no less:

1. **Streak reminder:** "You're on a 5-day streak! Don't let it die." Sent at user's preferred time (default 9am local) if they have not opened the app today.
2. **New subscriptions detected:** "12 new subscriptions found this week. Time to swipe!" Sent weekly on Monday morning.
3. **Achievement proximity:** "You're 3 unsubscribes away from unlocking 'Inbox Warrior'!" Sent once per achievement when user is within 20% of completion.

**User Story:** As a user who wants to maintain my email hygiene habit, I want timely reminders so that I remember to open Junkpile daily without it feeling spammy.

**Priority:** Should

**Dependencies:** Backend notification service must be built/activated. APNs integration on the backend. User timezone detection and preference storage.

**Risks:** Bad notification timing or frequency will cause users to disable notifications permanently. Start conservative: maximum 1 notification per day, respect Do Not Disturb, and allow granular opt-out per notification type in Settings.

**Success Metric:** Notification opt-in rate > 60%. Notification-driven session start rate > 15% of daily sessions.

---

### Phase 2: Engagement (V1.2 --> V1.3)

**Timeline:** V1.1 + 8 weeks
**Theme:** Make users come back every day. Deepen the game. Introduce social proof.

---

#### 2.1 — Smart Categorization and Batch Actions

**Description:** Before swiping, automatically categorize subscriptions into groups: Shopping/Retail, Social Media, News/Media, Finance, Travel, Software/SaaS, Other. Show category badges on cards. Enable "Quick Clean" mode: tap a category, see all senders, toggle keep/unsubscribe in bulk, confirm. This is NOT a replacement for swiping — it is an alternative mode for power users who want to process 50 emails in 2 minutes.

**User Story:** As a power user with hundreds of subscriptions, I want to bulk-unsubscribe by category so that I can clean my inbox faster without swiping through every single email.

**Priority:** Must

**Dependencies:** Backend must implement email sender categorization. Options: (a) rules-based using sender domain mapping (fast, imprecise), (b) lightweight ML classification on email headers (slower, more accurate). **Recommendation: Start with rules-based.** Maintain a curated sender-to-category mapping table. It covers 80% of common senders (Amazon, Facebook, NYT, etc.) and is deterministic. Add ML later only if the "Other" bucket exceeds 30% of emails.

**Risks:** Miscategorization erodes trust. If a bank email is categorized as "Shopping," users will doubt the system. Implement a "recategorize" option on every card.

**Success Metric:** Users who use Quick Clean process 3x more emails per session than swipe-only users.

---

#### 2.2 — Weekly Challenge System

**Description:** Introduce time-limited weekly challenges that give users a reason to open the app even when their inbox feels clean. Examples: "Unsubscribe from 10 shopping emails this week," "Process 50 emails in under 5 minutes," "Maintain your streak for 7 consecutive days." Challenges rotate weekly. Completing a challenge awards bonus XP and an exclusive badge. Missing a challenge has no penalty.

**User Story:** As a user who has already cleaned most of my inbox, I want new goals each week so that I have a reason to keep opening Junkpile.

**Priority:** Must

**Dependencies:** Backend challenge definition and tracking system. Client-side challenge UI (dedicated tab or home screen card).

**Risks:** If challenges feel impossible or irrelevant ("Unsubscribe from 20 finance emails" when the user has none), they will be ignored. Challenges must be personalized based on the user's remaining subscription mix. Start with 3 challenge templates and expand monthly.

**Success Metric:** 40% of weekly active users attempt at least one challenge. Challenge completion rate > 50%.

---

#### 2.3 — Home Screen Widgets (iOS)

**Description:** Three widget sizes:
- **Small:** Streak counter + "Swipe now" tap target.
- **Medium:** Streak counter + emails waiting + XP progress bar.
- **Large:** Streak counter + weekly activity mini-chart + "Start Session" button.

**User Story:** As a daily Junkpile user, I want to see my streak and pending emails on my home screen so that I remember to swipe and feel motivated by my progress.

**Priority:** Should

**Dependencies:** WidgetKit implementation. Shared data container between main app and widget extension. Background refresh for email count.

**Risks:** Widget data staleness. iOS limits background refresh frequency. The email count may be hours old. Mitigate by showing "last updated X minutes ago" text and refreshing on app open.

**Success Metric:** Widget adoption rate > 20% of active users. Users with widgets have 25% higher day-7 retention than users without.

---

#### 2.4 — Streak Protection and Freeze Mechanics

**Description:** Users earn one "Streak Freeze" for every 7-day streak maintained. A Streak Freeze automatically preserves the streak if the user misses one day. Maximum 2 freezes banked at a time. Freezes are consumed automatically — no user action required. A notification says: "Your streak was saved by a Streak Freeze! You have 1 remaining."

**User Story:** As a user who missed a day due to travel or illness, I want my streak to survive an occasional miss so that I do not feel punished and give up entirely.

**Priority:** Should

**Dependencies:** Streak tracking logic update. Notification system (from Phase 1).

**Risks:** If freezes are too abundant, streaks become meaningless. The 7-day earn rate and 2-freeze cap are deliberately tight. Do not increase these without data showing churn from streak loss.

**Success Metric:** Streak-loss churn decreases by 30% after implementation. Median streak length increases from X to Y (measure baseline first).

---

#### 2.5 — Friend Leaderboards (Lightweight Social)

**Description:** Users can add friends via iOS Contacts matching, share codes, or iMessage invite links. Leaderboard shows: weekly emails processed, current streak, total XP. No messaging, no commenting, no profiles, no feed. Just a ranked list of friends and their stats. Optional — users who never add friends see only their own stats.

**User Story:** As a user who wants a little competition, I want to see how my email cleanup compares to my friends so that I feel motivated to stay active.

**Priority:** Could

**Dependencies:** Backend user matching and leaderboard API. Privacy-safe contact matching (hash-based, Apple's standard pattern). iMessage share sheet integration.

**Risks:** Social features in utility apps historically underperform. Most users will not add friends. This is fine — the feature is for the 15% of users who are competitive and will become evangelists. Do not over-invest. MVP is a single screen with a ranked list. If fewer than 10% of users add even one friend within 60 days, deprecate the feature.

**Success Metric:** 15% of users add at least 1 friend. Users with friends have 40% higher 30-day retention.

---

#### 2.6 — Siri Shortcuts Integration

**Description:** Expose three Shortcuts actions: "Start Junkpile Session" (opens app to swiping), "Check My Streak" (returns streak count via Siri voice response), "How Many Emails Are Waiting" (returns pending count). Enables users to add Junkpile to their morning routine automations.

**User Story:** As a user who uses Siri Shortcuts for my morning routine, I want to include Junkpile so that email cleanup becomes an automatic part of my day.

**Priority:** Could

**Dependencies:** App Intents framework implementation. Backend endpoint for pending email count that is lightweight and fast.

**Risks:** Low adoption (Shortcuts usage is niche). But implementation cost is low (App Intents is straightforward in SwiftUI) and it signals to Apple that we are a good platform citizen — which helps with App Store featuring.

**Success Metric:** 5% of active users create at least one Shortcut. Treat this as an App Store positioning feature, not a retention driver.

---

### Phase 3: Expansion (V1.4 --> V2.0)

**Timeline:** V1.3 + 12 weeks
**Theme:** Grow the addressable market. Monetize sustainably. Deepen the product.

---

#### 3.1 — Outlook and Yahoo Mail Support

**Description:** Add Microsoft OAuth (Outlook/Hotmail/Live) and Yahoo OAuth as email provider options. Same swiping experience, same gamification. Provider selection happens at onboarding; users can connect multiple accounts.

**User Story:** As a user with an Outlook or Yahoo email account, I want to use Junkpile so that I can clean my non-Gmail inbox too.

**Priority:** Must

**Dependencies:** Backend OAuth implementation for Microsoft Graph API and Yahoo Mail API. Unsubscribe processing logic must be provider-agnostic (it mostly is — List-Unsubscribe headers are universal). Microsoft Graph API requires Azure AD app registration and potentially an app review.

**Risks:** Microsoft's OAuth review process for mail access is slow and strict (4-8 weeks). Begin the application process at the start of Phase 3, not at the end. Yahoo's API is poorly documented and may have reliability issues. Ship Outlook first, Yahoo second.

**Success Metric:** 20% of new signups choose Outlook within 90 days of launch. Multi-account users have 30% higher retention.

---

#### 3.2 — Premium Tier Launch (Junkpile Pro)

**Description:** Introduce a paid tier. See Section 4 (Monetization Strategy) for full details on what is free and what is premium.

**User Story:** As a power user who loves Junkpile, I want access to advanced features so that I can manage my email subscriptions even more effectively — and I am willing to pay for it.

**Priority:** Must

**Dependencies:** StoreKit 2 integration. Backend entitlement system. Receipt validation. Restore purchases flow. Paywall UI.

**Risks:** Paywalling the wrong features kills goodwill. The core swipe-to-unsubscribe loop MUST remain free forever. See Section 4 for the exact feature split.

**Success Metric:** 5% free-to-paid conversion rate within 90 days of launch. LTV > $15 per paying user.

---

#### 3.3 — iPad-Optimized Layout

**Description:** Two-column layout for iPad: left column shows the subscription list/categories, right column shows the swipe card or detail view. Keyboard shortcuts for power users (left arrow = unsubscribe, right arrow = keep, Cmd+Z = undo). Support for Stage Manager and external displays.

**User Story:** As an iPad user, I want a layout designed for my screen size so that Junkpile feels native and efficient on my device.

**Priority:** Should

**Dependencies:** SwiftUI NavigationSplitView refactor. Keyboard shortcut implementation.

**Risks:** Low. SwiftUI makes adaptive layouts relatively straightforward. The main risk is testing across iPad screen sizes and multitasking modes.

**Success Metric:** iPad users have equivalent session length and completion rates to iPhone users.

---

#### 3.4 — Email Frequency Insights

**Description:** For each sender, show: emails per week/month, when you last opened one, how often you engage. This helps users make informed keep/unsubscribe decisions. Display as a small info panel on the swipe card (expandable, not always visible).

**User Story:** As a user unsure whether to unsubscribe from a sender, I want to see how often they email me and whether I ever open them so that I can make a more informed decision.

**Priority:** Should

**Dependencies:** Backend must track and store email frequency metadata per sender. Gmail API provides some of this data (thread count, last received date). Full open-rate tracking requires email pixel analysis, which we will NOT do (privacy violation). Limit insights to: frequency, recency, and volume.

**Risks:** Displaying "You receive 12 emails/week from this sender" is powerful. Displaying "You never open these" requires read-status data from Gmail, which may be unreliable or permission-gated. Scope to frequency and recency only for V1.

**Success Metric:** Users who view frequency insights have 20% higher confidence in their swipe decisions (measured via optional post-session survey or reduced undo rate).

---

#### 3.5 — Subscription Health Score

**Description:** A single score (0-100) that represents the health of the user's inbox. Factors: number of active subscriptions, email-to-unsubscribe ratio, frequency of high-volume senders, streak consistency. Displayed prominently on the profile/stats screen. Trends over time shown via a line chart.

**User Story:** As a user, I want a single number that tells me how healthy my inbox is so that I feel a sense of progress and have a goal to improve.

**Priority:** Could

**Dependencies:** Algorithm design for score calculation. Historical data storage for trend visualization.

**Risks:** If the score feels arbitrary or gaming it is too easy, users will ignore it. The algorithm must be transparent: show the breakdown of what contributes to the score.

**Success Metric:** 60% of users check their score at least weekly. Users with improving scores have higher retention.

---

#### 3.6 — Apple Watch Companion (Minimal)

**Description:** A glanceable Watch app with: current streak count, daily goal progress (ring-style), and a complication for the watch face. No swiping on the Watch — the screen is too small for meaningful email triage. The Watch app is a motivation tool, not an interaction tool.

**User Story:** As an Apple Watch user, I want to see my Junkpile streak on my wrist so that I am reminded to open the app and stay on track.

**Priority:** Could

**Dependencies:** WatchKit/SwiftUI Watch implementation. Shared data via Watch Connectivity framework.

**Risks:** Apple Watch app development and testing is disproportionately expensive for the user value delivered. This is a "nice to have" that signals platform depth. Build it only if Phase 3 timeline permits.

**Success Metric:** Watch app install rate > 30% among users with Apple Watches. No meaningful retention impact expected — this is a brand/delight feature.

---

## 4. Monetization Strategy

### When to Introduce Monetization

**Not at launch. Not in Phase 1. Not in Phase 2.**

Introduce Junkpile Pro at V1.4 (Phase 3), after:
- Product-market fit is confirmed (day-30 retention > 20%)
- Core experience is polished and stable
- User base reaches 50,000+ active users
- App Store rating is stable at 4.5+

Premature monetization poisons the well. Users must love the free product before they will pay for more of it.

### What Stays Free Forever

The following features will NEVER be paywalled. This is a permanent commitment, not a temporary promotion:

- **Core swiping (unlimited)** — Swipe left/right on every email, no daily limits, no session caps
- **Unsubscribe processing** — Actually unsubscribing is the product. It is free.
- **Basic gamification** — XP, levels (all 20), streaks, basic achievements
- **Stats dashboard** — Weekly activity chart, session history, decision breakdown
- **Gmail support** — One connected Gmail account
- **Undo** — Safety feature, not a premium upsell
- **Push notifications** — Retention tool benefits us, not just the user

### Junkpile Pro Features

| Feature | Rationale for Premium |
|---------|----------------------|
| **Multiple email accounts** (2+ Gmail, Outlook, Yahoo) | Power user feature. One free account covers most users. |
| **Smart categorization + Quick Clean bulk mode** | Time-saving feature for heavy users. Worth paying for. |
| **Email frequency insights** (expanded sender analytics) | Data-driven decision support. Premium value. |
| **Subscription Health Score + trends** | Vanity metric with depth. Casual users do not need it. |
| **Exclusive achievements** (20 additional Pro-only achievements) | Collectors will pay for completionism. Does not disadvantage free users. |
| **Weekly challenges** (Pro challenges with higher XP rewards) | Free users still get challenges. Pro users get harder/more rewarding ones. |
| **Custom app icons** | Low-cost delight feature. Popular in indie apps. |
| **Friend leaderboards** (expanded from top 5 to unlimited) | Free users see top 5 friends. Pro users see full leaderboard + historical rankings. |

### Pricing

| Plan | Price | Rationale |
|------|-------|-----------|
| **Monthly** | $2.99/month | Below the impulse-buy threshold. Lower than Clean Email ($7.49/mo) and Cleanfox Pro ($3.49/mo). Junkpile is simpler and should be cheaper. |
| **Annual** | $19.99/year ($1.67/month) | 44% savings vs monthly. Standard iOS discount pattern. This is the target plan. |
| **Lifetime** | $39.99 (limited time at launch, then $49.99) | Generates upfront cash. Attracts indie app enthusiasts. Cap at first 10,000 lifetime purchases to limit long-term revenue loss. |

### Competitive Pricing Context

| Competitor | Price | What You Get |
|------------|-------|--------------|
| Clean Email | $7.49/mo or $59.99/yr | Full email management suite |
| Cleanfox Pro | $3.49/mo or $24.99/yr | Unsubscribe + carbon footprint |
| Unroll.me | Free (they sell your data) | Basic unsubscribe |

**Junkpile's position:** Cheaper than Clean Email (we do less), comparable to Cleanfox (we are more fun), and we do not sell your data (unlike Unroll.me). The gamification is the premium differentiator that no competitor offers.

---

## 5. Feature Kill List

### Features That Seem Obvious But Should NOT Be Built

#### Email Client Features (Reading, Composing, Searching)
**Why not:** This is the single most dangerous scope creep vector. The moment we add "read full email" or "reply," we are competing with Gmail, Outlook, Spark, and Apple Mail. We lose instantly. Junkpile shows email senders and subject lines only. That is the ceiling.

#### AI-Powered Unsubscribe Recommendations
**Why not:** "We think you should unsubscribe from these" is a trust landmine. If we recommend unsubscribing from something the user cares about, we lose their trust permanently. The entire point of the swipe UX is that the user makes every decision. We surface information (frequency, recency). We never make the decision.

#### Read-Later / Snooze Queue
**Why not:** This turns Junkpile into an email triage tool, which is a different product with different retention dynamics and a saturated competitive field (Spark, Superhuman, Sanebox). We unsubscribe. That is it.

#### Android Version
**Why not (for now):** Building a quality Android app doubles engineering cost and halves focus. iOS users spend 2-3x more on apps than Android users. Product-market fit must be proven on one platform before expanding. Android is a Series A conversation, not a V2.0 conversation.

#### Desktop / Web App
**Why not:** Junkpile's magic is the swipe gesture. It is a tactile, mobile-native interaction. A web version with click-to-unsubscribe is just a worse version of Clean Email. The mobile constraint IS the product.

#### Calendar Integration / Email Scheduling
**Why not:** Productivity suite creep. Not our market. Not our users. Not our problem.

#### "Inbox Zero" Certification or Shareable Badge
**Why not yet:** This sounds appealing but creates a perverse incentive to unsubscribe from everything, including emails users actually want, just to achieve "Zero." If we build this, it must be based on subscription health score, not raw inbox count. Defer until Subscription Health Score (3.5) ships and we can design it responsibly.

### Features to Defer Indefinitely

- **Machine learning email categorization** — Rules-based is sufficient. ML adds infrastructure complexity and a training data problem we do not have the scale to solve. Revisit at 500K+ users.
- **Natural language email summarization** — Cool demo, but not aligned with our "we do not read your email" brand. Hard pass.
- **Multi-language support** — English-first until we have evidence of international demand. Localization is expensive to maintain.
- **Family sharing plan** — Requires account linking, shared leaderboards, and billing complexity. Not worth the engineering cost until Pro subscriptions exceed 20K.

### Integration Requests to Decline

- **Slack/Teams integration** — "Get notified in Slack when you reach Inbox Zero!" Nobody wants this.
- **IFTTT/Zapier** — The Siri Shortcuts integration covers automation users. Third-party integration platforms add maintenance burden with no clear retention benefit.
- **Google Workspace / Enterprise** — Enterprise email management is a different market with different buyers, different compliance requirements, and different pricing. This is a consumer app. Decline all enterprise inquiries until Series A.

---

## 6. Anti-Stale Strategy

The fundamental challenge: once a user cleans their inbox, they have fewer emails to swipe. A successful Junkpile user generates less content for themselves over time. This is the paradox of a cleanup app — your best users need you least.

### How We Solve It

#### 6.1 — The Maintenance Loop

Even a clean inbox generates 3-10 new subscription emails per week. The app must transition from "cleanup mode" (high volume, intense sessions) to "maintenance mode" (low volume, quick daily check-ins). The shift should feel intentional, not like the app is dying.

**Implementation:**
- When a user's pending email count drops below 5, change the home screen messaging: "Your inbox is looking great. Here are a few new ones to review."
- Shorten the session expectation: maintenance sessions should feel like 60-90 seconds, not 10 minutes.
- Shift XP rewards toward streak maintenance, not volume. Day 30 of a streak should award more XP than unsubscribing 10 emails.

#### 6.2 — Seasonal Events (Quarterly)

Four themed events per year, aligned with email volume spikes:

| Quarter | Event | Theme |
|---------|-------|-------|
| Q1 (Jan) | **New Year Purge** | "Start the year clean." Double XP for all unsubscribes. Limited-edition "Fresh Start" achievement. |
| Q2 (Apr) | **Spring Cleaning** | Category-focused challenge: clean out one entire category (e.g., all Shopping emails). Exclusive "Spring Cleaner" badge. |
| Q3 (Jul) | **Summer Shred** | Speed-focused: process X emails in Y minutes. Timed challenge with global leaderboard. |
| Q4 (Nov) | **Black Friday Blitz** | Post-Black Friday, everyone's inbox is destroyed with promotional emails. "Unsubscribe from 25 retailers" challenge. This is our Super Bowl — highest email volume of the year. |

**Implementation:** Events run for 2 weeks. Backend defines event rules and rewards. Client renders themed UI (subtle color/icon changes, event banner). Content is defined server-side so events can be deployed without app updates.

#### 6.3 — Achievement Rotation

The initial 21 achievements will feel stale after 3-6 months for engaged users. Strategy:

- **Permanent achievements (Core):** The original 21 remain forever. They represent the baseline game.
- **Seasonal achievements (4-6 per quarter):** Tied to seasonal events. Expire when the event ends. Displayed in a "Past Seasons" gallery so users can show off historical badges.
- **Monthly micro-achievements (2 per month):** Small, surprising unlocks that rotate monthly. Examples: "Unsubscribed on a Sunday," "Processed exactly 42 emails in a session," "Used undo 3 times in one session." These are discoverable only after unlocking — they are not shown in the achievement gallery until earned.

This creates a living achievement system where there is always something new to unlock without inflating the permanent collection.

#### 6.4 — Curated Content Partnerships

Partner with email productivity experts and newsletter curators to provide:

- **"Worth Keeping" recommendations:** A monthly curated list of 5-10 newsletters that are actually worth subscribing to (tech, finance, culture, etc.). Displayed as a card in the session flow: "Before you go, here are newsletters our curators think are worth your time." Users can subscribe directly. This solves the "I unsubscribed from everything and now my inbox is boring" problem.
- **Email hygiene tips:** Short, rotating tips displayed on the session complete screen. "Did you know? The average person receives 121 emails per day." Keep them fresh monthly.

**Who to partner with:** The Newsette, Morning Brew's curation team, indie newsletter review sites. Revenue share is possible but not necessary at launch — the content value alone justifies the partnership.

#### 6.5 — Social Pressure Mechanics (Lightweight)

If leaderboards are built (Phase 2, feature 2.5):

- **Weekly leaderboard reset:** Rankings reset every Monday. This prevents early adopters from permanently dominating and gives every user a shot at #1 each week.
- **"Your friend just passed you" notification:** One notification per week, maximum. Triggers only if a friend overtakes the user on the leaderboard. Highly effective at re-engagement without being toxic.
- **No public shaming:** Users who stop using the app simply disappear from the active leaderboard. No "inactive" labels, no "last seen 5 days ago" guilt mechanics.

---

## 7. Technical Debt & Infrastructure

### Backend Requirements to Support This Roadmap

#### 7.1 — Error Code Taxonomy (Phase 1, Critical)

**Current state:** Backend returns generic HTTP 500 errors for most failure modes.
**Required:** Implement a typed error response format:

```json
{
  "error": {
    "code": "OAUTH_TOKEN_EXPIRED",
    "message": "Gmail OAuth token has expired",
    "recoverable": true,
    "retry_after_seconds": null,
    "user_action": "re_authenticate"
  }
}
```

Minimum error codes for V1.1:
- `OAUTH_TOKEN_EXPIRED`
- `OAUTH_SCOPE_INSUFFICIENT`
- `RATE_LIMITED` (with `retry_after_seconds`)
- `UNSUBSCRIBE_FAILED_NO_LINK`
- `UNSUBSCRIBE_FAILED_LINK_BROKEN`
- `UNSUBSCRIBE_FAILED_TIMEOUT`
- `EMAIL_FETCH_FAILED`
- `SERVER_INTERNAL_ERROR`

**Effort:** 1-2 sprints. Must be completed before the client-side error state work in Phase 1.

#### 7.2 — Deferred Unsubscribe Queue (Phase 1, Critical)

**Current state:** Unsubscribe requests are processed immediately on swipe.
**Required:** Implement a 5-second delay queue for unsubscribe processing to support the undo feature. Architecture:

1. Client sends `POST /unsubscribe` with a `deferred: true` flag.
2. Backend enqueues the unsubscribe with a 5-second TTL.
3. Client can send `DELETE /unsubscribe/{id}` within the TTL to cancel.
4. After TTL expires, the queue worker processes the unsubscribe.

Alternative: handle the delay entirely client-side (do not call the API until the 5-second timer expires). **Recommendation: Client-side delay.** Simpler, no backend changes, and the undo timer is a UX concern, not a data concern. The unsubscribe API call simply happens 5 seconds later.

**Effort:** 0 sprints if client-side. 1 sprint if server-side queue.

#### 7.3 — Subscription Count Fast Endpoint (Phase 1, High)

**Current state:** The initial email scan after OAuth may take 10-30+ seconds.
**Required:** A fast endpoint that returns an approximate subscription count within 3 seconds. Implementation options:
- Pre-compute the count during OAuth token exchange (background job).
- Return a rough estimate based on the first 100 emails scanned, then update asynchronously.

This is a hard dependency for the onboarding rewrite (Phase 1, feature 1.6).

**Effort:** 1 sprint.

#### 7.4 — Notification Service (Phase 1, Medium)

**Current state:** APNs infrastructure is set up but not integrated.
**Required:** Build a notification dispatch service that handles:
- Device token registration and management
- Timezone-aware scheduling
- Notification type preferences (per-user opt-in/opt-out)
- Rate limiting (max 1 per day)
- Template management for notification copy

**Technology recommendation:** Use a managed service (OneSignal free tier or Amazon SNS) rather than building from scratch. Notification delivery is a solved problem — do not re-solve it.

**Effort:** 2 sprints.

#### 7.5 — Email Provider Abstraction Layer (Phase 3, Critical)

**Current state:** Backend is likely tightly coupled to the Gmail API.
**Required:** Refactor email fetching and unsubscribe processing into a provider-agnostic interface:

```
interface EmailProvider {
  authenticate(credentials): AuthToken
  fetchSubscriptions(token, options): Subscription[]
  unsubscribe(token, subscriptionId): UnsubscribeResult
  getEmailFrequency(token, senderId): FrequencyData
}
```

Gmail, Outlook, and Yahoo implementations behind this interface. This must be completed before Outlook support ships.

**Effort:** 2-3 sprints. Begin refactoring at the start of Phase 3.

#### 7.6 — Entitlement and Billing System (Phase 3, Critical)

**Current state:** No billing system.
**Required:** Server-side entitlement management that:
- Validates Apple StoreKit 2 receipts (server-to-server)
- Tracks subscription state (active, expired, grace period, billing retry)
- Enforces feature gates based on entitlement status
- Handles restore purchases
- Supports lifetime purchases

**Technology recommendation:** Use RevenueCat ($0 until $2,500 MRR, then 1% of revenue). It handles StoreKit receipt validation, subscription state management, and cross-platform entitlements. Building this from scratch is 4-6 sprints of work that RevenueCat eliminates. The dependency is worth it.

**Effort:** 1 sprint with RevenueCat. 4-6 sprints without.

### Analytics Stack Recommendation

**Phase 1-2: TelemetryDeck**
- Privacy-first (no user tracking, GDPR compliant)
- EU-hosted
- $99/year indie tier
- Swift-native SDK
- Sufficient for event tracking, funnel analysis, and basic retention metrics

**Phase 3+: Evaluate Mixpanel or PostHog**
- Migrate only if we need: cohort analysis, A/B testing infrastructure, advanced segmentation
- PostHog is open-source and can be self-hosted (aligns with privacy brand)
- Mixpanel has better iOS SDK ergonomics

**Decision trigger:** Migrate when TelemetryDeck cannot answer a specific product question that is blocking a prioritization decision. Not before.

### Crash Reporting Recommendation

**Sentry** (not Firebase Crashlytics)

Rationale:
- No Google SDK dependency (cleaner optics for an app accessing Gmail)
- Privacy-conscious (data processing in EU available)
- Performance monitoring included
- $26/month developer tier (free tier available for <5K events/month)
- Excellent SwiftUI support including breadcrumbs and view hierarchy

### CI/CD for iOS Builds

**Recommendation: Xcode Cloud**

Rationale:
- Native Apple integration (no third-party dependency)
- Free tier includes 25 compute hours/month (sufficient for indie team)
- Direct TestFlight deployment
- App Store Connect integration for release management
- Triggered by Git push to specific branches

**Pipeline configuration:**
- `main` branch: build + test + deploy to TestFlight (internal)
- `release/*` branch: build + test + deploy to TestFlight (external)
- Tag `v*`: build + test + submit to App Store Review
- Pull requests: build + test only (no deployment)

**Alternative if Xcode Cloud is insufficient:** GitHub Actions with `fastlane` and self-hosted Mac runner. More flexible but more maintenance.

---

## Appendix: Roadmap Timeline Summary

```
Month 1-2:     V1.0 Launch Prep (must-have fixes from Section 2)
Month 2-3:     V1.0 App Store Launch
Month 3-4:     V1.1 (Phase 1 — Foundation: analytics, crash reporting, notifications, undo)
Month 5-6:     V1.2 (Phase 2a — Engagement: categories, challenges, widgets)
Month 7-8:     V1.3 (Phase 2b — Engagement: streaks, leaderboards, Shortcuts)
Month 9-10:    V1.4 (Phase 3a — Expansion: Outlook, Premium launch)
Month 11-12:   V1.5 (Phase 3b — Expansion: iPad, insights, health score)
Month 13+:     V2.0 planning based on data from Phases 1-3
```

**Total timeline to V2.0: 12-14 months from today.**

This timeline assumes a team of 2-3 iOS engineers, 1 backend engineer, and 1 designer. Adjust by +50% for a solo developer.

---

*This document is a living plan. Review monthly. Update quarterly. Kill features that do not earn their keep. Ship the things that matter.*
