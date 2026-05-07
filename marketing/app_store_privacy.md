# App Store Connect — Privacy "Nutrition Label" worksheet

> **Draft — review with counsel before publication.** This worksheet is a
> first pass at the answers you'll enter into App Store Connect → App
> Privacy. It reflects LoadOut's current behavior (local-first storage,
> opt-in Crashlytics, no analytics, no advertising) but the legal
> categorization (especially around "linked vs not linked to user" and
> "tracking") is a judgment call that should be confirmed by counsel
> before submission.

App: **LoadOut: Precision Reloading** (`com.johnsondigital.loadout`)
Effective date of this version: **2026-05-07**
Owner of record: **Johnson Digital Systems**

---

## 1. Summary

| Question | Answer |
|---|---|
| Does the app collect data from this app? | **Yes** (only the categories listed below). |
| Is data used for tracking, as defined by Apple? | **No.** LoadOut does not use any data to track the user across apps or websites owned by other companies, and does not share any data with data brokers. |
| Are any of the data types collected linked to the user's identity? | **Yes** — Email Address (for sign-in) and User ID (Firebase UID, RevenueCat App User ID) are linked to the user. Diagnostics are linked to the User ID when the user opts in. |
| Is any third-party SDK collecting data? | Yes: Firebase Authentication, Firebase Crashlytics (opt-in only), Firebase Storage (read-only catalog updates), RevenueCat. |

---

## 2. Data types collected

For each row: "Linked to You" means the data type is tied to the user's
identity (email, Firebase UID, RevenueCat App User ID, or device
identifier). "Used for Tracking" means cross-app/cross-site tracking as
Apple defines it (which we do not do).

| Apple data type | Collected? | Linked to user? | Used for tracking? | Purpose | Notes |
|---|---|---|---|---|---|
| **Contact Info → Email Address** | Yes | Linked | No | App Functionality, Account Management | Used for sign-in via Firebase Authentication. Not used for marketing. |
| **Contact Info → Name** | If user uses Apple/Google/Microsoft/Yahoo SSO | Linked | No | App Functionality | Display name comes back from the OAuth provider; we don't ask the user to type a name separately. |
| **Contact Info → Phone Number, Physical Address, Other User Contact Info** | No | — | — | — | Not collected. |
| **Health & Fitness** | No | — | — | — | Not collected. |
| **Financial Info → Payment Info** | No | — | — | — | Apple processes the in-app purchase. We never see card numbers. |
| **Financial Info → Credit Info, Other Financial Info** | No | — | — | — | Not collected. |
| **Location → Precise Location** | Yes (on-demand only) | Not Linked | No | App Functionality | Used only when the user taps "Get current weather" inside the app. Coordinates are sent to the weather provider for that single request. We do not store the coordinates and they are not associated with the user record. |
| **Location → Coarse Location** | No | — | — | — | We use precise (when in use) when needed, otherwise nothing. |
| **Sensitive Info** | No | — | — | — | Not collected. |
| **Contacts** | No | — | — | — | Not collected. |
| **User Content → Photos or Videos** | No | — | — | — | The photo-import feature reads images on-device only. We do not transmit or store images. |
| **User Content → Audio Data** | No | — | — | — | Not collected. The app does not request microphone access. |
| **User Content → Gameplay Content, Customer Support, Other User Content** | No | — | — | — | Not collected. Email support replies are processed in our support inbox separately and are not "User Content" for the purposes of this label. |
| **Browsing History** | No | — | — | — | Not collected. |
| **Search History** | No | — | — | — | Not collected. |
| **Identifiers → User ID** | Yes | Linked | No | App Functionality, Account Management | Firebase UID for the auth record; RevenueCat App User ID for purchase entitlement. We mirror the Firebase UID into RevenueCat so a Pro purchase follows the user across devices. |
| **Identifiers → Device ID** | No (we don't collect IDFA, IDFV, or advertising IDs) | — | — | — | RevenueCat handles its own device identifiers internally for receipt validation; we do not access advertising identifiers (no IDFA/ATT prompt). |
| **Purchases → Purchase History** | Yes | Linked | No | App Functionality | RevenueCat receives the App Store transaction record (product ID, purchase date, expiration). |
| **Usage Data → Product Interaction, Advertising Data, Other Usage Data** | No | — | — | — | We do not collect analytics, screen views, ad interactions, or session times. |
| **Diagnostics → Crash Data, Performance Data** | Yes (opt-in only) | Linked (when opted in) | No | App Functionality | Firebase Crashlytics. Off by default. The user opts in via Settings → Send crash reports. Reports contain stack traces, device/OS metadata, and the Firebase UID; they do not contain user reloading data or typed text. |
| **Diagnostics → Other Diagnostic Data** | No | — | — | — | Not collected. |
| **Surroundings, Body, Other Data** | No | — | — | — | Not collected. |

---

## 3. Per-data-type purpose mapping

App Store Connect asks you to attach one or more "purposes" to each data
type. Use only **App Functionality** (and **Account Management** where
the field requires it). Do not select Analytics, Product Personalization,
App Functionality + Analytics combinations, Developer's Advertising or
Marketing, or Third-Party Advertising.

- Email Address → **App Functionality**, **Account Management**
- Name → **App Functionality**
- Precise Location → **App Functionality**
- User ID → **App Functionality**, **Account Management**
- Purchase History → **App Functionality**
- Crash Data → **App Functionality**
- Performance Data → **App Functionality**

---

## 4. Tracking question

> "Does this app use data for tracking purposes?"

**Answer: No.** Apple defines tracking as linking data collected from
this app with data from third parties for targeted advertising or
measurement, or sharing data with a data broker. LoadOut does not do
either.

Because we answer No, we do **not** require an `App Tracking
Transparency` (ATT) prompt and we should not include
`NSUserTrackingUsageDescription` in `Info.plist`.

---

## 5. Third-party SDKs and what they receive

| SDK / service | What it sees | Apple privacy disclosure |
|---|---|---|
| Firebase Authentication | Email, password hash (email/password sign-in only), OAuth tokens, Firebase UID, sign-in metadata. | Listed under Contact Info → Email Address and Identifiers → User ID. |
| Firebase Crashlytics (opt-in) | Stack traces, device/OS metadata, Firebase UID, app version, breadcrumbs the SDK collects automatically. | Listed under Diagnostics. |
| Firebase Storage (read-only catalog updates) | Anonymous request to a public catalog blob; no user data attached. | No data type collected on our side; we don't disclose this on the label. |
| RevenueCat | Firebase UID (mirrored as App User ID), App Store transaction record, anonymous device/platform metadata. | Listed under Identifiers → User ID and Purchases → Purchase History. |
| Apple App Store | Payment processing for the in-app purchase. We do not see card data. | Apple's own disclosure covers this; no entry on our label. |

---

## 6. Items the App Review reviewer will likely probe

Anticipate questions like:

- **Why does the app ask for camera access?** To photograph handwritten
  reloading notes for on-device parsing. The image and parsed text
  never leave the device. The purpose string in `Info.plist` is "Use
  your camera to scan handwritten reloading notes into LoadOut."
- **Why does the app ask for photo library access?** To pick an existing
  photo of reloading notes to import. The purpose string is "Access
  photos to import scanned reloading notes."
- **Why does the app ask for location?** To fetch local weather (temp,
  pressure, humidity, wind) for ballistics calculations. Only when the
  user taps "Get current weather". The purpose string is "LoadOut uses
  your location to pull current weather (temperature, pressure,
  humidity, wind) for ballistics calculations."
- **Why does the app ask for Bluetooth?** To pair with a chronograph
  (Garmin Xero) or weather meter (Kestrel). The purpose string is
  "LoadOut connects to your Bluetooth chronograph (Garmin Xero) and
  weather meter (Kestrel) to import shot velocity and weather data."
- **What encryption do you export?** No proprietary cryptography.
  Standard TLS to Firebase. Cloud backups (Pro) are encrypted on-device
  with a passphrase using authenticated encryption from a published
  symmetric algorithm (AES-GCM with PBKDF2 / Argon2 key derivation —
  confirm the exact algorithm before claiming exemption under EAR
  742.15(b)(4) when filing the annual self-classification report).
- **Does the app contain a sign-in option?** Yes; Sign in with Apple is
  offered alongside Google, Microsoft, Yahoo, email/password, email
  link, and anonymous. This satisfies App Store Review Guideline
  4.8.

---

## 7. Privacy Policy URL

To enter in App Store Connect → App Information → Privacy Policy URL:

```
https://loadout-precision-reloading.web.app/legal/privacy.html
```

(Set this only after the operator has reviewed and approved the
hosted document.)

---

## 8. Open items for legal review

- Confirm the "linked vs not linked" classification of Precise
  Location is correct given that we send coordinates to a weather
  provider for a single request and do not retain them server-side.
  Apple's guidance treats one-off location lookups conservatively;
  some legal reviewers will want this listed as Linked out of
  caution.
- Confirm the categorization of Crashlytics breadcrumbs — Crashlytics
  records some lifecycle events automatically. We do not log custom
  user-typed content, but a thorough reviewer may want to enumerate
  the default breadcrumb set to be sure.
- Confirm that we do not need to file an annual encryption
  self-classification report (ERN) before launch, given we use
  off-the-shelf cryptography for cloud backup. The standard
  exemption under EAR 742.15(b)(4) is the most likely fit; counsel
  should confirm.
- Confirm whether the operator wants to declare Precise Location as
  "Optional" (the app works without it) and document that the
  feature is degraded but not blocked when location is denied.
