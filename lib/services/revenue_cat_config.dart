/// RevenueCat API keys.
///
/// - iOS: real public key (`appl_*`) issued after the iOS app was set up
///   in the RevenueCat dashboard. Sandbox + production purchases route
///   through this key.
/// - Android: still the project-wide **onboarding test key** (`test_*`)
///   pending Play Console identity verification. Replace with a `goog_*`
///   key once the Android app is set up in RevenueCat.
///
/// These are PUBLIC keys (safe to commit) — the actual secrets (App Store
/// Connect API key, Google service account JSON, App-Specific Shared
/// Secret) live on the RevenueCat server side and never come near the
/// client.
class RevenueCatConfig {
  static const String iosApiKey = 'appl_gxAWIbbwkvywccAzLMWASShyoxx';
  static const String androidApiKey = 'test_VArPeRYeXEvZeHqaPqpUTDRDKaW';

  /// Entitlement identifier configured in the RevenueCat dashboard.
  /// Active when the user has any Pro subscription/purchase active.
  static const String proEntitlement = 'pro';

  /// Whether the embedded API keys still hold placeholder values. When true,
  /// services should bail out gracefully instead of calling into the SDK
  /// (no offerings to fetch, no products to display).
  ///
  /// The onboarding `test_*` key is treated as configured (not a placeholder)
  /// so the SDK actually initializes against RevenueCat's sandbox.
  static bool get isPlaceholder =>
      iosApiKey.startsWith('REPLACE_ME') ||
      androidApiKey.startsWith('REPLACE_ME');
}
