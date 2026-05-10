// FILE: android/wear/src/test/java/com/johnsondigital/loadout/wear/WatchAppStateTest.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// JVM unit tests for the process-singleton `WatchAppState`. Verifies
// the cursor-clamp invariant after a new DOPE snapshot lands, the
// shot-count increment / clear path, and the `setActiveLoad` /
// `setFirearmGlance` setters.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The cursor-clamp logic is the singleton's most important invariant
// — `setDope(snap)` must clamp `rowCursor` if the new payload has
// fewer rows than the user was scrolled into, otherwise the DOPE
// composable would crash on `rows[cursor]`. Catching that here
// instead of in a Compose test keeps the bug local to the state
// holder.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Mutates the global `WatchAppState` singleton. `@Before` resets it
// between tests so each one starts from a known state.

package com.johnsondigital.loadout.wear

import com.johnsondigital.loadout.wear.bridge.ActiveLoadSnapshot
import com.johnsondigital.loadout.wear.bridge.DopeRow
import com.johnsondigital.loadout.wear.bridge.DopeSnapshot
import com.johnsondigital.loadout.wear.bridge.FirearmGlanceSnapshot
import com.johnsondigital.loadout.wear.state.WatchAppState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class WatchAppStateTest {

    @Before
    fun reset() {
        // Reset shared state so test order doesn't matter. The
        // singleton has no `clear()` — we drive it back to defaults
        // by calling its public surface.
        WatchAppState.clearShotCount()
        // Push an empty DOPE snapshot then advance cursor to 0; this
        // approximates "fresh launch".
        WatchAppState.setDope(emptyDope())
    }

    @Test
    fun setDope_clamps_cursor_when_new_snapshot_is_shorter() {
        WatchAppState.setDope(makeDope(rowCount = 10))
        // Scroll user 8 rows in.
        repeat(8) { WatchAppState.nextRow() }
        assertEquals(8, WatchAppState.rowCursor.value)

        // Phone pushes a shorter snapshot (e.g. user pruned distant
        // ranges). Cursor must clamp.
        WatchAppState.setDope(makeDope(rowCount = 4))
        assertEquals(3, WatchAppState.rowCursor.value)
    }

    @Test
    fun setDope_does_not_advance_cursor_when_new_snapshot_is_longer() {
        WatchAppState.setDope(makeDope(rowCount = 5))
        WatchAppState.nextRow()
        assertEquals(1, WatchAppState.rowCursor.value)

        // Push a snapshot with more rows. Cursor stays where it was.
        WatchAppState.setDope(makeDope(rowCount = 12))
        assertEquals(1, WatchAppState.rowCursor.value)
    }

    @Test
    fun nextRow_clamps_at_last_index() {
        WatchAppState.setDope(makeDope(rowCount = 3))
        repeat(10) { WatchAppState.nextRow() }
        assertEquals(2, WatchAppState.rowCursor.value)
    }

    @Test
    fun previousRow_clamps_at_zero() {
        WatchAppState.setDope(makeDope(rowCount = 3))
        WatchAppState.nextRow() // cursor = 1
        repeat(10) { WatchAppState.previousRow() }
        assertEquals(0, WatchAppState.rowCursor.value)
    }

    @Test
    fun nextRow_does_nothing_when_dope_empty() {
        WatchAppState.setDope(emptyDope())
        // Cursor was reset to 0 by the empty push.
        assertEquals(0, WatchAppState.rowCursor.value)
        WatchAppState.nextRow()
        assertEquals(0, WatchAppState.rowCursor.value)
    }

    @Test
    fun shotCount_increment_and_clear() {
        repeat(5) { WatchAppState.incrementShotCount() }
        assertEquals(5, WatchAppState.shotCount.value)
        WatchAppState.clearShotCount()
        assertEquals(0, WatchAppState.shotCount.value)
    }

    @Test
    fun setActiveLoad_publishes_to_stateflow() {
        val load = ActiveLoadSnapshot(
            name = "Match Load",
            cartridgeName = "6.5 Creedmoor",
            powderName = "H4350",
            powderChargeGr = 41.5,
            bulletName = "ELD-M",
            bulletWeightGr = 140.0,
        )
        WatchAppState.setActiveLoad(load)
        val current = WatchAppState.activeLoad.value
        assertNotNull(current)
        assertEquals("Match Load", current!!.name)
        assertEquals(41.5, current.powderChargeGr!!, 0.0001)
    }

    @Test
    fun setFirearmGlance_publishes_to_stateflow() {
        val firearm = FirearmGlanceSnapshot(
            name = "Tikka T3X 24",
            manufacturerModel = "Tikka T3X CTR",
            caliber = "6.5 Creedmoor",
            shotsFired = 1850,
            barrelLifeShots = 3000,
            remainingShots = 1150,
        )
        WatchAppState.setFirearmGlance(firearm)
        val current = WatchAppState.firearmGlance.value
        assertNotNull(current)
        assertEquals("Tikka T3X 24", current!!.name)
        assertEquals(1150, current.remainingShots)
    }

    @Test
    fun setShotCaptureSensitivity_round_trips() {
        WatchAppState.setShotCaptureSensitivity("high")
        assertEquals("high", WatchAppState.shotCaptureSensitivity.value)
        WatchAppState.setShotCaptureSensitivity("off")
        assertEquals("off", WatchAppState.shotCaptureSensitivity.value)
    }

    @Test
    fun currentRow_returns_null_when_empty() {
        WatchAppState.setDope(emptyDope())
        assertNull(WatchAppState.currentRow())
    }

    @Test
    fun currentRow_returns_indexed_row() {
        WatchAppState.setDope(makeDope(rowCount = 5))
        WatchAppState.nextRow()
        WatchAppState.nextRow()
        val row = WatchAppState.currentRow()
        assertNotNull(row)
        // makeDope() uses `(i + 1) * 100` so row index 2 → 300 yd.
        assertEquals(300, row!!.rangeYd)
    }

    // --- helpers -------------------------------------------------------------

    private fun emptyDope(): DopeSnapshot = DopeSnapshot(
        cartridgeName = "test",
        bulletGr = 0.0,
        bulletName = "x",
        muzzleVelocityFps = 0.0,
        zeroRangeYd = 0,
        windSpeedMph = 0.0,
        windFromDeg = 0.0,
        dragModel = "G1",
        bc = 0.0,
        profileName = null,
        firearmName = null,
        generatedAtMs = 0L,
        rows = emptyList(),
    )

    private fun makeDope(rowCount: Int): DopeSnapshot = DopeSnapshot(
        cartridgeName = "6.5 CM",
        bulletGr = 140.0,
        bulletName = "ELD-M",
        muzzleVelocityFps = 2710.0,
        zeroRangeYd = 100,
        windSpeedMph = 0.0,
        windFromDeg = 0.0,
        dragModel = "G7",
        bc = 0.328,
        profileName = null,
        firearmName = null,
        generatedAtMs = 0L,
        rows = List(rowCount) { i ->
            DopeRow(
                rangeYd = (i + 1) * 100,
                dropMil = i * 0.4,
                windMil = 0.0,
                velocityFps = 2710.0 - i * 50,
                timeOfFlightSec = i * 0.13,
            )
        },
    )
}
