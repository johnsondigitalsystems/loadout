// FILE: android/wear/src/main/java/com/johnsondigital/loadout/wear/screens/SettingsScreen.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// `@Composable` for the Settings / About tab on the Wear OS LoadOut
// companion. A small, scrollable, mostly-read-only diagnostics panel
// for the watch app. Sections, top to bottom:
//
//   * "About" — app name (LoadOut Wear) + version string + build code.
//   * "Phone Link" — a status row colored by `PhoneLinkState`:
//       - REACHABLE  → green dot + "Connected"
//       - NOT_REACHABLE → orange dot + "Phone unreachable"
//       - APP_NOT_INSTALLED / NOT_PAIRED → red dot + "Phone not paired"
//       - UNKNOWN → grey dot + "Checking…"
//   * "Shot Detection" — read-only display of the current
//     sensitivity preset (off / low / medium / high) plus a one-line
//     reminder that the preset is configured on the phone (per
//     CLAUDE.md §15).
//
// Public surface:
//   * `@Composable fun SettingsScreen(phoneLink, motion)` — the screen
//     body. Hosted by `MainActivity` as the fifth navigation page.
//
// Private composables:
//   * `Section(title, content)` — small section header + body.
//   * `LinkStatusRow(state)` — phone-link colored status row.
//   * `SensitivityRow(preset)` — read-only "Sensitivity: medium"
//     row.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The watch app has no user-tunable knobs by design — every setting
// that affects ballistics / shot capture lives on the phone (per
// CLAUDE.md §15 "the watch reflects whatever state the phone forwards
// to it"). What the user CAN benefit from on the watch is a quick
// diagnostic surface: "is my phone connected? what version am I
// running? what sensitivity did I set?".
//
// Without this screen, "phone not connected" would manifest as silent
// failure (DOPE doesn't update, shots don't log to the phone) and the
// user would have no way to confirm the cause without unpairing /
// repairing.
//
// (For Compose newcomers: composables can be passed enums and
// `ChangeNotifier`-style state holders directly — they'll re-render
// automatically when those values flip. Wear OS has its own
// `ScalingLazyColumn` for vertical lists, but for a 3-section
// diagnostics surface we just use a regular `Column` since the whole
// thing fits without scrolling on a normal watch face.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Status colors must contrast on a black watch face.** The dot
//    + label palette uses fully saturated greens / oranges / reds
//    (0xFF66BB6A, 0xFFFFA726, 0xFFFF5252) so the user can read the
//    state at arm's length in sunlight. Don't switch to themed
//    colors — Wear's MaterialTheme tokens are tuned for AMOLED
//    energy-saving, not for daylight legibility.
//
// 2. **The motion-detector preset is the watch's mirror, not its
//    truth.** `MotionDetector.sensitivity` reflects whatever the
//    phone last pushed via `shot_capture_sensitivity`, with
//    `SharedPreferences` as a survives-reboot cache. The watch is
//    NEVER the source of truth — that's why this screen renders the
//    preset name as plain text rather than a picker. Adding a picker
//    here would require duplicating the preset → threshold logic,
//    and the next phone push would silently overwrite the user's
//    choice anyway.
//
// 3. **Version number is read off `BuildConfig`.** We expose
//    `BuildConfig.VERSION_NAME` and `BuildConfig.VERSION_CODE` —
//    these come from `defaultConfig.versionName` /
//    `defaultConfig.versionCode` in `build.gradle.kts`. Don't
//    hand-code the version string here; that's a documented way to
//    ship an out-of-date number to the user.
//
// 4. **`Section` titles use Title Case per CLAUDE.md §0a.** "Phone
//    Link" not "Phone link"; "Shot Detection" not "Shot detection".
//    Body copy ("Configure on phone — Settings → Watch") uses
//    sentence case because it's a description, not a label.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `MainActivity.kt` — hosts this composable as one of the
//   `LoadOutWearRoot` pages.
// - `motion/MotionDetector.kt` — passed in for read-only sensitivity
//   display.
// - `MainActivity.PhoneLinkState` — passed in as the `phoneLink`
//   argument; the activity polls GMS every 3 seconds and updates the
//   value, the screen rerenders when it flips.
//
// This file ships on a separate Gradle sub-project (`:wear`), not in
// the main `:app` module.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure render; no taps mutate state on this screen.

package com.johnsondigital.loadout.wear.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.johnsondigital.loadout.wear.BuildConfig
import com.johnsondigital.loadout.wear.PhoneLinkState
import com.johnsondigital.loadout.wear.motion.MotionDetector
import com.johnsondigital.loadout.wear.motion.ShotCaptureSensitivity

/**
 * Settings / About panel for the Wear OS LoadOut companion. Read-only
 * surface — every adjustable preference lives on the phone per
 * CLAUDE.md §15.
 */
@Composable
fun SettingsScreen(
    phoneLink: PhoneLinkState,
    motion: MotionDetector,
) {
    val scrollState = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Section(title = "About") {
            Text(
                text = "LoadOut Wear",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "v${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                fontSize = 9.sp,
                color = MaterialTheme.colors.onBackground,
            )
        }

        Section(title = "Phone Link") {
            LinkStatusRow(phoneLink)
        }

        Section(title = "Shot Detection") {
            SensitivityRow(motion.sensitivity)
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "Configure on phone: Settings → Watch.",
                fontSize = 8.sp,
                color = MaterialTheme.colors.onBackground,
                textAlign = TextAlign.Center,
            )
        }

        // Privacy reminder — stays here (not the home page) so curious
        // users see it but it doesn't intrude on the at-the-line glance
        // surfaces.
        Text(
            text = "All transport is peer-to-peer. No HTTP, no analytics.",
            fontSize = 7.sp,
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = title,
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colors.primary,
        )
        content()
    }
}

@Composable
private fun LinkStatusRow(state: PhoneLinkState) {
    val (label, dot) = when (state) {
        PhoneLinkState.REACHABLE -> Pair("Connected", Color(0xFF66BB6A))
        PhoneLinkState.NOT_REACHABLE -> Pair("Phone Unreachable", Color(0xFFFFA726))
        PhoneLinkState.APP_NOT_INSTALLED -> Pair("App Not Installed", Color(0xFFFF5252))
        PhoneLinkState.NOT_PAIRED -> Pair("Phone Not Paired", Color(0xFFFF5252))
        PhoneLinkState.UNKNOWN -> Pair("Checking...", Color(0xFF9E9E9E))
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Spacer(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(dot),
        )
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun SensitivityRow(preset: ShotCaptureSensitivity) {
    val displayName = when (preset) {
        ShotCaptureSensitivity.OFF -> "Off"
        ShotCaptureSensitivity.LOW -> "Low"
        ShotCaptureSensitivity.MEDIUM -> "Medium"
        ShotCaptureSensitivity.HIGH -> "High"
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = "Sensitivity:",
            fontSize = 10.sp,
            color = MaterialTheme.colors.onBackground,
        )
        Text(
            text = displayName,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
