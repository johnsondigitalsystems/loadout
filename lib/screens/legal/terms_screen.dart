// FILE: lib/screens/legal/terms_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders the in-app Terms of Service as a scrollable text screen. Mirrors
// the hosted document at `public/legal/terms.html` — keep them in sync.
// The screen has no input or interactive state — just headings,
// paragraphs, and bullet lists.
//
// The terms cover:
//
//   - Who we are; accepting these Terms; eligibility (18+).
//   - Account use (including anonymous + sign-in flows we support).
//   - Subscription + lifetime purchase terms; refunds (defer to App Store
//     and Google Play); price changes.
//   - User content: the user owns their reloading data; we get only a
//     limited, non-exclusive license tied to the cloud-backup feature,
//     and even that is on encrypted-at-rest data we cannot read.
//   - Reference catalogs and SAAMI data are reference-only; the user has
//     to verify against current published manuals.
//   - Acceptable use — no reverse engineering of safety guidance, etc.
//   - Strong limitation-of-liability language, especially around
//     reloading-related injury / death.
//   - Apple- and Google-specific addenda required by the stores.
//   - Termination, governing law, miscellaneous.
//
// A "Draft — review with counsel before publication" banner sits at the
// top until counsel signs off. Remove it once the document is reviewed.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Both the App Store and Google Play require a public Terms of Service
// for any app that has paid features and accepts user content. Beyond
// the store requirement, the Terms are the legal vehicle for the
// reloading liability shield: the disclaimer screen warns the user, and
// these Terms make acceptance of that warning a condition of using the
// Service.
//
// Like `PrivacyScreen`, this widget is rendered both in-app (via
// Settings → Terms of Service) and reflected on the public Hosting site
// at `/legal/terms.html`. Keep both surfaces in sync — counsel will read
// the hosted version and the App Store reviewer will tap into the
// in-app version.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/settings_screen.dart — "Terms of Service" tile.
// - lib/screens/auth/login_screen.dart — the small "By continuing you
//   agree to our Terms…" footer link can push this screen.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None — pure rendering of `const` strings. No I/O, no network, no
// plugin calls.

import 'package:flutter/material.dart';

/// Full-text Terms of Service. Mirrors `public/legal/terms.html` — keep
/// the two in sync.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String _effectiveDate = '2026-05-07';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final headingStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final subheadingStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = textTheme.bodyMedium;
    final mutedBodyStyle = bodyStyle?.copyWith(color: mutedColor);

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('LoadOut Terms of Service', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Effective date: $_effectiveDate',
            style: mutedBodyStyle,
          ),
          const SizedBox(height: 16),
          _DraftBanner(theme: theme),
          const SizedBox(height: 12),
          _DangerBanner(theme: theme),
          const SizedBox(height: 16),

          Text('1. Who we are', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            '"LoadOut" (the "Service") is operated by Johnson Digital '
            'Systems ("we", "us", "our"). These Terms of Service (the '
            '"Terms") govern your access to and use of the LoadOut mobile '
            'app, the marketing site at '
            'loadout-precision-reloading.web.app, and any related '
            'services we provide.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('2. Accepting these Terms', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'By installing, opening, or using the Service you agree to '
            'these Terms and to our Privacy Policy. If you do not agree, '
            'do not use the Service. If you accept on behalf of an '
            'organization, you confirm you are authorized to bind that '
            'organization to these Terms.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('3. Eligibility', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'You must be at least 18 years old (or the age of majority in '
            'your jurisdiction, whichever is greater) and legally '
            'permitted to handle firearms, ammunition, and reloading '
            'components where you live. You are responsible for '
            'compliance with all applicable federal, state, provincial, '
            'and local laws.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('4. Your account', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'You may use LoadOut without an account, with an anonymous '
            'account, or with a sign-in account (email/password, Google, '
            'Apple, Microsoft, Yahoo, or email-link). If you create a '
            'sign-in account, you agree to:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Provide accurate information.',
              'Keep your credentials secure and not share them.',
              'Be responsible for all activity under your account.',
              'Notify us promptly if you suspect unauthorized access.',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We may suspend or terminate accounts that violate these '
            'Terms, that we believe pose a safety risk, or that we are '
            'required to suspend by law.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('5. Subscriptions and one-time purchases',
              style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'LoadOut is free to use for a baseline set of features. '
            'Optional LoadOut Pro features are unlocked via either of the '
            'following purchases, processed by Apple or Google:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Yearly subscription — auto-renews each year for the price '
                  'displayed on the App Store or Google Play (currently '
                  'US\$39.99/yr in the US store; local pricing varies). '
                  'Cancel at any time from your store subscription '
                  'settings; cancellation takes effect at the end of the '
                  'current period.',
              'Lifetime purchase — one-time payment for the price '
                  'displayed on the store (currently US\$79.99 in the US '
                  'store). The lifetime entitlement remains active for as '
                  'long as we operate the LoadOut Pro service, on the '
                  'platforms supported by Apple and Google, and to the '
                  'extent permitted by store policies. If we discontinue '
                  'the Service, we will provide reasonable advance notice '
                  'and a way to export your data.',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Subscription and lifetime entitlements are tied to your '
            'Apple ID or Google account, and follow you across devices '
            'once you sign in to LoadOut. Use "Restore Purchases" in '
            'Settings to re-link a purchase after reinstalling.',
            style: bodyStyle,
          ),
          const SizedBox(height: 16),

          Text('5.1 Refunds', style: subheadingStyle),
          const SizedBox(height: 8),
          Text(
            'All purchases are made through Apple or Google. Refunds are '
            'handled by them, not by us, and are subject to their refund '
            'policies:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Apple: https://reportaproblem.apple.com',
              'Google Play: '
                  'https://play.google.com/store/account/orderhistory',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Where required by law (e.g., the EU 14-day right of '
            'withdrawal, where applicable), we will honor statutory '
            'refund rights even outside the store flows. To request a '
            'statutory refund, email support@johnsondigital.com.',
            style: bodyStyle,
          ),
          const SizedBox(height: 16),

          Text('5.2 Price changes', style: subheadingStyle),
          const SizedBox(height: 8),
          Text(
            'We may change subscription prices for new billing periods. '
            'We will give you advance notice and a chance to cancel '
            'before any price change takes effect. Price changes do not '
            'affect the current paid period.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('6. Your content and your data', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Your reloading data — loads, firearms, custom components, '
            'batches, brass lots, ballistic profiles, notes — is yours. '
            'You retain all rights in it. We do not claim any ownership '
            'of it.',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'LoadOut is local-first: your reloading data lives on your '
            'device. The only place we touch your reloading data is if '
            'you turn on cloud backup (a Pro feature), in which case the '
            'data is encrypted on your device with a passphrase only you '
            'know before upload to your own iCloud Drive or Google Drive. '
            'To make that feature work, you grant us a limited, '
            'non-exclusive, royalty-free, worldwide license to:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Process the encrypted backup blob on your device for the '
                  'purpose of encrypting and uploading it to your cloud '
                  'provider; and',
              'Process and decrypt it on your device when you restore it.',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We do not have a license to read, copy, distribute, modify, '
            'or use the contents of your reloading data, because the '
            'encryption keeps it inaccessible to us. We never receive the '
            'decrypted data, and we never receive your passphrase.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('7. Reference catalogs and SAAMI data',
              style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'The Service includes reference catalogs (cartridges, '
            'powders, bullets, primers, brass, firearms, parts, SAAMI '
            'specifications) for browsing offline. This material is '
            'provided for reference and organizational purposes only. It '
            'is not and does not replace a current published reloading '
            'manual. Component lots vary, firearm chambers vary, and '
            'load data published by component manufacturers is updated '
            'over time. You must verify any load you use against current '
            'manuals from the powder, bullet, and firearm manufacturers, '
            'and against published SAAMI specifications, before producing '
            'live ammunition.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('8. Acceptable use', style: headingStyle),
          const SizedBox(height: 8),
          Text('You agree that you will not:', style: bodyStyle),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Reverse engineer, decompile, disassemble, or otherwise '
                  'attempt to extract the source code of the Service, '
                  'except where this is expressly permitted by applicable '
                  'law.',
              'Reverse engineer, copy, scrape, or redistribute the '
                  'safety guidance, disclaimer text, reference catalogs, '
                  'or SAAMI data so as to remove warnings or attribution, '
                  'or to misrepresent the source of that data.',
              'Use the Service to develop a competing product by copying '
                  'its proprietary content (e.g., disclaimer wording, '
                  'in-app copy, reference data layouts).',
              'Use the Service to upload or distribute illegal content, '
                  'malware, or content that infringes third-party rights.',
              'Attempt to access another user\'s account or any '
                  'non-public area of the Service.',
              'Use the Service to do anything that violates firearms, '
                  'ammunition, export, or sanctions laws applicable to '
                  'you.',
              'Use automated means (bots, scrapers, headless clients) to '
                  'access the Service in a way that overloads our '
                  'infrastructure or circumvents our access controls.',
            ],
          ),
          const SizedBox(height: 24),

          Text('9. Third-party services', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'The Service uses third-party services to operate, including '
            'Google Cloud / Firebase (Authentication, Hosting, Storage), '
            'RevenueCat (purchase verification), and the Apple App Store '
            '/ Google Play (purchase processing). Your use of those '
            'services is also governed by their terms and privacy '
            'policies.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('10. Intellectual property', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'The Service, its design, the LoadOut name and logo, the '
            'in-app copy, and the curated reference catalogs are owned '
            'by Johnson Digital Systems and protected by '
            'intellectual-property laws. We grant you a personal, '
            'limited, non-transferable, revocable license to use the '
            'Service in accordance with these Terms. All other rights '
            'are reserved.',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Trademarks and brand names of firearms, components, and '
            'component manufacturers referenced in the catalogs belong '
            'to their respective owners. Their inclusion is for '
            'identification only and does not imply endorsement or '
            'affiliation.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('11. No warranty', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT '
            'WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WITHOUT '
            'LIMITATION ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A '
            'PARTICULAR PURPOSE, ACCURACY, OR NON-INFRINGEMENT. WE DO '
            'NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED, '
            'ERROR-FREE, OR SECURE, OR THAT ANY REFERENCE DATA IS '
            'ACCURATE, COMPLETE, CURRENT, OR SAFE TO ACT ON. YOU ARE '
            'RESPONSIBLE FOR VERIFYING EVERY LOAD AGAINST CURRENT '
            'PUBLISHED MANUALS.',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          Text('12. Limitation of liability', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'TO THE FULLEST EXTENT PERMITTED BY LAW, JOHNSON DIGITAL '
            'SYSTEMS AND ITS OFFICERS, DIRECTORS, EMPLOYEES, '
            'CONTRACTORS, AND AGENTS WILL NOT BE LIABLE FOR ANY '
            'INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR '
            'PUNITIVE DAMAGES, OR FOR ANY LOSS OF PROFITS, REVENUE, '
            'DATA, GOODWILL, OR OTHER INTANGIBLE LOSSES, ARISING FROM '
            'OR RELATED TO YOUR USE OF THE SERVICE, EVEN IF WE HAVE '
            'BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, WE ARE '
            'NOT LIABLE FOR ANY PROPERTY DAMAGE, PERSONAL INJURY, OR '
            'DEATH ARISING FROM ANY AMMUNITION PRODUCED, LOADED, '
            'HANDLED, FIRED, OR STORED BY YOU OR BY ANY THIRD PARTY, '
            'WHETHER OR NOT INFORMED BY DATA YOU OBTAINED THROUGH THE '
            'SERVICE. YOU ASSUME ALL RISK ASSOCIATED WITH RELOADING AND '
            'SHOOTING.',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'TO THE EXTENT ANY LIABILITY CANNOT BE DISCLAIMED BY LAW, '
            'OUR AGGREGATE LIABILITY TO YOU FOR ALL CLAIMS ARISING FROM '
            'OR RELATED TO THE SERVICE WILL NOT EXCEED THE GREATER OF '
            '(A) THE AMOUNT YOU PAID US FOR THE SERVICE IN THE TWELVE '
            'MONTHS PRECEDING THE CLAIM, OR (B) US\$50.',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Some jurisdictions do not allow the exclusion of certain '
            'warranties or limitations of certain damages. In those '
            'jurisdictions, the exclusions and limitations above apply '
            'only to the maximum extent permitted by law.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('13. Indemnification', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'You agree to defend, indemnify, and hold harmless Johnson '
            'Digital Systems and its personnel from any claims, '
            'liabilities, damages, losses, and expenses (including '
            'reasonable attorneys\' fees) arising out of or related to: '
            '(a) your use of the Service; (b) your violation of these '
            'Terms; (c) any ammunition you produce, handle, or fire; or '
            '(d) your violation of any law or third-party right.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('14. Termination', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'You can stop using the Service at any time by deleting the '
            'app and, if you wish, requesting account deletion via '
            'support@johnsondigital.com. We may suspend or terminate '
            'your access if you violate these Terms, if we are required '
            'to by law, or if we discontinue the Service. On '
            'termination, sections of these Terms that by their nature '
            'should survive (ownership, warranty disclaimer, limitation '
            'of liability, indemnification, dispute resolution) will '
            'survive.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('15. Changes to the Service or these Terms',
              style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'We may update the Service and these Terms over time. If we '
            'make a material change to the Terms, we will update the '
            'effective date and surface notice in-app. Continued use of '
            'the Service after the change means you accept the updated '
            'Terms. If you do not accept the changes, stop using the '
            'Service.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('16. Governing law and disputes', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'These Terms are governed by the laws of the State of '
            '[STATE TO BE SET BY COUNSEL], United States, without '
            'regard to conflict-of-laws rules. The exclusive venue for '
            'any dispute that is not subject to arbitration is the '
            'state and federal courts located in '
            '[COUNTY/CITY TO BE SET BY COUNSEL].',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          Text(
            '[Optional, subject to attorney review] The parties agree '
            'to resolve disputes by binding individual arbitration '
            'under the rules of a major arbitration provider, and '
            'waive class-action and class-arbitration rights. The '
            'specifics of the arbitration provision must be drafted '
            'with counsel and conform to the operator\'s home-state '
            'law and the FAA.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('17. Apple-specific terms', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'If you obtained the Service from the Apple App Store, the '
            'following also apply:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'These Terms are between you and Johnson Digital Systems, '
                  'not Apple. Apple is not responsible for the Service '
                  'or its content.',
              'Apple has no obligation to provide maintenance or '
                  'support for the Service.',
              'If the Service fails to conform to any applicable '
                  'warranty, you may notify Apple, who will refund the '
                  'purchase price; Apple has no further warranty '
                  'obligation.',
              'Apple is not responsible for product claims, third-party '
                  'intellectual-property claims, or your compliance '
                  'with consumer-protection law.',
              'Apple and its subsidiaries are third-party beneficiaries '
                  'of these Terms and may enforce them against you.',
            ],
          ),
          const SizedBox(height: 24),

          Text('18. Google Play-specific terms', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'If you obtained the Service from Google Play, the Google '
            'Play Terms of Service also apply to your purchase and use '
            'of the Service. To the extent of any conflict between '
            'these Terms and the Google Play Terms with respect to '
            'your purchase, the Google Play Terms control for that '
            'purchase.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('19. Miscellaneous', style: headingStyle),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Entire agreement. These Terms and the Privacy Policy are '
                  'the entire agreement between you and us regarding '
                  'the Service.',
              'Severability. If any provision is unenforceable, the '
                  'rest remain in effect.',
              'No waiver. Our failure to enforce a provision is not a '
                  'waiver of it.',
              'Assignment. You may not assign these Terms without our '
                  'consent. We may assign them in connection with a '
                  'merger, acquisition, or sale of assets.',
              'Notices. Notices to you may be sent in-app or to the '
                  'email tied to your account. Notices to us must go '
                  'to support@johnsondigital.com.',
            ],
          ),
          const SizedBox(height: 24),

          Text('Contact', style: headingStyle),
          const SizedBox(height: 8),
          Text('Johnson Digital Systems — LoadOut', style: bodyStyle),
          Text('support@johnsondigital.com', style: bodyStyle),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Yellow draft banner shown until counsel has approved the Terms.
/// Remove this widget once the legal review is complete.
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? scheme.tertiaryContainer.withValues(alpha: 0.4)
        : const Color(0xFFFEF3C7);
    final fg = isDark ? scheme.onTertiaryContainer : const Color(0xFF78350F);
    final border = isDark ? scheme.tertiary : const Color(0xFFF59E0B);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Draft — review with counsel before publication. These '
              'Terms have not yet been approved by an attorney.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red banner reinforcing the reloading-safety preamble at the top of
/// the Terms.
class _DangerBanner extends StatelessWidget {
  const _DangerBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? scheme.errorContainer.withValues(alpha: 0.4)
        : const Color(0xFFFEE2E2);
    final fg = isDark ? scheme.onErrorContainer : const Color(0xFF7F1D1D);
    final border = isDark ? scheme.error : const Color(0xFFDC2626);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reloading ammunition is dangerous. LoadOut is a reference '
              'and tracking tool only. By using the app you accept full '
              'responsibility for verifying every load against current '
              'published manuals and for the safety consequences of any '
              'ammunition you produce. See the in-app Safety Disclaimer '
              'for the full warning.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a list of strings as `• `-prefixed lines. Each item is its own
/// `Text` so long items wrap correctly under the bullet.
class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.style});

  final List<String> items;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
