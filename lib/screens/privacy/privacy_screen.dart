import 'package:flutter/material.dart';

/// Full-text privacy policy. Reachable from the privacy dialog on the home
/// screen. Mirrors `PRIVACY_POLICY.md` in the repo root — keep them in sync.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const String _effectiveDate = '2026-05-06';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final headingStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = textTheme.bodyMedium;
    final mutedBodyStyle = bodyStyle?.copyWith(color: mutedColor);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('LoadOut Privacy Policy', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Effective date: $_effectiveDate',
            style: mutedBodyStyle,
          ),
          const SizedBox(height: 24),

          Text('What this app is', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'LoadOut is a reloading reference and tracking app. It helps you '
            'record your recipes, firearms, and components. Reference '
            'catalogs (cartridges, powders, bullets, primers, brass, '
            'firearms, parts) ship with the app for browsing.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('Data we store on your device', style: headingStyle),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Recipes, custom components you add, firearms you\'ve added, '
                  'and shots-fired counts.',
              'This data lives in an on-device SQLite database (in your '
                  'app\'s private storage). It never leaves your phone.',
              'The only way this data is removed is if you delete the app, '
                  'reset your device, or clear app storage.',
            ],
          ),
          const SizedBox(height: 24),

          Text('Data we send to a server', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'We use Firebase Authentication (Google Cloud) for sign-in. The '
            'following data is processed by Firebase Authentication on '
            'Google\'s servers:',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Your email address.',
              'A password hash (if you use email/password sign-in) — stored '
                  'by Firebase, not by us; we never see the plaintext.',
              'OAuth tokens for any third-party providers you use (Google, '
                  'Apple, Microsoft, Yahoo).',
              'Firebase\'s own technical metadata (anonymous user IDs, '
                  'timestamps of sign-ins).',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We do not see, store, or transmit any of your reloading data — '
            'recipes, firearms, components, or inventory.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('What we don\'t do', style: headingStyle),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'No analytics. We don\'t track your in-app behavior.',
              'No advertising. The app shows no ads.',
              'No third-party data sharing or selling.',
              'No location collection.',
              'No microphone or camera access (the app doesn\'t request '
                  'these).',
              'No contacts, photos, or other personal device data is '
                  'collected.',
            ],
          ),
          const SizedBox(height: 24),

          Text('Sign-in providers', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'If you sign in with a third-party provider (Google, Apple, '
            'Microsoft, Yahoo), that provider\'s privacy policy also '
            'applies to your relationship with them. We only request the '
            'minimum scope needed to identify you (typically email and '
            'name).',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Google: https://policies.google.com/privacy',
              'Apple: https://www.apple.com/legal/privacy/',
              'Microsoft: https://privacy.microsoft.com/privacystatement',
              'Yahoo: https://legal.yahoo.com/us/en/yahoo/privacy/',
            ],
          ),
          const SizedBox(height: 24),

          Text('Children', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'LoadOut is not directed at children under 13 (or 17, given '
            'the subject matter). We do not knowingly collect data from '
            'minors. Reloading is for adults — see the app\'s disclaimer.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('Your rights', style: headingStyle),
          const SizedBox(height: 8),
          _BulletList(
            style: bodyStyle,
            items: const [
              'Delete your account: sign out and delete the app. To remove '
                  'your auth record from Firebase, request account deletion '
                  'via the contact below.',
              'Export your data: an export feature is on the roadmap. Until '
                  'it ships, your data is in the on-device SQLite database; '
                  'advanced users can extract it from app sandbox storage.',
              'EU/UK/CA residents (GDPR / UK GDPR / CCPA): you have rights '
                  'to access, correct, delete, and port your data. Contact '
                  'us using the address below.',
            ],
          ),
          const SizedBox(height: 24),

          Text('Changes to this policy', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'We will update the effective date and notify you in-app (via '
            'a re-prompt of the disclaimer / privacy dialog) if we make '
            'material changes.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),

          Text('Contact', style: headingStyle),
          const SizedBox(height: 8),
          Text('Johnson Digital Systems', style: bodyStyle),
          Text('info@johnsondigitalsystems.com', style: bodyStyle),
          const SizedBox(height: 32),
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
