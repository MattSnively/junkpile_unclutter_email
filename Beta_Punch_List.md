** Junkpile BETA Known bugs and issues **

1. Profile message "Welcome Back" even on first visit
2. For users that don't connect email ("skip for now" option) is there a demo? what would they do?
3. ~~on "what we access" page, align icons to first line of text every time. currently center-aligned, causing mismatched spacing for entries with multiple lines of text~~ **FIXED (Build 6)** — Icon alignment set to `.top` with baseline padding
4. ~~"Connect Gmail" button text not centered~~ **FIXED (Build 6)** — Icon increased to 24×24, spacing to 12, explicit `.center` alignment
5. ~~Spacing on sign-in page needs work. there's a hidden "OR" option between Apple and Google login. Do we need both? Why login with Apple if Gmail is the only mailbox option right now.~~ **FIXED (Build 6)** — Added captions under each button explaining the two paths, emphasized Apple as primary, bolded "or" divider
6. On "Simple as Swipe" landing page, instead of Get Started button can we implement a "swipe right to start" option? Also would be a good place to include an animation previewing the functionality of the app
7. How much effort is this to add more than Gmail? Might be a full-pass project, not a punch list item.
8. How are we grabbing the list of emails to swipe through? I am getting many duplicates across sessions. would like to eliminate that.
9. Formatting of email previews is still terrible. the "From" and "Subject" lines are good, but the preview of the email body is full of CSS and looks unpolished. This is a high-priority fix as the app will not gain adoption without a better solution.
10.Currently, statistics are not persisting through sessions. I have swiped 99 emails this week but the decision ratio, lifetime stats, and recent sessions info do not match up.
11. ~~Dark/Light mode--how is this chosen? there's no option to switch, is it based on system settings? Let's add a user toggle in Settings~~ **FIXED (Build 6)** — Added Appearance section in Settings with System/Light/Dark segmented picker, applied to root view
12. Privacy Policy and ToS both link out to external sites. is that a requirement? Would be nice to house that text in-app.
13. ~~"Your Data" and "Disclaimer" both required multiple taps to access. looks like a glitch on first touch.~~ **FIXED (Build 6)** — Replaced `.onTapGesture` with `Button` to eliminate List gesture conflict (Disclaimer was already fixed)
14. Add Achievements access in Stats section for all earned badges, badge glossery so users know what they are "playing" for besides cleaning their inbox.
15. Junkpile PRO idea: is there a way for us to track "unsubscribed" emails and then see which companies are not unsubscribing? E.G. I unsubscribe from Nike, but then in a session the next week I have more emails from Nike. can we place an alert on screen like a "you've previously attempted to unsubscribe from this company?"
16. I think we need to adjust the number of emails in a "Sesssion" to 20. also, can we call it something besides "session?" I don't love that name.
17. ~~The spacing on Lifetime Stats "emails processed" is gross. we have to fit that on two lines, and processed sounds so formal. Maybe "emails swiped"~~ **FIXED (Build 6)** — Renamed to "Emails Swiped", added `.lineLimit(1)` + `.minimumScaleFactor(0.7)`
18. ~~The spacing on Lifetime Stats "unsubscribed" is also bad. Needs to fit on one line.~~ **FIXED (Build 6)** — Reduced icon frame from 40→32px, labels now fit on one line
19. ~~the animation for swiping is good but could be better. Right now the tag "keep" appears in the top right corner but gets lost almost immediately as the card is swiped right. Let's move the "keep" and "unsub" tag to above the email and add an animated element to it.~~ **FIXED (Build 6)** — Floating colored capsule pill above the card with spring scale animation
20. ~~We also don't have any animation indicating how many points were earned each swipe--that needs to be clear to the user instead of springing a score on them at the end of a session, which might lead to confusion.~~ **FIXED (Build 6)** — "+X pts" float-up animation after each swipe (10 pts unsub, 5 pts keep), respects Reduce Motion
21. "Ready to clean your inbox" button on home screen NEEDS to take you to a new session. Currently no functionality, just wasted space.
