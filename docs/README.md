# Junkpile Legal Documents - Web Hosting

This directory contains the Privacy Policy and Terms of Service for the Junkpile mobile app.

## Files

- `privacy.html` - Privacy Policy (publicly accessible)
- `terms.html` - Terms of Service (publicly accessible)

## Hosting Instructions

### Option 1: GitHub Pages (Free, Recommended)

1. **Create a new repository** (or use this one) on GitHub
2. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Source: Deploy from a branch
   - Branch: `main`, Folder: `/web`
   - Save

3. **Your URLs will be:**
   - Privacy: `https://[username].github.io/[repo-name]/privacy.html`
   - Terms: `https://[username].github.io/[repo-name]/terms.html`

4. **Update the iOS app** with your actual URLs in `SettingsView.swift`:
   ```swift
   // Line 331
   if let privacyURL = URL(string: "https://[your-actual-url]/privacy.html") {

   // Line 347 (after edit)
   if let termsURL = URL(string: "https://[your-actual-url]/terms.html") {
   ```

5. **Update App Store Connect:**
   - Log in to App Store Connect
   - Go to your app → App Information
   - Add your Privacy Policy URL in the required field
   - Add your Support URL (can be the same or a different page)

### Option 2: Custom Domain

If you own `junkpile.app`:

1. Upload `privacy.html` and `terms.html` to your web host
2. Access them at:
   - `https://junkpile.app/privacy.html` (or `/privacy`)
   - `https://junkpile.app/terms.html` (or `/terms`)

3. The iOS app already references these URLs (just change from `.html` to no extension if your server supports it)

### Option 3: Simple Static Hosting Services

**Netlify (Free):**
1. Sign up at https://netlify.com
2. Drag and drop this `web` folder
3. Get instant URLs like `https://junkpile-legal.netlify.app/privacy.html`

**Vercel (Free):**
1. Sign up at https://vercel.com
2. Connect your GitHub repo
3. Deploy the `/web` directory

## Important: Update These Placeholders

Before publishing, update these placeholder values in both HTML files:

### In `privacy.html` and `PRIVACY_POLICY.md`:
- `[Your server location]` (line about international data transfers)
- `[Your website URL]` (contact section)
- `[Your mailing address]` (contact section, if required by jurisdiction)

### In `terms.html` and `TERMS_OF_SERVICE.md`:
- `[Your State/Country]` (governing law section)
- `[Your Jurisdiction]` (dispute resolution section)
- `[Your website URL]` (contact section)
- `[Your mailing address]` (contact section, if required by jurisdiction)

## Updating the Documents

When you update the legal documents:

1. Update the markdown files (`PRIVACY_POLICY.md` and `TERMS_OF_SERVICE.md`)
2. Update the HTML files (`web/privacy.html` and `web/terms.html`)
3. Update the "Last Updated" date in all files
4. **Notify users** via in-app notification if changes are material
5. Re-deploy to your hosting service

## Support Email

The documents reference `support@junkpile.app`. Make sure this email:
- Actually exists and is monitored
- Is listed in App Store Connect as your support email
- Auto-responds or has someone checking it regularly

## Legal Disclaimer

**I am not a lawyer.** These documents are templates based on common app store requirements and privacy best practices. You should:

1. **Consult a lawyer** before publishing, especially if:
   - You operate in the EU (GDPR compliance)
   - You operate in California (CCPA compliance)
   - You collect data from children
   - You plan to monetize or sell data

2. **Customize** the documents to match your actual practices
3. **Keep them updated** as your app evolves
4. **Archive old versions** in case of disputes

## Questions?

If you're unsure about any legal requirements:
- **US-based:** Consult a tech/startup lawyer (many offer free consultations)
- **EU-based:** Ensure GDPR compliance (consider using Iubenda or Termly generators)
- **App Store rejections:** Apple often provides specific guidance on what's missing

## Next Steps

After hosting these documents:

1. ✅ Update `SettingsView.swift` with actual URLs
2. ✅ Test the links in the iOS app
3. ✅ Add Privacy Policy URL to App Store Connect
4. ✅ Add Support URL to App Store Connect
5. ✅ Fill out the Privacy Nutrition Label in App Store Connect (data collection questionnaire)
6. ✅ Submit for App Review

Good luck with your launch! 🚀
