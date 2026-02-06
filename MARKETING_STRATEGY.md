# Junkpile: Marketing Strategy

**Version:** 1.0
**Date:** February 5, 2026
**Status:** Pre-Launch

---

## 1. Positioning & Messaging

### Core Value Proposition

**Lead with the problem, not the game.**

The average person receives 121 emails per day. Over half are subscriptions they never asked for or stopped reading years ago. Every morning starts with a scroll through noise just to find what matters. People know they should unsubscribe but the friction is real: find the unsubscribe link, confirm on a sketchy webpage, repeat 200 times. Nobody does it. The inbox just gets worse.

**Junkpile makes inbox cleanup effortless.** One swipe, one second, done. No hunting for tiny unsubscribe links. No confirming on third-party pages. No wondering if it actually worked. Connect your Gmail, swipe through the mess, and reclaim your inbox in minutes instead of months.

The gamification exists to solve a specific behavioral problem: unsubscribing is a chore people abandon halfway through. XP, streaks, and achievements turn a tedious task into something you actually finish.

### Tagline Options

1. **"Your inbox has 200 subscriptions. Let's fix that."** -- Direct, quantified, problem-aware. Works well in App Store and ads.
2. **"Swipe left on junk mail."** -- Instantly communicates the mechanic. Borrows familiar Tinder language without belaboring the metaphor.
3. **"Unsubscribe from everything. Finally."** -- Captures the emotional relief. That word "finally" does heavy lifting.
4. **"Clean inbox. Zero effort."** -- Benefit-first. Strong for App Store subtitle.
5. **"The five-minute inbox detox."** -- Time-boxed promise. Good for ad copy and social content.

**Recommended primary:** "Swipe left on junk mail." -- It is memorable, immediately communicates the mechanic, and has inherent shareability.

**Recommended App Store subtitle:** "Clean inbox. Zero effort."

### Key Differentiators vs. Competitors

| Differentiator | Junkpile | Clean Email | Unroll.me | Cleanfox |
|---|---|---|---|---|
| **Interaction model** | Swipe-based, one decision at a time | Dashboard/list management | Rollup bundles + list | List-based bulk actions |
| **Time to value** | Under 60 seconds from install to first unsubscribe | Requires learning dashboard UI | Fast but pushes rollup feature | Moderate setup |
| **Engagement model** | Gamified progression (XP, levels, achievements, streaks) | None | None | Carbon footprint angle |
| **Data practices** | OAuth only, no email content storage, no data sales, Apple-native frameworks | Subscription model, stores data | Sold anonymized user data (Slice/Nielsen scandal, 2017) | GDPR-focused but EU-centric |
| **Platform** | iOS-native, SwiftUI, feels like an Apple app | Cross-platform, web-first feel | Cross-platform | Cross-platform |
| **Price model** | TBD (see note below) | $11/mo premium | Free (data monetization) | Free with premium |

**Pricing note:** Junkpile should strongly consider a freemium model: free for the first 50 unsubscribes (enough to feel the value), then a one-time purchase of $4.99 or annual subscription of $9.99/year. One-time purchase builds trust with privacy-conscious users. Subscription funds ongoing API costs. Test both.

### Trust Messaging

Trust is the single biggest barrier to adoption for any email app. Every piece of marketing must proactively address it. This is not optional supplementary copy; it belongs in the App Store description, the onboarding flow, the landing page above the fold, and every ad.

**Trust pillars to communicate everywhere:**

1. **"We never read your emails."** Junkpile accesses sender and subject metadata only. Email bodies are not read, stored, or processed. Say this explicitly and repeatedly.
2. **"We never sell your data."** Name the Unroll.me scandal directly in comparison content. "Remember when Unroll.me got caught selling your data? We are built differently."
3. **"OAuth only. We never see your password."** Explain this in plain language: "You log in through Google directly. We never touch your password. You can revoke access anytime in your Google account settings."
4. **"Built with Apple frameworks only."** No third-party analytics SDKs. No Facebook SDK. No tracking pixels. For the privacy-conscious iOS user, this is a significant signal.
5. **"App Store privacy label: clean."** Apple's privacy nutrition labels are visible before download. Ensure Junkpile's label is minimal. Screenshot it and use it in marketing materials.
6. **"Revoke anytime."** Include clear instructions for revoking OAuth access in the app settings, in the FAQ, and in the App Store description. Lowering the exit barrier paradoxically increases entry.

**Trust messaging framework for all copy:**

> Junkpile connects to Gmail through Google's official OAuth. We access sender names and subject lines to identify subscriptions. We never read your email content. We never store your emails. We never sell your data. We use zero third-party tracking SDKs. You can revoke access from your Google account at any time, and all your data is deleted immediately.

---

## 2. Launch Strategy

### Pre-Launch (8-6 Weeks Before Launch)

**Week 8-7: Foundation**

- **Landing page at junkpile.app** (or similar domain). Single page: headline, 15-second screen recording GIF of the swipe mechanic, trust messaging, email capture for waitlist. Build with a simple static site (Carrd, or a single-page Next.js deploy). No complex infrastructure.
- **Waitlist with built-in virality.** Use a tool like Viral Loops or build a simple referral mechanic: "You are #847 on the waitlist. Share your link to move up." Each referral moves the user up 10 spots. This is low-effort to implement and generates organic sharing.
- **App Store pre-order page.** Apple allows pre-orders up to 180 days before launch. Set up the listing early. This lets you start collecting pre-orders and locks in your App Store URL for all marketing materials.
- **Create social accounts.** Twitter/X (@junkpileapp), TikTok (@junkpileapp), Instagram (@junkpileapp). Secure the handles even if you do not post immediately.

**Week 6-5: Beta Program**

- **TestFlight beta with 50-100 users.** Recruit from:
  - r/iOSBeta (readers are early adopters who love trying new apps)
  - r/productivity (inbox management is a perennial topic)
  - Personal and professional networks
  - Tech Twitter: post a 30-second screen recording with "Building an app that lets you swipe-unsubscribe from emails. Looking for 50 beta testers." Developer build-in-public content performs well.
- **Beta feedback loop.** Use a simple Typeform or Google Form linked from the app's settings screen. Ask three questions: (1) What worked? (2) What frustrated you? (3) Would you pay for this? Follow up personally with every beta tester. At 50-100 people this is feasible and generates loyalty.
- **Fix critical UX issues before public launch.** The swipe undo, accidental swipe prevention, and accessibility support are not nice-to-haves. They are launch blockers. Beta testers will surface these immediately.

**Week 4-3: Content Seeding**

- **Write 2-3 blog posts** for launch week SEO (host on junkpile.app/blog):
  - "How to Unsubscribe from Emails in Gmail (2026 Guide)" -- pure SEO play targeting high-volume search queries.
  - "I Unsubscribed from 200 Emails in 10 Minutes. Here's What Happened." -- personal narrative, shareable, good for social.
  - "Why We Built an Email App That Never Reads Your Email" -- trust/transparency piece, good for Hacker News.
- **Record 3-5 TikTok/Reels.** Short-form video content to have ready for launch week:
  - Screen recording: speed-run unsubscribing from 50 emails in 2 minutes.
  - "POV: You just cleaned up 3 years of subscription emails" with satisfying swipe montage.
  - "Email apps that sell your data vs. Junkpile" -- direct competitor callout.
- **Prepare press kit.** One-page PDF: app description, screenshots, founder bios, key stats from beta ("Average beta tester unsubscribed from 87 emails in their first session"). Host at junkpile.app/press.

**Week 2-1: Outreach**

- **Email 15-20 journalists and newsletter writers.** Do not blast a generic press release. Personalize each email. Target:
  - **Tech journalists:** Jason Snell (Six Colors), John Gruber (Daring Fireball), Federico Viticci (MacStories) -- these cover iOS-native apps and appreciate SwiftUI craftsmanship.
  - **Newsletter writers:** Matt Birchler (Birchtree), Dense Discovery, The Sample.
  - **Productivity writers:** Anyone who has written about email management in the last 6 months (search "email unsubscribe" on Google News and pitch the authors).
- **Pitch angle for press:** "This team built an email unsubscribe app using zero third-party dependencies and never reads your email content. In a post-Unroll.me world, here's what privacy-first email management looks like." The privacy angle is the hook, not the gamification.
- **Line up 3-5 micro-influencers** (10K-100K followers) in the productivity/tech space for launch week posts. Offer free lifetime access (costs you nothing) in exchange for an honest review. Target:
  - YouTube: channels like Christopher Lawley (iPad/iOS productivity), Thomas Frank (productivity systems), or smaller creators in the "desk setup / digital minimalism" niche.
  - TikTok: search "email tips" and "inbox zero" -- creators in this space have high engagement and low sponsorship rates.

### Launch Day Playbook

**The morning of launch (coordinate for 9 AM ET, Tuesday or Wednesday -- avoid Monday and Friday):**

1. **Flip the App Store listing live.** If using pre-orders, the app auto-releases. Otherwise, submit 3-4 days early and coordinate release date with Apple.
2. **Send waitlist email.** Subject: "Junkpile is live. Go unsubscribe from everything." Include direct App Store link. Keep it to 3 sentences.
3. **Post to all social channels simultaneously.** Pin the launch post. Include a 15-second video of the swipe mechanic.
4. **Submit to Product Hunt.** This requires preparation:
   - Have 3-5 people ready to leave genuine, detailed reviews in the first hour (not "Great app!" -- actual descriptions of their experience).
   - Maker comment: post a 2-paragraph story about why you built Junkpile. Be personal. Mention the problem you experienced firsthand.
   - Respond to every comment within 30 minutes for the first 12 hours.
   - Target: Top 5 of the day. Achievable for a polished, consumer-facing app with good visuals.
5. **Post to Hacker News.** Title: "Show HN: Junkpile -- Swipe to unsubscribe from emails (iOS, privacy-first)." The HN crowd will care about the technical decisions (SwiftUI-only, no third-party SDKs, OAuth-only). Be ready to answer technical questions in comments.
6. **Post to Reddit.** Three separate posts over the day (not simultaneously, space by 4-6 hours):
   - r/iphone -- "I built an app that lets you swipe-unsubscribe from emails. No ads, no data selling."
   - r/productivity -- "Cleaned up 200 email subscriptions in 10 minutes with an app I made"
   - r/apple -- if the first two gain traction, cross-post.
   - **Reddit rules:** Be transparent that you are the developer. Do not astroturf. Redditors will check your post history. Authenticity is mandatory.
7. **Activate influencer posts.** Coordinate so reviews go live within the first 6 hours of launch.
8. **Monitor and respond.** One person should be dedicated to responding to every App Store review, social media comment, Reddit reply, and support email for the entire day. Response time under 1 hour.

### Post-Launch: First 30 Days

**Days 1-7: Momentum**

- Respond to every App Store review (Apple allows developer responses). Thank positive reviewers. Address negative reviews with specifics ("We're shipping swipe undo in version 1.1 next week").
- Publish the "I Unsubscribed from 200 Emails" blog post. Share across social.
- Post daily stats on Twitter/X: "Day 3: Junkpile users have unsubscribed from 12,847 emails." Real-time social proof.
- Email waitlist non-converters with a nudge: "487 people unsubscribed from an average of 94 emails yesterday. Your inbox is waiting."

**Days 7-14: Iteration**

- Ship version 1.1 with the top 3 user-requested features from launch feedback (swipe undo should be in this update if not in 1.0).
- Write an App Store "What's New" that demonstrates you listen to users.
- Pitch a "one week later" follow-up to any journalist who covered the launch.
- Begin collecting and sharing user testimonials (with permission). Screenshot DMs, tweets, and App Store reviews for social content.

**Days 14-30: Expansion**

- Begin Apple Search Ads campaigns (see Paid Channels below).
- Submit to Apple's editorial team for App Store featuring. Email AppStorePromotion@apple.com with your press kit, key metrics from the first two weeks, and a note about your all-Apple-frameworks approach. Apple loves promoting apps built with SwiftUI.
- Launch a referral program in-app: "Share Junkpile with a friend, both get 500 XP." Low-friction, aligns with the gamification system.
- Begin testing TikTok ad creative using organic content that performed well.

### App Store Optimization (ASO)

**App Name:** Junkpile: Email Unsubscribe

**Subtitle:** Clean inbox. Zero effort.

**Keywords (100 character limit, comma-separated, no spaces):**

```
unsubscribe,email,cleanup,inbox,junk,mail,spam,subscription,gmail,newsletter,clean,organize,swipe
```

**Keyword rationale:**
- "unsubscribe" -- high intent, moderate competition, exact user need.
- "email cleanup" / "inbox clean" -- high volume search terms.
- "junk mail" / "spam" -- users search these even though Junkpile is not technically a spam filter. Adjacent intent.
- "gmail" -- platform-specific, captures users searching for Gmail tools.
- "newsletter" -- captures the "too many newsletters" pain point.
- "swipe" -- low competition, captures curiosity searches.

**App Store Description (first 3 lines are critical -- visible before "Read More"):**

> Your inbox has hundreds of subscriptions you never read. Junkpile lets you unsubscribe from all of them in minutes -- just swipe left. No hunting for unsubscribe links. No sketchy confirmation pages. Connect your Gmail, start swiping, and take your inbox back.

> **Privacy first:** Junkpile never reads your email content. We access sender info only, through Google's official OAuth. No third-party SDKs. No data sales. Ever. Revoke access anytime.

> **How it works:**
> 1. Connect your Gmail securely through Google sign-in.
> 2. Junkpile identifies your subscriptions automatically.
> 3. Swipe left to unsubscribe. Swipe right to keep. That's it.
> 4. Earn XP, unlock achievements, and track your progress as you clean.

> **Features:**
> - One-swipe unsubscribe from any email subscription
> - Gamified experience: XP, 20 levels, 21 achievements, daily streaks
> - Session stats so you can see your cleanup progress
> - No email content is ever read, stored, or shared
> - Built entirely with Apple frameworks -- no third-party tracking

**Screenshots (6 required, prioritize first 3):**

1. **Hero shot:** The swipe interface in action, mid-swipe, with a subscription card visible. Overlay text: "Swipe left to unsubscribe."
2. **Before/after:** Split screen showing cluttered inbox vs. clean inbox. Overlay text: "200 subscriptions cleaned in 10 minutes."
3. **Privacy screen:** Show the OAuth connection screen with overlay text: "We never read your emails. Ever."
4. **Stats/progress:** Show the gamification dashboard with XP, level, and achievements. Overlay text: "Track your cleanup progress."
5. **Achievement unlock:** Show an achievement pop-up mid-session. Overlay text: "Earn achievements as you clean."
6. **Streak/engagement:** Show the daily streak counter. Overlay text: "Build your streak. Keep your inbox clean."

**Screenshot design notes:** Use device frames (iPhone 15 Pro). Use a consistent color palette that matches the app. Dark mode screenshots tend to perform better in the App Store. Test both.

---

## 3. Growth Channels

### Organic Channels (Ranked by Expected ROI)

**1. App Store Search (ASO) -- Highest ROI**

- Cost: Time only.
- Why: High-intent users searching "unsubscribe emails" or "email cleanup" are your best converters. They already have the problem.
- Action: Optimize keywords monthly based on App Store Connect search analytics. Track impression-to-install conversion rate. A/B test screenshots using Apple's Product Page Optimization.
- Expected volume: 60-70% of organic installs will come from App Store search for a utility app.

**2. TikTok / Instagram Reels -- Highest Viral Potential**

- Cost: Time to create (1-2 hours per video).
- Why: The swipe mechanic is inherently visual and satisfying. Email clutter is a universally relatable pain point. Short-form video is the highest-reach organic channel in 2026.
- Content formats that work:
  - **Speed runs:** "Unsubscribing from 100 emails in 3 minutes" with a timer overlay.
  - **Satisfaction content:** Montage of swiping away junk with a satisfying sound effect on each swipe.
  - **Relatable humor:** "Me opening my email vs. me after Junkpile" with a before/after reaction.
  - **Stats reveals:** "I just found out I was subscribed to 347 email lists. Let's fix that." Show the cleanup process.
- Posting cadence: 3-4 times per week. Repurpose the same content across TikTok, Reels, and YouTube Shorts.
- Expected reach: Highly variable (10K-2M per video) but one viral hit can drive thousands of installs.

**3. Reddit -- Highest Trust Channel**

- Cost: Time only (but high time investment per post due to community norms).
- Why: Reddit users are early adopters, privacy-conscious, and influential in tech circles. A well-received Reddit post generates installs, press coverage, and backlinks simultaneously.
- Target subreddits:
  - r/productivity (2.4M members) -- frame around inbox management systems.
  - r/iphone (5M+ members) -- frame around useful iOS apps.
  - r/apple (4M+ members) -- frame around SwiftUI-native design.
  - r/privacy (1.6M members) -- frame around the privacy-first architecture. This community will scrutinize your data practices. Be prepared with detailed answers.
  - r/digitalminimalism (300K members) -- frame around reducing digital noise.
  - r/sideproject (100K members) -- build-in-public narrative.
  - r/swiftui (50K members) -- developer community, technical credibility.
- Cadence: One post per subreddit per launch phase (pre-launch, launch, post-launch). Never cross-post; write unique content for each community.

**4. SEO / Blog Content -- Highest Long-Term ROI**

- Cost: Time to write (4-6 hours per article).
- Why: "How to unsubscribe from emails" has ~40K monthly searches. A well-optimized article can drive consistent organic traffic for years.
- Priority articles:
  1. "How to Unsubscribe from Emails in Gmail (2026)" -- target "unsubscribe gmail," "stop email subscriptions"
  2. "Best Email Unsubscribe Apps for iPhone (2026)" -- target "email unsubscribe app," appear in your own comparison
  3. "Is Unroll.me Safe? Privacy Concerns Explained" -- target competitor brand searches, redirect to your privacy-first alternative
  4. "How Many Email Subscriptions Do You Have? (The Average Will Shock You)" -- data-driven content for backlinks and social shares
- Host on junkpile.app/blog with proper schema markup and internal links to the App Store.

**5. Twitter/X Build-in-Public -- Highest Network Effects**

- Cost: 15 minutes per day.
- Why: The indie iOS dev community on Twitter is active and supportive. Build-in-public threads get engagement, followers, and eventual press coverage.
- Content:
  - Weekly progress updates with screenshots.
  - Technical deep-dives on SwiftUI implementation decisions.
  - Transparent metrics: download numbers, retention rates, revenue.
  - Celebrate milestones: "Junkpile users have unsubscribed from 100,000 emails."

**6. Word of Mouth / Referral -- Highest LTV Users**

- Cost: Engineering time for referral system.
- Why: Referred users have 2-3x higher retention than acquired users.
- Mechanic: "Share Junkpile, both you and your friend get 500 XP." Triggered after the user completes their first cleanup session (high-intent moment). Use iOS share sheet for frictionless sharing.

### Paid Channels Worth Testing

**1. Apple Search Ads (Priority 1 -- Test in Week 3)**

- Why: Highest intent paid channel. Users are actively searching the App Store.
- Budget: Start at $20/day. Scale to $50/day if CPA is under $2.
- Keywords to bid on:
  - **Exact match:** "unsubscribe emails," "email cleanup," "inbox cleaner," "junk mail app"
  - **Competitor conquesting:** "clean email app," "unroll me alternative" -- these are legal to bid on.
  - **Broad match (discovery):** "email," "inbox," "subscription" -- use broad match to discover new keywords, then promote winners to exact match.
- Target CPA: $1.00-$2.00 (achievable for a utility app in a non-hypercompetitive category).
- Optimization: Test multiple Creative Sets (Apple allows custom screenshot sets per ad group). A/B test privacy-first messaging vs. speed/convenience messaging.

**2. TikTok Ads (Priority 2 -- Test in Week 4)**

- Why: Low CPMs ($3-8), young-skewing audience, and the creative format (short video) matches the app's visual appeal.
- Budget: Start at $30/day.
- Creative: Use organic TikTok content that performed well. TikTok ads that look like organic content outperform polished ads 3:1.
- Targeting: iOS users, 18-35, interests in productivity, technology, email.
- Target CPA: $1.50-$3.00.

**3. Instagram/Facebook Ads (Priority 3 -- Test in Month 2)**

- Why: Broad reach, good for lookalike audiences once you have 500+ installs.
- Budget: Start at $25/day.
- Creative: Carousel ad showing the swipe mechanic in 3 frames. Video ad repurposed from TikTok content.
- Targeting: iOS users, 22-40, interests in productivity apps, Gmail users.
- Target CPA: $2.00-$4.00.

**Do NOT test (yet):** Google Ads (search intent is better captured by Apple Search Ads for an iOS app), Twitter/X Ads (high CPMs, low conversion for consumer apps), Podcast ads (too expensive for pre-scale, revisit at $10K/mo revenue).

### Partnership & Integration Opportunities

1. **Productivity YouTubers** -- Offer affiliate deals (rev share on subscriptions driven by their unique link). Thomas Frank, Ali Abdaal's team, Matt D'Avella adjacent creators.
2. **Newsletter writers** -- Partner with newsletters about productivity, tech, or digital wellness. Offer their readers exclusive access or bonus XP. Targets: Superhuman's blog (adjacent product), Tiago Forte's audience (Building a Second Brain community), Cal Newport's audience (digital minimalism).
3. **Apple** -- Apply for App Store editorial featuring. Emphasize the all-Apple-frameworks stack, SwiftUI, and SwiftData. Apple actively promotes apps that showcase their latest technologies. Contact AppStorePromotion@apple.com.
4. **Gmail-adjacent tools** -- Reach out to Superhuman, Spark, and Mimestream to explore cross-promotion. "Clean your inbox with Junkpile, then experience it with [email client]." Non-competitive, mutual benefit.
5. **Digital wellness organizations** -- Partner with Center for Humane Technology or similar organizations for credibility and reach. "Reduce your daily digital noise."

---

## 4. Retention Strategy

### How Gamification Supports Retention (When Done Right)

Gamification in Junkpile is not the product; it is the behavioral scaffolding that makes the product work. The core job-to-be-done is "clean up my inbox." Gamification ensures users actually complete that job and come back to maintain it.

**Principles:**

1. **Gamification must never gate core functionality.** Users should never need to "earn" the ability to unsubscribe. XP and levels are rewards for progress, not paywalls.
2. **Early achievements must be trivially easy.** The first achievement should trigger within the first 30 seconds ("First Swipe" -- unsubscribe from your first email). Immediate reinforcement.
3. **The progression curve must match the cleaning curve.** Most users will have a large initial cleanup (50-200 unsubscribes) followed by smaller maintenance sessions (5-10 per week). XP rewards must scale accordingly:
   - **Initial cleanup:** Rapid level progression (levels 1-8 in the first session). This feels rewarding.
   - **Maintenance phase:** Slower but steady progression (levels 9-15 over weeks 2-8). Daily streaks and weekly achievements become the primary motivators.
   - **Endgame:** Levels 16-20 are prestige/completionist. Achievements in this range are rare and shareable.
4. **Achievements must be surprising, not just expected.** At least 5 of the 21 achievements should be hidden/secret, unlocked by specific behaviors the user discovers organically. Example: "Night Owl" -- unsubscribe from 10 emails after midnight. "Speed Demon" -- unsubscribe from 20 emails in under 60 seconds.

### Push Notification Strategy

**Guiding principle:** Every push notification must provide value or be delightful. If it is neither, do not send it.

**What to Send:**

| Notification | Timing | Frequency | Purpose |
|---|---|---|---|
| "You have 12 new subscriptions to review" | When new subscription emails are detected (batch, not real-time) | Max once per day | Core value -- reminds user of the problem |
| "Your 7-day streak is alive! Swipe through today's batch?" | 10 AM local time, only if user has an active streak of 3+ days | Daily during active streak | Streak maintenance is a proven retention mechanic |
| "Achievement unlocked: Inbox Hero (unsubscribed from 100 emails)" | Immediately upon unlock | Event-driven only | Celebration, shareable moment |
| "Your inbox has gotten 43% quieter since you started" | Weekly, Sunday evening | Weekly | Progress reflection, reinforces value |

**What NOT to Send:**

- Never send "We miss you!" or "Come back!" guilt notifications. They erode trust and trigger uninstalls.
- Never send more than 2 push notifications per day under any circumstance.
- Never send notifications that require action within a time window ("Unsubscribe now or lose your streak!"). This creates anxiety, not engagement.
- Never send notifications about features, updates, or promotions via push. Use in-app messaging for these.
- Never send push notifications in the first 24 hours after install. Let the user establish their own usage pattern first.

**Permission strategy:** Request push notification permission after the user completes their first cleanup session (not during onboarding). Frame it as: "Want to know when new subscriptions pile up? We'll let you know, gently." This timing ensures the user has experienced value before being asked for permission, dramatically increasing opt-in rates (expected: 55-65% vs. 35-40% for onboarding prompts).

### Re-Engagement Campaigns for Churned Users

**Definition of churn:** No app open in 14 days.

**Email re-engagement sequence** (requires email capture during signup, which OAuth provides):

1. **Day 14 (after last open):** "Your inbox added ~47 new subscriptions since your last cleanup." Use actual data from their connected account if available, or average estimates if not. Subject line: "Your inbox missed you." CTA: "Open Junkpile."
2. **Day 30:** "Quick update: we shipped [top user-requested feature]. Also, your inbox probably has 100+ new subscriptions by now." Subject line: "New in Junkpile + your inbox update." CTA: "See what's new."
3. **Day 60:** Final email. "We'll stop emailing you after this (unlike all those subscriptions cluttering your inbox). If you want to clean up, Junkpile is still here." Subject line: "Last email from us (ironic, right?)." Self-aware humor works for this audience.
4. **After Day 60:** Stop all re-engagement. Continuing to email a disengaged user makes you the problem you are solving.

**In-app re-engagement (for users who return organically):**

- Show a "Welcome back" screen with their stats: "You unsubscribed from 87 emails last time. 34 new subscriptions have piled up since then. Ready to swipe?"
- Do NOT penalize returning users by resetting streaks or removing progress. Their XP and level should be exactly where they left them.

### Milestone-Based Engagement Hooks

These are specific, pre-defined moments that trigger delight and sharing:

| Milestone | Trigger | In-App Experience | Sharing Prompt |
|---|---|---|---|
| First unsubscribe | 1 email unsubscribed | Confetti animation + "First one down" message | None (too early) |
| "Getting Started" | 10 unsubscribes | Achievement badge + XP bonus | None |
| "Inbox Apprentice" | 50 unsubscribes | Level-up animation + stat summary | "Share your progress?" with pre-filled text: "I just unsubscribed from 50 emails with @junkpileapp" |
| "Inbox Master" | 100 unsubscribes | Special achievement + animated badge | Share card with stats (visual, designed for Instagram/Twitter) |
| "First Week Streak" | 7-day streak | Streak badge + bonus XP | "Share your streak?" |
| "Inbox Zero Hero" | All identified subscriptions reviewed | Full-screen celebration + comprehensive stats dashboard | Auto-generated share card: "I reviewed all [X] of my email subscriptions. [Y] unsubscribed, [Z] kept." |

**Share card design:** Create a visually appealing, branded card (think Spotify Wrapped but for email) that users can screenshot and share. Include: total unsubscribes, time spent, level reached, and a Junkpile watermark/logo. This is your single most important organic growth asset.

---

## 5. Metrics & Goals

### North Star Metric

**Total emails unsubscribed across all users.**

Why this and not DAU or downloads:

- It directly measures the value Junkpile delivers. Every unsubscribe is a problem solved.
- It correlates with retention (users who unsubscribe more come back more, because they have seen the value).
- It is a compelling marketing number ("Junkpile users have cleaned up 1 million email subscriptions").
- It aligns team incentives correctly: to grow this number, you must acquire users, retain them, AND make the core experience work well.

### Leading Indicators to Track

| Metric | What It Tells You | Healthy Range | Tool |
|---|---|---|---|
| **Day 1 retention** | Is onboarding working? Do users experience value immediately? | 40-50% | App Store Connect / custom analytics |
| **Day 7 retention** | Are users coming back after the initial cleanup? | 20-30% | App Store Connect / custom analytics |
| **Day 30 retention** | Is the maintenance loop working? | 10-15% | App Store Connect / custom analytics |
| **Emails unsubscribed per session** | Is the core mechanic satisfying? | 15-30 | In-app telemetry |
| **Session length** | Are users engaged or bouncing? | 3-7 minutes | In-app telemetry |
| **Sessions per week** | Is the habit forming? | 2-4 during first month | In-app telemetry |
| **Unsubscribes per user (lifetime)** | Total value delivered per user | 50-150 | In-app telemetry |
| **Conversion to push notification opt-in** | Is the permission prompt well-timed? | 55-65% | In-app telemetry |
| **App Store rating** | Overall user satisfaction | 4.5+ stars | App Store Connect |
| **Share card generation rate** | Are milestones driving organic growth? | 5-10% of users reaching a milestone | In-app telemetry |
| **Referral conversion rate** | Is word-of-mouth working? | 15-25% of shared links result in install | In-app telemetry + attribution |
| **OAuth revocation rate** | Are users losing trust? | Less than 5% within 30 days | Backend monitoring |

### 30/60/90 Day Targets

**These assume a 2-3 person team with no paid marketing budget for the first 30 days, then $500-1,000/month in paid ads starting month 2.**

**30-Day Targets (Launch + Organic Growth):**

| Metric | Target | Notes |
|---|---|---|
| Total downloads | 2,000-5,000 | Driven by Product Hunt, Reddit, press, and ASO. Highly variable based on virality. |
| Day 1 retention | 40%+ | If below 35%, onboarding is broken. Fix immediately. |
| Day 7 retention | 20%+ | If below 15%, the maintenance loop is failing. |
| App Store rating | 4.5+ stars | Requires proactive review solicitation (prompt after 3rd session, not 1st). |
| Total emails unsubscribed | 50,000-150,000 | At avg. 75 per user on 2K-5K users, minus dropoff. |
| Waitlist conversion rate | 40%+ | Percentage of waitlist signups who install. |
| Press mentions | 3-5 | MacStories, Product Hunt feature, 1-2 smaller blogs. |

**60-Day Targets (Growth + Paid Testing):**

| Metric | Target | Notes |
|---|---|---|
| Total downloads | 8,000-15,000 | Includes initial paid acquisition testing. |
| Day 30 retention (first cohort) | 10%+ | First meaningful retention data. |
| Apple Search Ads CPA | Under $2.00 | If above $3.00, pause and optimize creative/keywords. |
| Revenue (if monetizing) | $2,000-$5,000 MRR | Depends on pricing model. One-time purchase will front-load; subscription will ramp slowly. |
| Referral installs | 10%+ of total installs | Indicates organic growth engine is working. |
| App Store search impressions | 50K+/month | Indicates ASO is gaining traction. |

**90-Day Targets (Scaled Growth):**

| Metric | Target | Notes |
|---|---|---|
| Total downloads | 20,000-40,000 | Assumes at least one paid channel is working efficiently. |
| Monthly active users (MAU) | 5,000-10,000 | |
| Total emails unsubscribed | 1,000,000 | Major marketing milestone: "1 million emails unsubscribed." |
| Revenue (if monetizing) | $5,000-$10,000 MRR | Approaching sustainability for a 2-3 person team. |
| Organic vs. paid split | 60/40 | If paid is over 50%, organic growth engine needs attention. |
| App Store featured | Applied + follow-up sent | Getting featured is not guaranteed, but applying is mandatory. |

### Cohort Analysis Framework

Track user cohorts by install week. For each cohort, measure:

1. **Retention curve:** Day 1, 3, 7, 14, 30, 60, 90 retention. Plot each cohort on the same chart to visualize whether retention is improving over time (it should, as you ship UX improvements).
2. **Value delivery:** Average emails unsubscribed per user in the cohort. Is the first-session experience getting better?
3. **Monetization (if applicable):** Conversion rate to paid within 7 days, 30 days, 90 days per cohort. Which acquisition channels produce the highest-LTV users?
4. **Engagement depth:** Average level reached per cohort. Average achievements unlocked. Are users engaging with gamification or ignoring it?

**Segmentation dimensions:**

- **Acquisition source:** Organic search vs. Product Hunt vs. Reddit vs. paid. This tells you which channels bring engaged users vs. tourists.
- **First session size:** Users who unsubscribed from 50+ emails in session 1 vs. users who unsubscribed from under 10. Hypothesis: larger first sessions correlate with higher retention (more value experienced).
- **Push notification opt-in:** Compare retention of push-enabled vs. push-disabled users. Quantifies the value of push notifications.
- **Platform version:** Track retention by iOS version. iOS 17 minimum requirement should be validated against user distribution data from App Store Connect.

---

## 6. Anti-Stale Roadmap (Marketing Side)

### Monthly Content Calendar Framework

Each month follows a repeating structure. Specific topics rotate, but the format cadence stays consistent.

**Week 1: Data & Insights**
- Publish one data-driven blog post or social thread. Use aggregate (anonymized) user data.
- Examples: "The 10 Companies That Send the Most Subscription Emails," "What Day of the Week Do People Get the Most Junk Email?", "The Average Junkpile User Was Subscribed to 147 Email Lists."
- Format: Blog post + infographic for social + TikTok/Reel with key stat.

**Week 2: Product & Feature**
- Highlight one feature, tip, or use case. Not a changelog; frame around user benefit.
- Examples: "Did You Know You Can Undo a Swipe?", "3 Ways to Use Junkpile Achievements to Stay Motivated," "How to Review New Subscriptions Weekly in Under 2 Minutes."
- Format: Short video tutorial (30-60 seconds) + App Store screenshot update if warranted.

**Week 3: Community & Social Proof**
- Share user stories, testimonials, or milestones.
- Examples: Repost user share cards (with permission), interview a power user, celebrate community milestones ("Junkpile users have collectively unsubscribed from 500K emails").
- Format: Social post + optional blog post for longer stories.

**Week 4: Cultural & Trending**
- Connect Junkpile to broader conversations: productivity culture, digital wellness, privacy news, email trends.
- Examples: React to a news story about data privacy, comment on a trending "inbox zero" discussion, create a meme about email overload.
- Format: Social-first content, timely and reactive.

**Ongoing (2-3x per week):**
- TikTok/Reels showing the swipe mechanic, satisfying cleanup montages, humorous email-related content.
- Twitter/X engagement with the productivity and iOS dev communities.

### Seasonal Campaign Ideas

| Season/Event | Campaign | Content |
|---|---|---|
| **January ("New Year, New Inbox")** | Major push. Position Junkpile as a New Year's resolution tool. | "Start 2027 with a clean inbox. Unsubscribe from everything you don't read." Blog post: "The New Year's Resolution That Takes 5 Minutes." TikTok: resolution-themed cleanup montage. |
| **Tax Season (February-April)** | "Find Your Tax Emails Faster" | "The average inbox has 200 subscription emails for every 1 important tax document. Clean the noise so you can find what matters." Practical angle, timely. |
| **Spring Cleaning (March-April)** | "Spring Clean Your Digital Life" | Partner with other productivity apps for a "digital spring cleaning" bundle or cross-promotion. Blog: "The Complete Digital Spring Cleaning Checklist." |
| **Back to School (August-September)** | "Clean Inbox for a Fresh Start" | Target students and teachers starting new semesters. College students have especially cluttered inboxes from years of signing up for things. TikTok targeting college-age users. |
| **Black Friday / Cyber Monday (November)** | "Unsubscribe BEFORE the Sales Emails Hit" | Timely, practical, and humorous. "Black Friday means 47 sale emails per day. Swipe them away before they arrive." Run this campaign the week before Black Friday. |
| **End of Year (December)** | "Your Inbox Year in Review" | Generate a Spotify-Wrapped-style year-end summary for each user: total unsubscribes, time saved, emails prevented. Designed for sharing. This is the single highest-value content piece of the year. |
| **Data Privacy Day (January 28)** | Trust and transparency content | "On Data Privacy Day, here's exactly what Junkpile does (and doesn't do) with your email data." Full transparency report. |
| **Earth Day (April 22)** | "Reduce Your Digital Carbon Footprint" | Every email stored on a server consumes energy. "Unsubscribing from 100 emails prevents ~28 kg of CO2 per year." (Research and verify this stat; Cleanfox uses a similar angle.) |

### Community Building Tactics

**1. Discord Server (Launch at 5,000 Users)**

- Create a Junkpile Discord with channels:
  - **#achievements** -- Users share achievement unlocks and share cards. Peer recognition drives engagement.
  - **#feature-requests** -- Direct pipeline from users to the dev team. Publicly mark requests as "planned," "shipped," or "considering."
  - **#junk-hall-of-shame** -- Users share the most ridiculous subscription emails they discovered they were signed up for. This is entertainment content that generates organic engagement.
  - **#beta-testing** -- Give Discord members early access to TestFlight builds. Creates a VIP feeling and free QA.
- Moderation: One team member moderates part-time. Set clear rules. Keep it positive and on-topic.

**2. Leaderboard (In-App, Optional)**

- A weekly leaderboard of most emails unsubscribed. Opt-in only (privacy-sensitive users should not feel pressured).
- Anonymized by default (show usernames only if user opts in).
- Resets weekly to keep it accessible for new users.

**3. Power User Program (Launch at 10,000 Users)**

- Identify top 1% of users by engagement (emails unsubscribed, streak length, achievements unlocked).
- Invite them to a private "Junkpile Insiders" group (email list or Discord role).
- Benefits: Early feature access, direct line to the founders, exclusive achievements.
- Obligation: Give honest feedback and share Junkpile organically (no forced posting requirements).

### User-Generated Content Opportunities

**1. Share Cards (Highest Priority UGC Asset)**

- Automatically generated visual cards at milestones (see Milestone-Based Engagement Hooks above).
- Design them to be visually distinctive and instantly recognizable as Junkpile content.
- Include a subtle watermark/logo and app name but do not make it obnoxious. The content should be interesting enough that users want to share it even without being asked.

**2. "My Inbox Stats" Annual Recap**

- End-of-year feature (see Seasonal Campaigns): generate a personalized visual summary of the user's email cleanup journey.
- Total emails unsubscribed, estimated time saved, top subscription categories, level/achievements reached.
- Design multiple card layouts so each user's recap looks slightly different. This prevents the feed from feeling repetitive when multiple users share.

**3. #JunkpileChallenge (TikTok/Reels)**

- Launch a challenge: "Show your inbox before and after Junkpile. Use #JunkpileChallenge."
- Provide a template: screen-record opening the app, showing the number of subscriptions found, speed-swiping through them, then showing the final stats.
- Incentivize: "Best #JunkpileChallenge video this month gets featured on our page + 1,000 bonus XP."

**4. Testimonials and Reviews**

- After a user hits 50 unsubscribes, prompt: "Enjoying Junkpile? A quick App Store review helps us reach more people." Do not prompt before meaningful value is delivered.
- Screenshot and share positive App Store reviews on social (with context, not just the quote). Example: "'I didn't realize I was subscribed to 200 newsletters. Junkpile fixed it in 10 minutes.' -- 5-star review from Sarah K."

**5. "Worst Subscription" Contest**

- Monthly social media contest: share the most absurd email subscription you found you were signed up for.
- Users screenshot the sender/subject from within Junkpile (no email content visible, maintaining privacy norms).
- Prize: Featured on Junkpile's social + exclusive in-app badge ("Junk Finder").

---

## Appendix: Budget Summary

| Item | Monthly Cost | Notes |
|---|---|---|
| Apple Search Ads | $600-$1,500 | Scale based on CPA performance |
| TikTok Ads (testing) | $300-$900 | Only if organic TikTok shows promise |
| Domain + hosting | $20 | Static landing page |
| Email (waitlist + re-engagement) | $0-$50 | Free tier of Resend, Loops, or similar |
| Design tools | $15-$30 | Figma free tier or Canva Pro for social assets |
| Micro-influencer gifting | $0 | Lifetime app access, no cash required pre-scale |
| **Total (Month 1)** | **$35-$100** | Organic only |
| **Total (Month 2-3)** | **$935-$2,480** | Adding paid channels |

---

## Appendix: Key Decisions Needed Before Launch

1. **Pricing model.** Freemium with one-time purchase, annual subscription, or usage-limited free tier? This affects every growth channel and retention strategy. Decide and test in beta.
2. **Analytics infrastructure.** You need basic telemetry (retention, session length, feature usage) without violating your privacy-first positioning. Consider TelemetryDeck (privacy-focused, indie-friendly) or build minimal in-house analytics with SwiftData + your backend API.
3. **Multi-platform timeline.** Gmail-only is the right launch scope, but users will immediately ask for Outlook, Yahoo, and iCloud Mail support. Have a public answer ready, even if it is "Gmail first, more providers coming based on demand."
4. **Android timeline.** Every press mention will generate "When is this coming to Android?" comments. Have a stock answer: "We're focused on making the iOS experience great first. Android is on the roadmap." Do not commit to a date.

---

*This document should be revisited and updated monthly as real user data replaces assumptions.*
