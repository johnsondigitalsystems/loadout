# LoadOut iOS Share Extension — manual Xcode setup

The `share_handler` Flutter plugin is wired up in Dart already
(`lib/services/share_handler_service.dart`), the Android side is
configured via `android/app/src/main/AndroidManifest.xml`, and the
package is declared in `pubspec.yaml`.

iOS, however, requires a one-time Share Extension target in Xcode.
Apple does not allow a Flutter app to receive `UIActivityViewController`
shares without a dedicated extension target — same constraint that
forces the watch app's manual Xcode wiring (see CLAUDE.md § 15).

This README walks an operator through the GUI steps. Every step is
required; skipping any one of them yields a build that compiles but
silently doesn't appear in the iOS share sheet.

## What this enables

When the user opens a note in **Apple Notes** (or any text-share-
capable app — OneNote on iOS, Bear, Obsidian, Drafts, even Mail and
Safari), taps **Share**, and picks **LoadOut** from the share sheet,
the text is delivered to the running Flutter app and the recipe-
review screen pops up pre-parsed.

Without this extension, LoadOut does not appear in the iOS share
sheet at all. The user has to fall back to the in-app file picker
(plain `.txt`, PDF) or wait for OneNote / Word export.

## One-time Xcode steps

1. Open `ios/Runner.xcworkspace` (NOT `Runner.xcodeproj` — pods
   break the bare project).

2. **File → New → Target… → iOS → Share Extension**.
   - Product Name: `ShareExtension`
   - Bundle Identifier: `com.johnsondigital.loadout.ShareExtension`
   - Embed in Application: `Runner`
   - Language: Swift
   - Project: Runner

3. Replace the auto-generated `ShareViewController.swift` with the
   minimal stub the plugin expects. The plugin reads incoming text
   off the system extension context and forwards it through the
   App Group container to the main app, so the controller body is
   essentially boilerplate. Use this exactly:

   ```swift
   import UIKit
   import Social
   import MobileCoreServices
   import share_handler_ios

   class ShareViewController: ShareHandlerIosViewController {
       override func viewDidLoad() {
           super.viewDidLoad()
           appGroupId = "group.com.johnsondigital.loadout"
       }
   }
   ```

   (The `share_handler_ios` import line resolves once Pods install
   the plugin's iOS module — see step 7.)

4. Configure the extension's `Info.plist` so it advertises that it
   accepts plain text + URLs (covers Notes, OneNote, Word-on-iOS,
   Safari, Mail, etc.). Replace the `NSExtension` dict with:

   ```xml
   <key>NSExtension</key>
   <dict>
       <key>NSExtensionAttributes</key>
       <dict>
           <key>NSExtensionActivationRule</key>
           <dict>
               <key>NSExtensionActivationSupportsText</key>
               <true/>
               <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
               <integer>1</integer>
           </dict>
       </dict>
       <key>NSExtensionMainStoryboard</key>
       <string>MainInterface</string>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.share-services</string>
   </dict>
   ```

5. **App Group entitlement** (both targets).
   - Runner: Signing & Capabilities → + Capability → App Groups →
     check `group.com.johnsondigital.loadout` (already provisioned
     for the watch app per CLAUDE.md § 15; reuse it).
   - ShareExtension: same — Signing & Capabilities → + Capability
     → App Groups → check the same group.

   If the group isn't listed, click the small refresh icon next to
   the App Groups list (Xcode pulls from the developer portal); if
   it's still missing, provision it at developer.apple.com →
   Identifiers → App Groups → register
   `group.com.johnsondigital.loadout`.

6. **Deployment target.** Set `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
   on the ShareExtension target Build Settings to match Runner
   (CLAUDE.md § 8). Newer is fine; older breaks the Pod link.

7. **Podfile** — add the Share Extension target so CocoaPods links
   the plugin's iOS module into it. In `ios/Podfile`, BELOW the
   existing `target 'Runner' do … end` block, add:

   ```ruby
   target 'ShareExtension' do
     use_frameworks!
     pod 'share_handler_ios', :path => '../.symlinks/plugins/share_handler_ios/ios'
   end
   ```

   Then `cd ios && pod install`.

8. **Verify.** Run the app on a real iOS device (the iOS simulator
   doesn't expose third-party share extensions for testing). Open
   Apple Notes, type a recipe, tap Share. Scroll the row of app
   icons until you see LoadOut (you may need to tap **More** → toggle
   LoadOut on the first time). Tap LoadOut. The Flutter app should
   foreground into the recipe review screen with your note text
   pre-parsed in the form.

## Things that break this silently

- Forgetting to add the App Group to BOTH targets. The extension
  will receive the share, write into a different container than
  the one the main app reads, and the text will quietly never land.
- Mis-typed `appGroupId` in `ShareViewController.swift`. Same
  failure mode: text vanishes between extension and app.
- Skipping the `pod install` step. The build compiles via Flutter
  but the extension target is missing the plugin and crashes on
  first share.
- Setting `IPHONEOS_DEPLOYMENT_TARGET` lower than 15.0. The
  CocoaPods install step warns then fails the Pod link.

## What stays in source control

- This README.
- (Eventually) a checked-in `ShareExtension/ShareViewController.swift`
  + `Info.plist` once the operator has run the wizard once and we
  can stabilise the file layout, mirroring the watch-app pattern
  documented in CLAUDE.md § 15. Until then those files live only
  inside the operator's local Xcode workspace.

## Companion changes already merged

- `pubspec.yaml` declares `share_handler: ^0.0.25`.
- `lib/services/share_handler_service.dart` is the Dart-side
  listener. Started from `_DisclaimerGate.initState`.
- `android/app/src/main/AndroidManifest.xml` carries the
  `<intent-filter>` for `ACTION_SEND` + `text/plain`, which is the
  Android equivalent of the Share Extension. Android works without
  any additional setup.
- `lib/screens/onboarding/import_sources_screen.dart`'s "Apple
  Notes" card teaches the user how to invoke the share sheet.
