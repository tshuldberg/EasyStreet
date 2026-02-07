# Non-Technical Team Tasks: App Store Launch & SF Market Entry

## Context

EasyStreet is a functional iOS MVP (21,809 SF street segments, parking alerts, color-coded map) approaching App Store submission. The engineering work is covered by existing plans (`production-readiness.md`, `app-store-launch.md`). This document identifies **everything non-developers can own** to support a successful launch in San Francisco.

The app is privacy-first (no analytics, no servers, all data on-device), free, and targets SF residents who park on streets with sweeping schedules.

---

## Category 1: App Store Setup (REQUIRED before submission)

### 1.1 Enroll in Apple Developer Program
- Go to https://developer.apple.com/programs/enroll/
- Cost: $99/year (individual) or $299/year (organization)
- **Decision needed:** Individual vs. Organization account
  - Individual: faster (24-48 hrs), simpler, shows personal name as seller
  - Organization: requires D-U-N-S number (can take 1-2 weeks), shows company name
- Have a credit card and Apple ID ready
- After approval, share the Apple ID credentials with the dev team

### 1.2 Register App ID & Bundle Identifier
- In App Store Connect, register bundle ID: `com.easystreet.app`
- Enable capabilities: Push Notifications, Maps
- This is a point-and-click task in the Apple Developer portal

### 1.3 Create App Store Connect Listing
- Log into https://appstoreconnect.apple.com
- Create new app with:
  - **Name:** EasyStreet
  - **Primary Language:** English (U.S.)
  - **Bundle ID:** com.easystreet.app
  - **SKU:** easystreet-ios-v1
  - **Primary Category:** Navigation
  - **Secondary Category:** Travel

### 1.4 Fill in App Store Metadata
All of this is typed into App Store Connect fields:

| Field | Value |
|-------|-------|
| **Subtitle** (30 chars) | Street Sweeping Parking Alerts |
| **Promotional Text** (170 chars) | Never get a street sweeping ticket again. See color-coded sweeping schedules on a map, mark where you parked, and get alerts before the sweeper arrives. |
| **Keywords** (100 chars) | street sweeping,parking,san francisco,ticket,sf parking,street cleaning,tow,move car |
| **Support URL** | TBD (see Task 2.3) |
| **Privacy Policy URL** | TBD (see Task 2.1) |
| **Age Rating** | 4+ (no objectionable content) |
| **Price** | Free |
| **Copyright** | 2026 EasyStreet |

**App Description** (paste into App Store Connect):
> Never get a parking ticket from street sweeping again.
>
> EasyStreet shows San Francisco's complete street sweeping schedule on an interactive, color-coded map. Red means sweeping today, orange means tomorrow, yellow means soon, and green means you're safe. Mark where you parked and get a notification before the sweeper arrives.
>
> Features:
> - Color-coded map of all 21,000+ SF street segments
> - "I Parked Here" with GPS location capture
> - Push notifications before sweeping starts
> - Adjustable notification timing (15 min to 2 hours)
> - Drag-to-adjust parking pin
> - Tap any street to see its sweeping schedule
> - Works completely offline - no account required
> - 100% private - no data leaves your device
>
> Data sourced from the City of San Francisco's official street sweeping schedule.

### 1.5 Configure Privacy Declarations in App Store Connect
Under "App Privacy" in App Store Connect, declare:
- **Data Types Collected:** Location (Precise Location)
- **Usage:** App Functionality
- **Linked to User:** No
- **Used for Tracking:** No
- All other categories: "Not collected"

### 1.6 Prepare App Review Notes
Type into the "Notes for Reviewer" field:
> EasyStreet displays San Francisco street sweeping schedules on a map. To test: open the app, allow location access, and you'll see color-coded streets. Tap "I Parked Here" to mark a parking spot. Tap any street to see its schedule. The app works offline with bundled data from SF Open Data (data.sfgov.org). No account or login is required.

---

## Category 2: Legal & Compliance

### 2.1 Host Privacy Policy as a Web Page
The privacy policy is already written (see `docs/privacy-policy.md`). It needs to be accessible at a public URL for App Store Connect.

**Option A — GitHub Pages (free, easiest):**
1. In the GitHub repo, go to Settings > Pages
2. Set source to "main" branch, `/docs` folder
3. Privacy policy will be at: `https://<username>.github.io/EasyStreet/privacy-policy`

**Option B — Simple website (Carrd, Notion, Google Sites):**
1. Copy the content from `docs/privacy-policy.md`
2. Paste into a free website builder
3. Publish and copy the URL

Once hosted, paste the URL into App Store Connect's "Privacy Policy URL" field.

### 2.2 Set Up Support Email
- The email `easystreet.app@gmail.com` is already referenced in the privacy policy
- Ensure this inbox is monitored (set up forwarding if needed)
- Create a simple auto-reply: "Thanks for contacting EasyStreet. We'll get back to you within 48 hours."

### 2.3 Create a Simple Support/Landing Page
Needed for the App Store "Support URL" field. Can be a single page with:
- App description (1 paragraph)
- FAQ (see Category 5 below)
- Contact email
- Link to privacy policy
- Host on GitHub Pages, Carrd, or similar

---

## Category 3: Visual Assets

### 3.1 Design App Icon (1024x1024 PNG)
This is the most visible creative asset. Requirements:
- 1024x1024 pixels, PNG format, no transparency, no rounded corners (Apple adds those)
- Must be recognizable at small sizes (29x29 on Settings screen)
- No text in the icon (Apple guideline)

**Design direction suggestions:**
- A simplified street/road with a broom or sweeper silhouette
- A parking pin with a green checkmark or shield
- A minimalist map segment with color coding
- Color palette: greens (safe/trust), with red/orange accent

**Tools for non-designers:** Canva (free), Figma (free), or hire on Fiverr ($20-50)

After the 1024x1024 master is created, give it to the dev team — they'll generate all required sizes.

### 3.2 Capture App Store Screenshots
Apple requires screenshots for at least one device size. Recommended: capture for 6.7" (iPhone 15 Pro Max) and 6.5" (iPhone 14 Plus).

**Screenshots to capture (6-8 images):**
1. **Map overview** — Full SF map with color-coded streets visible
2. **Zoomed in** — Close-up showing red/orange/yellow/green streets clearly
3. **"I Parked Here"** — Map with parking pin dropped and parking card visible
4. **Street detail** — Bottom sheet showing a street's sweeping schedule
5. **Notification preview** — A sweeping alert notification on lock screen
6. **Search** — Address search in action
7. **Legend** — Map legend showing what colors mean (could combine with #1)

**How to capture:**
- Run the app in Xcode Simulator (dev team can help set this up)
- Use Cmd+S in Simulator to save screenshots
- Or: dev team can generate screenshots and hand them off for annotation

### 3.3 Add Text Overlays to Screenshots (Optional but recommended)
Add brief captions to each screenshot:
- "See every sweeping schedule at a glance"
- "Never miss a street sweeper again"
- "Mark your spot, get an alert"
- "Tap any street for details"
- "100% offline, 100% private"

**Tools:** Canva, Figma, or Apple's Keynote (free templates exist for App Store frames)

### 3.4 Create a Simple App Preview Video (Optional)
- 15-30 second screen recording showing: open app > see colored map > tap street > see schedule > park here > get notification
- Can be recorded in Simulator or on a real device
- Not required for launch but improves conversion

---

## Category 4: Beta Testing (TestFlight)

### 4.1 Recruit 5-10 Beta Testers
Ideal testers are SF residents who:
- Park on streets with sweeping schedules
- Own an iPhone (iOS 14+)
- Are willing to give honest feedback

**Where to find testers:**
- Friends/family in SF
- Nextdoor SF neighborhoods
- SF parking-related Reddit threads
- Local SF Facebook groups
- Co-workers who commute to SF

### 4.2 Create a Beta Testing Guide
Write a simple doc (Google Doc or email) for testers:

> **How to test EasyStreet:**
> 1. You'll receive a TestFlight invitation email — tap "View in TestFlight" to install
> 2. Open EasyStreet and allow location access
> 3. Browse the map — streets should be color-coded
> 4. Tap a street to see its sweeping schedule
> 5. Tap "I Parked Here" to mark your parking spot
> 6. Check if you receive a notification before the next sweeping time
>
> **Things to look for:**
> - Is your street's schedule accurate? (Compare with posted signs)
> - Do colors make sense? (Red = today, orange = tomorrow, etc.)
> - Does the notification arrive at the right time?
> - Anything confusing or broken?
>
> **How to report issues:**
> - Tap the share button in TestFlight to submit feedback
> - Or email easystreet.app@gmail.com with a screenshot

### 4.3 Collect and Organize Feedback
- Create a simple spreadsheet with columns: Tester Name, Date, Issue/Feedback, Severity (Critical/Nice-to-have), Status
- Share with the dev team weekly
- Prioritize: data accuracy issues > crashes > UX confusion > feature requests

### 4.4 Verify Data Accuracy with Real-World Signs
This is the single most valuable thing non-technical people can do:
- Walk/drive SF neighborhoods and photograph street sweeping signs
- Compare posted schedules with what EasyStreet shows for that street
- Focus on: your home neighborhood, downtown, Mission, Sunset, Richmond, Marina
- Log any discrepancies: street name, what sign says, what app says
- **Data source is from May 2025** — some schedules may have changed since then

---

## Category 5: Support & Content

### 5.1 Write an FAQ
Draft answers for common questions:

| Question | Answer |
|----------|--------|
| Is EasyStreet free? | Yes, completely free with no ads or in-app purchases. |
| Does it work outside San Francisco? | Not yet — currently SF only. More cities coming soon. |
| How accurate is the data? | We use the official City of SF street sweeping schedule. Schedules can occasionally change — always check posted signs. |
| Does EasyStreet track my location? | No. Your location is stored only on your device and never sent anywhere. |
| Why didn't I get a notification? | Make sure notifications are enabled in Settings > EasyStreet. Also check that you marked your parking spot with "I Parked Here." |
| When is sweeping suspended? | San Francisco suspends sweeping on 11 official city holidays. The app accounts for this automatically. |
| Can I adjust notification timing? | Yes — tap the gear icon to choose 15 min, 30 min, 1 hour, or 2 hours before sweeping. |
| The schedule for my street seems wrong | Please email us at easystreet.app@gmail.com with the street name and what your posted sign says. We'll investigate. |

### 5.2 Write a "What's New" for v1.0
Keep it simple:
> Initial release. See San Francisco's complete street sweeping schedule on a color-coded map, mark where you parked, and get alerts before the sweeper arrives.

---

## Category 6: Marketing & Launch

### 6.1 Write a Launch Announcement
Draft a short announcement (3-4 paragraphs) for social media, email, etc.:
- What EasyStreet does (1 sentence)
- Why it matters (SF parking tickets are $79+)
- Key features (color map, alerts, privacy)
- Call to action (download link)

### 6.2 Social Media Presence
- Create accounts on Instagram and/or Twitter/X with handle `@easystreetapp` (or similar)
- Post 3-5 pre-launch teasers:
  - "Coming soon: never get a sweeping ticket again"
  - Screenshot of the color-coded map
  - "Did you know SF has 21,000+ street segments with sweeping schedules?"
  - "How much have you paid in parking tickets this year?"
- Post the launch announcement on day 1

### 6.3 Local SF Community Outreach
Post the launch announcement (with App Store link) in:
- [ ] r/sanfrancisco (Reddit)
- [ ] r/bayarea (Reddit)
- [ ] SF-specific Nextdoor groups
- [ ] SF Facebook groups (SF Residents, San Francisco Living, etc.)
- [ ] Hacker News (Show HN: I built an app to avoid SF parking tickets)
- [ ] Product Hunt (optional, but good for visibility)

**Tone:** Authentic, helpful, not salesy. Lead with the problem ("I kept getting $79 tickets...") not the product.

### 6.4 Reach Out to Local Media/Blogs (Optional)
Brief pitch email to:
- SFist, SF Chronicle, KQED
- Local neighborhood blogs (Mission Local, Richmond Review, Sunset Beacon)
- SF-focused tech blogs

**Pitch angle:** "New free app maps every street sweeping schedule in SF — could save residents hundreds in tickets"

### 6.5 Track App Store Reviews
- After launch, check App Store Connect daily for new reviews
- Respond to negative reviews within 24 hours (politely, offering to help)
- Flag data accuracy complaints for the dev team
- Screenshot and share positive reviews on social media

---

## Category 7: Launch Day Checklist

On the day the app goes live on the App Store:

- [ ] Verify the app downloads and opens correctly from the App Store
- [ ] Test the full flow: open > allow location > see map > park > get alert
- [ ] Post launch announcement on all social channels (Category 6.3)
- [ ] Send launch email to beta testers thanking them
- [ ] Monitor App Store Connect for crash reports (first 24 hours)
- [ ] Monitor support email for user issues
- [ ] Respond to any App Store reviews within 24 hours

---

## Priority & Sequencing

### Before Development Finishes (start now)
1. **1.1** Apple Developer enrollment (can take days)
2. **3.1** App icon design (creative work, takes time)
3. **4.1** Recruit beta testers
4. **5.1** Write FAQ
5. **6.1-6.2** Draft launch copy and set up social accounts

### After Dev Hands Off a TestFlight Build
6. **4.2-4.3** Run beta test, collect feedback
7. **4.4** Verify data accuracy against real signs
8. **3.2-3.3** Capture and annotate screenshots

### During App Store Submission
9. **2.1** Host privacy policy
10. **2.3** Create support page
11. **1.3-1.6** Fill in all App Store Connect fields
12. **3.2** Upload screenshots

### Launch Day
13. **6.3-6.4** Community outreach and media pitches
14. **7** Full launch day checklist
15. **6.5** Begin monitoring reviews

---

## Summary

There are **~25 discrete tasks** across 7 categories that non-technical team members can own. The highest-impact items are:

1. **Apple Developer enrollment** (blocks everything)
2. **App icon design** (blocks submission)
3. **Data accuracy verification** (walking SF neighborhoods — uniquely valuable, can't be automated)
4. **Beta tester recruitment** (real user feedback before launch)
5. **Community outreach on launch day** (drives initial downloads)
