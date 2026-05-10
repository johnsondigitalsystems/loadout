// FILE: android/wear/src/main/java/com/johnsondigital/loadout/wear/screens/DopeScreen.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// `@Composable` for the DOPE tab on the Wear OS LoadOut companion
// (Feature 2). Reads `WatchAppState` directly (via
// `.collectAsState()`) and renders, when a snapshot is available, a
// glanceable card with:
//
//   * Active-load banner: a single-line summary of the currently
//     pushed `active_load` payload (cartridge + bullet weight). Falls
//     back to "Pick a Load on Phone" when no active load has been
//     pushed.
//   * DOPE header: cartridge + bullet identity, ellipsised on overflow.
//   * Big numerals showing the current range in yards.
//   * Two columns: vertical "UP" hold and horizontal "WIND" hold,
//     both in mils.
//   * Prev / Next arrow buttons calling
//     `WatchAppState.previousRow()` / `nextRow()`.
//
// Public surface:
//   * `@Composable fun DopeScreen()` — the screen body. Hosted by
//     `MainActivity` as the second page in `LoadOutWearRoot`.
//
// Private composables:
//   * `ActiveLoadBanner(snap)` — top-of-screen badge summarising the
//     pushed active recipe; hides itself when no payload is present.
//   * `Populated(snap, row)` — populated DOPE state.
//   * `HoldColumn(label, value)` — small two-line column for UP/WIND.
//   * `EmptyState()` — "Waiting for DOPE — open Ballistics on your
//     phone." fallback when no snapshot has arrived.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// One of five feature screens hosted by `MainActivity.LoadOutWearRoot`.
// The DOPE card is the user's at-a-glance reference at the line —
// "what dial do I turn for this range?". Mirrors
// `ios/RunnerWatchApp/DopeView.swift`. Sits as the second page of the
// pager (the user's cold-launch landing page) because it's the screen
// they look at most.
//
// Reading directly from `WatchAppState` (rather than through a
// view-model) is appropriate here because the state is process-singleton
// and any composable that subscribes will recompose when it changes.
// Adding a view-model wrapper would just be ceremony.
//
// (For Compose newcomers: `androidx.wear.compose.material.*` is the
// Wear OS-tuned variant of Material widgets — buttons sized for
// fingertip taps on a small face, type scales appropriate for arm's
// length viewing. Use these instead of the phone Material set inside
// the `:wear` module.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Wear OS doesn't have a digital crown.** Apple Watch users
//    scroll DOPE rows with the crown; Wear OS Pixel Watch and
//    Galaxy Watch have a rotating bezel or side-button input but no
//    universal "crown" abstraction. We expose < / > buttons as the
//    minimum-viable navigation; rotary support could be added per-
//    device with `Modifier.onRotaryScrollEvent { ... }` later.
//
// 2. **`fillMaxWidth(0.4f)` and `0.7f` for buttons.** On a round
//    Wear face the corners are clipped; sizing buttons with
//    fractions ensures they stay inside the visible viewport. Hard
//    pixel widths would clip on smaller faces.
//
// 3. **`row` is computed with `.getOrNull(cursor) ?: snap.rows.first()`.**
//    The fallback handles the brief window between a new snapshot
//    landing and `WatchAppState.setDope` clamping the cursor. In
//    practice both happen on the same `runBlocking`-style update,
//    so the fallback is defensive — but cheap insurance.
//
// 4. **`MaterialTheme.colors.onBackground` — Wear's material has
//    different color tokens than phone Material 3.** Don't reach
//    for `MaterialTheme.colorScheme.onSurface` here; that's the
//    phone API. Wear uses `MaterialTheme.colors.*`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `MainActivity.kt` — hosts as the DOPE page in `LoadOutWearRoot`.
// - `state/WatchAppState.kt` — read via `collectAsState()`. The
//   listener service writes to it; this composable reacts. Both
//   `dopeSnapshot` and `activeLoad` are observed.
//
// This file ships on a separate Gradle sub-project (`:wear`), not in
// the main `:app` module.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Mutates `WatchAppState.rowCursor` via `nextRow()` / `previousRow()`
//   on button taps. No I/O, no audio.

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.johnsondigital.loadout.wear.bridge.ActiveLoadSnapshot
import com.johnsondigital.loadout.wear.bridge.DopeRow
import com.johnsondigital.loadout.wear.bridge.DopeSnapshot
import com.johnsondigital.loadout.wear.state.WatchAppState

/**
 * Glanceable DOPE card for Feature 2. Driven by [WatchAppState].
 *
 * The screen exposes < / > buttons for scrolling — Wear OS doesn't
 * have a digital crown, but devices with rotary input wired through
 * Compose's `RotaryScrollEvent` callback would extend this naturally.
 */
@Composable
fun DopeScreen() {
    val snapshot by WatchAppState.dopeSnapshot.collectAsState()
    val activeLoad by WatchAppState.activeLoad.collectAsState()
    val cursor by WatchAppState.rowCursor.collectAsState()

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Active-load banner sits ABOVE the DOPE card so a glance at
        // the watch tells the shooter both what they're shooting and
        // where to dial it. Hides itself when no payload is present
        // (per the project's no-placeholder rule — never invent a load
        // name the user didn't pick).
        ActiveLoadBanner(activeLoad)

        val snap = snapshot
        if (snap == null || snap.rows.isEmpty()) {
            EmptyState()
        } else {
            val row = snap.rows.getOrNull(cursor) ?: snap.rows.first()
            Populated(snap = snap, row = row)
        }
    }
}

@Composable
private fun ActiveLoadBanner(snap: ActiveLoadSnapshot?) {
    if (snap == null) {
        // No active load — the user hasn't picked a recipe on the phone
        // yet. Tell them where to fix it without faking any of the
        // ballistics-affecting fields.
        Text(
            text = "Pick a Load on Phone",
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colors.onBackground,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp, bottom = 2.dp),
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        return
    }
    // Compose a one-line summary: "Cartridge · 140 gr Bullet · 41.5 gr
    // Powder". Drop fields the phone didn't push so we don't render
    // empty units.
    val parts = mutableListOf<String>()
    parts += snap.cartridgeName
    val bulletGr = snap.bulletWeightGr
    val bulletName = snap.bulletName
    when {
        bulletGr != null && bulletName != null ->
            parts += "${"%.0f".format(bulletGr)} gr $bulletName"
        bulletName != null -> parts += bulletName
        bulletGr != null -> parts += "${"%.0f".format(bulletGr)} gr"
    }
    val powderGr = snap.powderChargeGr
    if (powderGr != null) {
        parts += "${"%.1f".format(powderGr)} gr ${snap.powderName ?: "powder"}"
    } else if (snap.powderName != null) {
        parts += snap.powderName
    }
    Text(
        text = parts.joinToString(" · "),
        fontSize = 9.sp,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colors.primary,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, bottom = 2.dp),
        textAlign = TextAlign.Center,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
    Spacer(modifier = Modifier.height(2.dp))
}

@Composable
private fun Populated(snap: DopeSnapshot, row: DopeRow) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
    ) {
        Text(
            text = "${snap.cartridgeName} · ${"%.0f".format(snap.bulletGr)} ${snap.bulletName}",
            fontSize = 10.sp,
            color = MaterialTheme.colors.onBackground,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "${row.rangeYd}",
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "YARDS",
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colors.onBackground,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            HoldColumn(label = "UP", value = row.dropMil)
            HoldColumn(label = "WIND", value = row.windMil)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { WatchAppState.previousRow() },
                modifier = Modifier.fillMaxWidth(0.4f),
                colors = ButtonDefaults.secondaryButtonColors(),
            ) { Text("<", fontSize = 14.sp) }
            Button(
                onClick = { WatchAppState.nextRow() },
                modifier = Modifier.fillMaxWidth(0.7f),
                colors = ButtonDefaults.secondaryButtonColors(),
            ) { Text(">", fontSize = 14.sp) }
        }
    }
}

@Composable
private fun HoldColumn(label: String, value: Double) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = "%.1f mil".format(value),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = label,
            fontSize = 8.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colors.onBackground,
        )
    }
}

@Composable
private fun EmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "Waiting for DOPE",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "Open Ballistics on your phone.",
            fontSize = 9.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colors.onBackground,
        )
    }
}
