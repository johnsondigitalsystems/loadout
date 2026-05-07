// FILE: lib/screens/disclaimer/disclaimer_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Renders the BLOCKING first-launch disclaimer. Until the user has
// scrolled to the bottom of the long-form safety text, ticked the "I
// understand and accept" checkbox, AND tapped the "Accept and Continue"
// button, the app refuses to advance to the auth gate or any feature
// screen. There is no "skip" button and the OS back button is suppressed
// (`PopScope(canPop: false)` — Flutter's modern way to disable popping
// the route off the navigator stack).
//
// `DisclaimerScreen` is a `StatefulWidget` because it tracks two pieces
// of UI state across the lifetime of the screen:
//
//   - `_scrolledToBottom` — flips to `true` once the user has scrolled
//     to within 24 pixels of the bottom of the disclaimer body. The
//     scroll listener (`_onScroll`) latches this once and never flips
//     it back. There's also a `WidgetsBinding.instance.addPostFrameCallback`
//     that flips it immediately if the content is short enough that no
//     scrolling is needed at all (otherwise the gate would be unreachable
//     on a tablet where everything fits on one screen).
//   - `_accepted` — tracks the checkbox value. The checkbox is greyed
//     out (`onChanged: null`) until `_scrolledToBottom` is true, so the
//     user physically cannot tick it without scrolling.
//
// The "Accept and Continue" `FilledButton` is enabled only when both
// flags are true (`canAccept = _accepted && _scrolledToBottom`). On tap
// it calls the `widget.onAccept` callback handed in by the parent;
// persistence (the SharedPreferences key) is the parent's job, not this
// file's.
//
// The disclaimer body is a `_DisclaimerBody` private widget that lays
// out plain `Text` chunks in a `DefaultTextStyle.merge`. It covers:
// "reloading is dangerous," "verify every recipe against current
// manuals," "no warranty," "your data stays on your device," "your
// responsibility" with a five-bullet `_Bullet` list, "no professional
// relationship," and "liability." It ends with "If you do not accept
// these terms, do not use this app."
//
// Three visual affordances reinforce that the screen is scrollable:
//
//   - A sticky info banner at the top reads "Scroll through the full
//     disclaimer below before accepting."
//   - A `Scrollbar` with `thumbVisibility: true` so the scroll position
//     is always visible.
//   - A bottom fade gradient + "Scroll for more ↓" label that
//     auto-hides once `_scrolledToBottom` is true.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// LoadOut's safety/liability posture (see CLAUDE.md and the project's
// privacy policy) requires the user to be informed BEFORE they can use
// the app, every time, on every device, until the disclaimer version
// changes. The persistence is keyed by a versioned preference name —
// the parent that hosts this screen uses `disclaimer_accepted_v1`. To
// force re-acceptance on a meaningful policy change, that suffix can be
// bumped to `_v2` etc. and existing users will be re-prompted.
//
// The "scroll to the bottom before the checkbox enables" pattern is
// industry-standard for binding consent flows — a court is more likely
// to accept that the user actually read the terms if they had to pass
// through the entire body of text on the way to the accept button.
//
// This screen is the FIRST of the two disclaimer surfaces in the app.
// The other is `lib/widgets/disclaimer_overlay.dart`, which is the
// short per-launch reminder dialog. Don't confuse them.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Two subtle problems handled here:
//
//   1. On large screens (tablets, big phones in landscape), the entire
//      disclaimer might fit without any scrolling at all. With a naive
//      "must scroll" implementation the gate would be permanently
//      unreachable. The `addPostFrameCallback` after layout checks
//      `pos.maxScrollExtent <= 0` and short-circuits the flag in that
//      case.
//   2. `PopScope(canPop: false)` blocks the Android system back button
//      and any iOS swipe-to-go-back gesture. Without it, the user
//      could back-button their way past the gate on Android.
//
// The 24-pixel slack on the "is bottom?" check (`pos.pixels >=
// pos.maxScrollExtent - 24`) tolerates the tiny rendering imprecision
// of physics-driven scroll views — the user shouldn't have to slam the
// scroll exactly to the last pixel for the checkbox to enable.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/app.dart` — the `_DisclaimerGate` widget renders this screen
//   on first launch (when the SharedPreferences flag is unset) and
//   provides an `onAccept` callback that flips the flag and advances
//   to the auth gate.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None directly — this file does not persist anything itself. The
// `onAccept` callback is the file's only output, and the parent decides
// what to do with it (currently: write `disclaimer_accepted_v1` to
// SharedPreferences, then rebuild). Pure UI plus a single callback.

import 'package:flutter/material.dart';

/// Full-screen, blocking disclaimer shown on first launch. The user must
/// scroll, tick the acknowledgement checkbox, and tap "Accept and continue"
/// before the app proceeds to the auth gate. The parent persists acceptance
/// via the [onAccept] callback.
class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  final _scrollController = ScrollController();
  bool _scrolledToBottom = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // If the content fits without scrolling, treat the user as having
    // reached the bottom after the first frame so the gate isn't
    // unreachable on large screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent <= 0) {
        setState(() => _scrolledToBottom = true);
      }
    });
  }

  void _onScroll() {
    if (_scrolledToBottom) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 24) {
      setState(() => _scrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAccept = _accepted && _scrolledToBottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Important — Please Read'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Sticky instruction banner: visible from the moment the
              // screen loads, so users know the screen is scrollable and
              // why the Accept button below is disabled.
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scroll through the full disclaimer below before '
                        'accepting.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                        child: const _DisclaimerBody(),
                      ),
                    ),
                    // Bottom fade + chevron — visual affordance that more
                    // content lies below the fold. Hides itself once the
                    // user has reached the bottom.
                    if (!_scrolledToBottom)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.surface.withValues(alpha: 0),
                                  theme.colorScheme.surface,
                                ],
                              ),
                            ),
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Scroll for more',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      value: _accepted,
                      onChanged: _scrolledToBottom
                          ? (v) => setState(() => _accepted = v ?? false)
                          : null,
                      title: Text(
                        'I understand and accept',
                        style: TextStyle(
                          color: _scrolledToBottom
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                        ),
                      ),
                      subtitle: !_scrolledToBottom
                          ? Text(
                              'Available after scrolling to the bottom',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: canAccept ? widget.onAccept : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Accept and Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerBody extends StatelessWidget {
  const _DisclaimerBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleLarge;
    final subheading = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final body = theme.textTheme.bodyMedium;
    final boldBody = body?.copyWith(fontWeight: FontWeight.w700);

    return DefaultTextStyle.merge(
      style: body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Draft banner — review with counsel before launch. Remove
          // this widget once the disclaimer is signed off.
          _DraftBanner(theme: theme),
          const SizedBox(height: 12),
          Text(
            'Read this carefully. Reloading is dangerous.',
            style: heading,
          ),
          const SizedBox(height: 16),
          Text(
            'Reloading ammunition can cause serious injury or death.',
            style: boldBody,
          ),
          const SizedBox(height: 8),
          const Text(
            'Hand-loaded ammunition that is over-charged, double-charged, '
            'under-charged, mis-seated, or assembled with incompatible '
            'components can detonate inside your firearm. The result can '
            'include a destroyed firearm, lost fingers, blinded eyes, '
            'severe burns, hearing loss, and death. These outcomes are '
            'not abstract risks — they happen to experienced reloaders.',
          ),
          const SizedBox(height: 16),
          Text('What LoadOut is — and isn\'t.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'LoadOut is a reference and tracking app. It helps you '
            'organize reloading recipes, firearms, components, batches, '
            'brass lots, and ballistic profiles. The reference catalogs '
            'inside the app — powders, bullets, primers, brass, '
            'firearms, parts, and SAAMI cartridge specifications — are '
            'provided for informational and organizational purposes '
            'only.',
          ),
          const SizedBox(height: 8),
          Text(
            'LoadOut is not a reloading manual. It is not a replacement '
            'for one. The data inside it has not been independently '
            'pressure-tested by us. Treat every entry as reference, not '
            'instruction.',
            style: boldBody,
          ),
          const SizedBox(height: 16),
          Text(
            'Verify every load against a current published manual.',
            style: subheading,
          ),
          const SizedBox(height: 4),
          const Text(
            'Before you load a single round, cross-reference your recipe '
            'against the current edition of the relevant published '
            'manual from the powder, bullet, and firearm manufacturers — '
            'for example Hodgdon, IMR, Alliant, Vihtavuori, Sierra, '
            'Hornady, Berger, Speer, Nosler, Lyman, and the firearm '
            'manufacturer for your specific platform.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Component lots change. Powder lot variation alone can shift '
            'pressure meaningfully. Manuals are updated as testing data '
            'changes. A recipe that was published as safe a decade ago '
            'may no longer be considered safe today, or may not be safe '
            'with your current lot of powder, primer, or bullet.',
          ),
          const SizedBox(height: 16),
          Text('Never start at maximum charge.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'Always begin at the published starting charge for your '
            'cartridge, bullet, and powder combination. Work up in small '
            'increments toward — but not exceeding — the published '
            'maximum, watching for pressure signs (flattened or pierced '
            'primers, ejector marks, sticky bolt lift, case head '
            'expansion). Stop and back off the moment you see them.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Pressure signs are not a green light to keep going. They '
            'are a warning that you are at or beyond the safe pressure '
            'envelope for your firearm with your specific components on '
            'this specific day. Atmospheric conditions, bore condition, '
            'chamber dimensions, brass condition, and primer cup '
            'thickness all matter.',
          ),
          const SizedBox(height: 16),
          Text('Use proper equipment and technique.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'Use a calibrated scale that you have verified against check '
            'weights. Inspect every case for cracks, web separation, or '
            'unusual head-to-shoulder dimension. Wear eye and ear '
            'protection during load development. Do not work near '
            'distractions or under the influence of anything that '
            'impairs judgment.',
          ),
          const SizedBox(height: 16),
          Text('No professional relationship.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'LoadOut is not a substitute for instruction from a '
            'qualified handloader, gunsmith, or competition coach. If '
            'you are new to reloading, take a class, read at least one '
            'current published manual cover-to-cover, and work with '
            'someone experienced before producing live ammunition.',
          ),
          const SizedBox(height: 16),
          Text('Your responsibility.', style: subheading),
          const SizedBox(height: 4),
          const Text('By using this app you agree that you:'),
          const SizedBox(height: 8),
          const _Bullet(
            'Are of legal age to handle firearms and reloading '
            'components in your jurisdiction.',
          ),
          const _Bullet(
            'Will follow all applicable federal, state, provincial, '
            'and local laws.',
          ),
          const _Bullet(
            'Will use proper safety equipment and procedures.',
          ),
          const _Bullet(
            'Will not rely on this app as your sole or primary source '
            'of recipe data.',
          ),
          const _Bullet(
            'Will verify every load against a current published manual '
            'before loading.',
          ),
          const _Bullet(
            'Accept all risk associated with reloading and shooting.',
          ),
          const SizedBox(height: 16),
          Text('No warranty.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'LoadOut is provided "as is" with no warranty of any kind. '
            'We do not warrant that the data shown is accurate, '
            'complete, current, or safe to act on. Errors in reference '
            'data, in your own data entry, or in the app itself are '
            'possible. Component lots vary, firearm chambers vary, and '
            'conditions vary.',
          ),
          const SizedBox(height: 16),
          Text('Your data stays yours.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'Your reloading data — recipes, firearms, custom '
            'components, and inventory — is stored on this device by '
            'default. LoadOut does not run a backend that receives or '
            'stores it. With Pro, you can optionally back up an '
            'end-to-end encrypted copy to your own iCloud Drive or '
            'Google Drive, using a passphrase only you know. LoadOut '
            'never sees the encrypted backup.',
          ),
          const SizedBox(height: 16),
          Text('Liability.', style: subheading),
          const SizedBox(height: 4),
          const Text(
            'To the fullest extent permitted by law, Johnson Digital '
            'Systems and the developers of LoadOut disclaim all '
            'liability for any damages arising from use of this app, '
            'including but not limited to property damage, personal '
            'injury, or death. The decision to load and fire any '
            'ammunition is yours, and the consequences of that decision '
            'are also yours.',
          ),
          const SizedBox(height: 24),
          Text(
            'If you do not accept these terms, do not use this app.',
            style: body?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Yellow draft banner shown until counsel has approved the disclaimer
/// language. Remove this widget once the legal review is complete.
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
              'Draft — review with counsel before publication. This '
              'safety disclaimer language has not yet been approved by '
              'an attorney.',
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

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Text('•'),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
