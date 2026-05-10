// FILE: android/wear/src/main/java/com/johnsondigital/loadout/wear/screens/FirearmGlanceScreen.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// `@Composable` for the Firearm Glance tab on the Wear OS LoadOut
// companion. Reads `WatchAppState.firearmGlance` and renders a
// glanceable card showing:
//
//   * The currently-selected firearm's name (large, bold).
//   * Manufacturer / model + caliber on a second line, when present.
//   * A barrel-life summary block:
//       - "shots fired" counter on the left.
//       - "shots remaining" counter on the right (or "no budget set"
//         when the firearm has no `barrelLifeShots` configured).
//   * Empty state when no firearm has been pushed by the phone.
//
// Public surface:
//   * `@Composable fun FirearmGlanceScreen()` — the screen body.
//     Hosted by `MainActivity` as a navigation destination.
//
// Private composables:
//   * `Populated(snap)` — populated layout.
//   * `BarrelLifeBlock(...)` — the shot counter columns at the bottom.
//   * `EmptyState()` — fallback when no firearm has arrived.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// CLAUDE.md §15 reserves `firearm_glance` as a phone → watch payload.
// The phone's firearm form computes barrel-life telemetry (`shotsFired
// / barrelLifeShots`) and pushes a snapshot whenever the active
// firearm changes. The watch surfaces this on a dedicated page so a
// shooter mid-stage can confirm "this is the right rifle" and see at
// a glance how much barrel they have left.
//
// Lives on its own page rather than being merged into the DOPE banner
// because barrel life isn't always interesting — a shooter trying out
// a new load doesn't care about it; a competitor counting down to a
// rebarrel does. Putting it on a swipeable page keeps the DOPE page
// clean for users who never want to see the counter.
//
// (For Compose newcomers: this is a stateless composable — it reads
// global state from `WatchAppState` and renders. Composables that
// only display state get to be `@Composable fun()` with no
// arguments; ones that mutate state typically take callback lambdas
// or a stateful collaborator like `motion: MotionDetector`.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **No-placeholder rule applies here too.** When the phone has
//    never pushed a `firearm_glance` payload — or has pushed one with
//    no `barrelLifeShots` set — we show "no budget set" instead of
//    fabricating "5,000 shots remaining" or rendering "0 / 0 shots".
//    Same precision-tooling instinct as the DOPE empty state.
//
// 2. **`remainingShots` is computed phone-side.** We don't recompute
//    `barrelLifeShots - shotsFired` on the watch. The phone might be
//    using a custom barrel-life heuristic the watch doesn't know
//    about (e.g. a barrel that's "burning out" early shifts the
//    effective ceiling down 5%). Trusting the phone's number keeps
//    the math single-sourced.
//
// 3. **Color choices are deliberate.** `MaterialTheme.colors.primary`
//    for the firearm name signals "this is the active selection."
//    The remaining-shots counter goes red below 200 to flag a barrel
//    nearing end-of-life — the threshold is hand-tuned and could
//    move per-cartridge in a future revision (a .22 LR has a
//    different barrel life than a 6.5 PRC), but a single red
//    threshold is good enough for v1.
//
// 4. **Long firearm names are ellipsised.** A 24-character custom
//    name like "Tikka T3X 24" 6.5 PRC suppressed barrel" needs to
//    render on a 1.4" round face; `maxLines = 1` plus
//    `TextOverflow.Ellipsis` is the standard Wear truncation idiom.
//    If the user really wants the full name, the phone's firearms
//    list still has it.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `MainActivity.kt` — hosts this composable as one of the
//   `LoadOutWearRoot` pages.
// - `state/WatchAppState.kt` — read via `collectAsState()` for the
//   `firearmGlance` StateFlow.
// - `bridge/Payloads.kt` — defines `FirearmGlanceSnapshot`.
//
// This file ships on a separate Gradle sub-project (`:wear`), not in
// the main `:app` module.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure render off observable state.

package com.johnsondigital.loadout.wear.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.johnsondigital.loadout.wear.bridge.FirearmGlanceSnapshot
import com.johnsondigital.loadout.wear.state.WatchAppState

/**
 * Glanceable firearm summary + barrel-life counter. Reads
 * [WatchAppState.firearmGlance] and renders the most recent
 * `firearm_glance` payload pushed from the phone.
 */
@Composable
fun FirearmGlanceScreen() {
    val snapshot by WatchAppState.firearmGlance.collectAsState()
    val snap = snapshot
    if (snap == null) {
        EmptyFirearm()
        return
    }
    Populated(snap)
}

@Composable
private fun Populated(snap: FirearmGlanceSnapshot) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
    ) {
        Text(
            text = "ACTIVE FIREARM",
            fontSize = 8.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colors.onBackground,
        )
        Text(
            text = snap.name,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colors.primary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
        // Sub-line: manufacturer/model + caliber. Suppressed entirely
        // when neither is available so we don't render an empty bar.
        val subParts = mutableListOf<String>()
        snap.manufacturerModel?.let { subParts += it }
        snap.caliber?.let { subParts += it }
        if (subParts.isNotEmpty()) {
            Text(
                text = subParts.joinToString(" · "),
                fontSize = 9.sp,
                color = MaterialTheme.colors.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(4.dp))

        BarrelLifeBlock(
            shotsFired = snap.shotsFired,
            barrelLife = snap.barrelLifeShots,
            remaining = snap.remainingShots,
        )
    }
}

@Composable
private fun BarrelLifeBlock(
    shotsFired: Int?,
    barrelLife: Int?,
    remaining: Int?,
) {
    if (shotsFired == null && barrelLife == null) {
        Text(
            text = "No barrel-life data",
            fontSize = 9.sp,
            color = MaterialTheme.colors.onBackground,
            textAlign = TextAlign.Center,
        )
        return
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = shotsFired?.toString() ?: "—",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "FIRED",
                fontSize = 8.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colors.onBackground,
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            // Coloring: red when remaining < 200 (final 200 rounds of
            // a typical 6.5 PRC barrel — exactly when a competitor
            // wants the warning), white otherwise. The threshold is
            // hand-picked for v1 — see file header.
            val remainingColor: Color = when {
                remaining == null -> MaterialTheme.colors.onBackground
                remaining < 200 -> Color(0xFFFF5252)
                else -> Color.White
            }
            Text(
                text = remaining?.toString() ?: "—",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = remainingColor,
            )
            Text(
                text = if (barrelLife != null) "REMAINING" else "NO BUDGET",
                fontSize = 8.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colors.onBackground,
            )
        }
    }
}

@Composable
private fun EmptyFirearm() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "Pick a Firearm on Phone",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "Active firearm summary will appear here.",
            fontSize = 9.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colors.onBackground,
        )
    }
}
