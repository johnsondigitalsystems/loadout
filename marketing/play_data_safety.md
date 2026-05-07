# Google Play Console — Data Safety form worksheet

> **Draft — review with counsel before publication.** This worksheet is a
> first pass at the answers you'll enter into Play Console → App content
> → Data safety. It reflects LoadOut's current behavior. The legal
> categorization (especially "shared" vs "collected" and the encryption
> claims) is a judgment call that should be confirmed by counsel before
> submission.

App: **LoadOut: Precision Reloading** (`com.johnsondigital.loadout`)
Effective date of this version: **2026-05-07**
Owner of record: **Johnson Digital Systems**

---

## 1. Top-level answers

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes**, the categories listed in section 3 below. |
| Is all of the user data collected by your app encrypted in transit? | **Yes.** All data sent to Firebase Authentication, Firebase Crashlytics (when opted in), Firebase Storage, and RevenueCat travels over TLS. |
| Do you provide a way for users to request that their data be deleted? | **Yes.** In-app: Settings → Delete my data wipes all on-device reloading data. Account deletion: <support@johnsondigital.com> removes the Firebase Auth record and the linked RevenueCat entitlement. |

Google Play also requires a publicly accessible **account deletion URL**.
We will publish an account-deletion request page at
`https://loadout-precision-reloading.web.app/legal/account-deletion.html`
(or use a mailto: with `support@johnsondigital.com` if the lighter
weight option is acceptable). Confirm Play Store policy with counsel
before launch.

---

## 2. Definitions

- **Collected** = transmitted off the user's device.
- **Shared** = transferred to a third party we don't operate.

Play distinguishes between these two. For most LoadOut data the answer
is "collected (by us, sent to a service provider acting on our behalf)
but not shared with an independent third party". Service providers like
Firebase and RevenueCat acting under contract for us are not
"third-party data sharing" under Play's definition, but the form does
require us to disclose that the data is collected.

---

## 3. Data types collected

| Play data type | Collected? | Shared? | Required or Optional | Purpose | Notes |
|---|---|---|---|---|---|
| **Personal info → Name** | Yes (when user uses Apple/Google/Microsoft/Yahoo SSO) | No | Optional | Account management, App functionality | Returned by the OAuth provider. |
| **Personal info → Email address** | Yes | No | Optional | Account management, App functionality | Required only if the user chooses to sign in (anonymous and "skip sign-in" flows do not collect email). |
| **Personal info → User IDs** | Yes | No | Optional | Account management, App functionality | Firebase UID and RevenueCat App User ID. |
| **Personal info → Address, Phone number, Race/ethnicity, Political/religious/sexual orientation, Other info** | No | — | — | — | Not collected. |
| **Financial info → User payment info, Purchase history, Credit info, Other financial info** | Purchase history: Yes (RevenueCat) | No | Required if user buys Pro | App functionality | RevenueCat receives the Play transaction record (product ID, purchase date, expiration). We do not see card numbers — Google handles payment. |
| **Health and fitness** | No | — | — | — | Not collected. |
| **Messages** | No | — | — | — | Not collected. |
| **Photos and videos** | No | — | — | — | The photo-import feature reads images on-device only. Images and parsed text never leave the device. |
| **Audio files → Voice or sound recordings, Music files, Other audio files** | No | — | — | — | The app does not request microphone access. |
| **Files and docs** | No | — | — | — | Not collected. (Local export writes JSON to the user's own device storage; we don't transmit it.) |
| **Calendar** | No | — | — | — | Not collected. |
| **Contacts** | No | — | — | — | Not collected. |
| **Location → Approximate location** | No | — | — | — | Not collected. |
| **Location → Precise location** | Yes (on-demand only) | No | Optional | App functionality | Used only when the user taps "Get current weather" inside the app. Coordinates are sent to the weather provider for that single request. We do not retain them. |
| **Web browsing** | No | — | — | — | Not collected. |
| **App activity → App interactions, In-app search history, Installed apps, Other user-generated content, Other actions** | No | — | — | — | We do not run analytics. |
| **App info and performance → Crash logs** | Yes (opt-in only) | No | Optional | App functionality | Firebase Crashlytics. Off by default; user opts in via Settings → Send crash reports. Reports include stack traces, device/OS metadata, the Firebase UID. They do not include reloading data or user-typed text. |
| **App info and performance → Diagnostics** | Yes (opt-in only) | No | Optional | App functionality | Same Firebase Crashlytics behavior as crash logs. |
| **App info and performance → Other app performance data** | No | — | — | — | Not collected. |
| **Device or other IDs** | No | — | — | — | We do not collect Android Advertising IDs. RevenueCat manages its own internal device identifiers for receipt validation; we do not access them. |

---

## 4. Per-data-type purpose mapping

For each collected type, choose only the following purposes (avoid
"Advertising or marketing", "Personalization", "Analytics", and "Fraud
prevention, security, and compliance" unless counsel decides otherwise):

- Name → **Account management**, **App functionality**
- Email address → **Account management**, **App functionality**
- User IDs → **Account management**, **App functionality**
- Purchase history → **App functionality**
- Precise location → **App functionality**
- Crash logs → **App functionality**
- Diagnostics → **App functionality**

---

## 5. Data security section

Mark these statements:

- **All data is encrypted in transit:** Yes.
- **You can request that data be deleted:** Yes.
  - Provide the account-deletion URL or `support@johnsondigital.com`
    contact.
- **Data is collected following Google Play's Families Policy:** Not
  applicable; LoadOut is not directed at children.

---

## 6. Permissions Play will surface

For each Android runtime permission, Play asks you to justify the use.
Match these to the per-feature explanations the app already shows:

- `CAMERA` — to photograph handwritten reloading notes for the
  photo-import feature; image stays on-device.
- `READ_MEDIA_IMAGES` (Android 13+) / `READ_EXTERNAL_STORAGE`
  (older) — to choose an existing photo of reloading notes to import;
  image stays on-device.
- `ACCESS_FINE_LOCATION` (foreground only) — to fetch local weather
  for ballistics calculations on demand.
- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` — to pair with a chronograph
  (Garmin Xero) or weather meter (Kestrel).

---

## 7. Sensitive permissions declaration

If you submit the build with any of the "sensitive" permission classes
that require a Play Console declaration (e.g., background location, SMS,
Call Log, Accessibility), document them here. As of 2026-05-07,
**LoadOut does not use any sensitive permissions in the Play sense.**
Foreground-only `ACCESS_FINE_LOCATION` is not classed as sensitive for
Data Safety purposes the same way background location is.

---

## 8. Account deletion URL

Play requires a publicly accessible page that explains how to delete
the account and the associated data. Suggested content (HTML to be
written before launch):

- A short explanation that LoadOut stores no reloading data on its
  servers and that on-device deletion is via Settings → Delete my
  data.
- An email-based form: "Email <support@johnsondigital.com> from the
  email tied to your account with the subject 'Account deletion
  request'. We will delete the Firebase Authentication record and ask
  RevenueCat to delete the linked entitlement record. We will confirm
  by email when complete."
- Estimated processing time (suggest 7 business days; counsel to
  confirm against the privacy-rights window applicable to the
  operator).

---

## 9. Open items for legal review

- Confirm the categorization of foreground-only Precise Location.
  Some legal reviewers prefer to declare it as "collected" and
  "optional" with explicit "App functionality" purpose, even though
  we do not retain the coordinates server-side.
- Confirm the account-deletion URL approach (hosted page vs. just an
  email contact). Play's Account Deletion policy has tightened over
  the last year; the hosted page is the safer choice.
- Confirm encryption-at-rest claims for Firebase. Firebase encrypts
  data at rest by default; we should not claim anything stronger than
  what Google publishes for the relevant Firebase services
  (Authentication, Crashlytics, Storage).
- Confirm that we do not need to declare any of the "Health
  Connect" / "Sensitive permissions" categories given that BLE
  pairing for chronograph and weather meter is not a sensitive
  permission for Data Safety purposes.
- Verify the targeted SDK level requirements and Data Safety
  requirements for the Play Store version we ship at launch.
