// FILE: android/wear/src/test/java/com/johnsondigital/loadout/wear/PayloadsTest.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// JVM unit tests for the JSON ↔ Kotlin parsers in
// `bridge/Payloads.kt`. Validates:
//
//   * `DopeRow.fromJson` round-trips happy-path values, returns null
//     on missing required keys.
//   * `DopeSnapshot.fromJson` decodes a complete payload (header +
//     rows), preserves optional `pn` / `fn` when present and yields
//     null when absent, and tolerates an empty `rows` array.
//   * `ActiveLoadSnapshot.fromJson` handles missing optional fields
//     (powder, bullet weight) without coercing them to 0.
//   * `FirearmGlanceSnapshot.fromJson` decodes barrel-life telemetry,
//     preserving the phone-computed `remainingShots` rather than
//     recomputing.
//
// Privacy: no I/O, no network, runs on the JVM.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The wire format is shared with two other parsers (Dart + Swift); a
// single typo in the watch-side decoder would silently corrupt every
// inbound payload from the phone. These tests catch that on
// `./gradlew :wear:test` so the failure shows up in code review, not
// at the line.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Runs under Robolectric so the `org.json.JSONObject` implementation
// is available on the JVM classpath. (Android's `android.jar` stubs
// include `org.json` at compile time but not at runtime; without
// Robolectric the tests would throw `RuntimeException: Stub!` on
// every `JSONObject(...)` construction.)

package com.johnsondigital.loadout.wear

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.johnsondigital.loadout.wear.bridge.ActiveLoadSnapshot
import com.johnsondigital.loadout.wear.bridge.DopeRow
import com.johnsondigital.loadout.wear.bridge.DopeSnapshot
import com.johnsondigital.loadout.wear.bridge.FirearmGlanceSnapshot
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [33])
class PayloadsTest {

    // ---- DopeRow ------------------------------------------------------------

    @Test
    fun dopeRow_decodes_happy_path() {
        val obj = JSONObject(
            """{"r":500,"u":1.6,"w":0.4,"v":2510.0,"t":0.65}"""
        )
        val row = DopeRow.fromJson(obj)
        assertNotNull(row)
        assertEquals(500, row!!.rangeYd)
        assertEquals(1.6, row.dropMil, 0.0001)
        assertEquals(0.4, row.windMil, 0.0001)
        assertEquals(2510.0, row.velocityFps, 0.0001)
        assertEquals(0.65, row.timeOfFlightSec, 0.0001)
    }

    @Test
    fun dopeRow_returns_null_when_required_keys_missing() {
        val obj = JSONObject("""{"r":100}""")
        assertNull(DopeRow.fromJson(obj))
    }

    @Test
    fun dopeRow_returns_null_on_wrong_types() {
        val obj = JSONObject(
            """{"r":"five hundred","u":1.6,"w":0.4,"v":2500.0,"t":0.65}"""
        )
        assertNull(DopeRow.fromJson(obj))
    }

    // ---- DopeSnapshot -------------------------------------------------------

    @Test
    fun dopeSnapshot_decodes_full_payload() {
        val json = """
            {
              "cart": "6.5 Creedmoor",
              "bgr": 140.0,
              "bn": "ELD-M",
              "mv": 2710.0,
              "z": 100,
              "ws": 8.0,
              "wd": 270.0,
              "dm": "G7",
              "bc": 0.328,
              "pn": "Match Profile",
              "fn": "Tikka T3X",
              "g": 1715126400000,
              "rows": [
                {"r":100,"u":0.0,"w":0.0,"v":2710.0,"t":0.13},
                {"r":500,"u":1.6,"w":0.4,"v":2510.0,"t":0.65}
              ]
            }
        """.trimIndent()
        val snap = DopeSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals("6.5 Creedmoor", snap!!.cartridgeName)
        assertEquals(140.0, snap.bulletGr, 0.0001)
        assertEquals("ELD-M", snap.bulletName)
        assertEquals(2710.0, snap.muzzleVelocityFps, 0.0001)
        assertEquals(100, snap.zeroRangeYd)
        assertEquals(8.0, snap.windSpeedMph, 0.0001)
        assertEquals(270.0, snap.windFromDeg, 0.0001)
        assertEquals("G7", snap.dragModel)
        assertEquals(0.328, snap.bc, 0.0001)
        assertEquals("Match Profile", snap.profileName)
        assertEquals("Tikka T3X", snap.firearmName)
        assertEquals(1715126400000L, snap.generatedAtMs)
        assertEquals(2, snap.rows.size)
        assertEquals(500, snap.rows[1].rangeYd)
    }

    @Test
    fun dopeSnapshot_optional_fields_yield_null_when_absent() {
        // Payload without `pn` / `fn` — should decode but with null
        // optional fields, not the literal string "null".
        val json = """
            {
              "cart": ".308 Win",
              "bgr": 168.0,
              "bn": "SMK",
              "mv": 2700.0,
              "z": 100,
              "dm": "G1",
              "bc": 0.450,
              "rows": []
            }
        """.trimIndent()
        val snap = DopeSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertNull(snap!!.profileName)
        assertNull(snap.firearmName)
        assertEquals(0, snap.rows.size)
    }

    @Test
    fun dopeSnapshot_returns_null_on_missing_required_fields() {
        // Missing `cart` — required.
        val json = """
            {
              "bgr": 168.0,
              "bn": "SMK",
              "mv": 2700.0,
              "z": 100,
              "dm": "G1",
              "bc": 0.450,
              "rows": []
            }
        """.trimIndent()
        assertNull(DopeSnapshot.fromJson(JSONObject(json)))
    }

    @Test
    fun dopeSnapshot_skips_malformed_rows_silently() {
        // Two rows; the first is malformed (missing `r`). The decoder
        // should drop the malformed one and keep the good one.
        val json = """
            {
              "cart": "6.5 CM",
              "bgr": 140.0,
              "bn": "ELD-M",
              "mv": 2710.0,
              "z": 100,
              "dm": "G7",
              "bc": 0.328,
              "rows": [
                {"u":0.0,"w":0.0,"v":2710.0,"t":0.13},
                {"r":500,"u":1.6,"w":0.4,"v":2510.0,"t":0.65}
              ]
            }
        """.trimIndent()
        val snap = DopeSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals(1, snap!!.rows.size)
        assertEquals(500, snap.rows[0].rangeYd)
    }

    // ---- ActiveLoadSnapshot -------------------------------------------------

    @Test
    fun activeLoad_decodes_full_payload() {
        val json = """
            {
              "n": "Match Load",
              "cart": "6.5 Creedmoor",
              "p": "H4350",
              "pgr": 41.5,
              "b": "ELD-M",
              "bgr": 140.0
            }
        """.trimIndent()
        val snap = ActiveLoadSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals("Match Load", snap!!.name)
        assertEquals("6.5 Creedmoor", snap.cartridgeName)
        assertEquals("H4350", snap.powderName)
        assertEquals(41.5, snap.powderChargeGr!!, 0.0001)
        assertEquals("ELD-M", snap.bulletName)
        assertEquals(140.0, snap.bulletWeightGr!!, 0.0001)
    }

    @Test
    fun activeLoad_handles_missing_optionals_as_null() {
        val json = """{"n":"Plinker","cart":".223 Rem"}"""
        val snap = ActiveLoadSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals("Plinker", snap!!.name)
        assertNull(snap.powderName)
        // Critical: missing pgr should be null, not 0.0.
        assertNull(snap.powderChargeGr)
        assertNull(snap.bulletName)
        assertNull(snap.bulletWeightGr)
    }

    @Test
    fun activeLoad_returns_null_when_name_missing() {
        // Required fields: `n` and `cart`. Missing `n` should fail.
        val json = """{"cart":".308 Win","p":"Varget","pgr":44.0}"""
        assertNull(ActiveLoadSnapshot.fromJson(JSONObject(json)))
    }

    // ---- FirearmGlanceSnapshot ----------------------------------------------

    @Test
    fun firearm_decodes_with_full_telemetry() {
        val json = """
            {
              "n": "Tikka T3X 24",
              "m": "Tikka T3X CTR",
              "c": "6.5 Creedmoor",
              "s": 1850,
              "bl": 3000,
              "r": 1150,
              "g": 1715126400000
            }
        """.trimIndent()
        val snap = FirearmGlanceSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals("Tikka T3X 24", snap!!.name)
        assertEquals("Tikka T3X CTR", snap.manufacturerModel)
        assertEquals("6.5 Creedmoor", snap.caliber)
        assertEquals(1850, snap.shotsFired)
        assertEquals(3000, snap.barrelLifeShots)
        assertEquals(1150, snap.remainingShots)
        assertEquals(1715126400000L, snap.generatedAtMs)
    }

    @Test
    fun firearm_handles_missing_barrel_life_budget() {
        // User has not configured `barrelLifeShots` on the phone — the
        // payload arrives with `s` but no `bl` / `r`. Decoder must not
        // fabricate either.
        val json = """{"n":"Glock 17","s":2400}"""
        val snap = FirearmGlanceSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals("Glock 17", snap!!.name)
        assertEquals(2400, snap.shotsFired)
        assertNull(snap.barrelLifeShots)
        assertNull(snap.remainingShots)
    }

    @Test
    fun firearm_returns_null_when_name_missing() {
        // Required field is `n`.
        val json = """{"m":"Tikka T3X","c":"6.5 Creedmoor","s":100}"""
        assertNull(FirearmGlanceSnapshot.fromJson(JSONObject(json)))
    }

    @Test
    fun firearm_preserves_phone_computed_remaining_when_below_zero() {
        // Phone may surface a negative remaining value to flag a
        // burned-out barrel. The watch should preserve the value
        // verbatim — the UI is what styles it red, the decoder
        // is value-neutral.
        val json = """{"n":"Old PRC","s":3200,"bl":3000,"r":-200}"""
        val snap = FirearmGlanceSnapshot.fromJson(JSONObject(json))
        assertNotNull(snap)
        assertEquals(-200, snap!!.remainingShots)
    }

    @Test
    fun all_decoders_return_null_on_completely_invalid_json() {
        // Sanity check: a numeric-only JSON object cannot satisfy any
        // of the four shapes.
        val obj = JSONObject("""{"unrelated":42}""")
        assertNull(DopeRow.fromJson(obj))
        assertNull(DopeSnapshot.fromJson(obj))
        assertNull(ActiveLoadSnapshot.fromJson(obj))
        assertNull(FirearmGlanceSnapshot.fromJson(obj))
    }

    @Test
    fun dopeSnapshot_default_generatedAt_falls_back_to_now() {
        // No `g` key — decoder should still succeed and stamp a
        // sensible "now-ish" timestamp.
        val json = """
            {
              "cart": ".308 Win",
              "bgr": 168.0,
              "bn": "SMK",
              "mv": 2700.0,
              "z": 100,
              "dm": "G1",
              "bc": 0.450,
              "rows": []
            }
        """.trimIndent()
        val before = System.currentTimeMillis()
        val snap = DopeSnapshot.fromJson(JSONObject(json))
        val after = System.currentTimeMillis()
        assertNotNull(snap)
        assertTrue(
            "generatedAtMs should be between $before and $after, was ${snap!!.generatedAtMs}",
            snap.generatedAtMs in before..after,
        )
    }
}
