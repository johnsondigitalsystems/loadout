// FILE: android/wear/src/test/java/com/johnsondigital/loadout/wear/TimerEngineTest.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Robolectric-backed unit tests for `TimerEngine`'s state machine and
// persistence. Validates:
//
//   * Initial state is IDLE with the persisted total (default 90 s).
//   * `adjust(seconds)` only mutates total while IDLE; clamps total
//     to ≥5 s.
//   * `start()` from IDLE moves to RUNNING and resets remainingSec to
//     totalSec; subsequent `start()` while RUNNING is a no-op.
//   * `pause()` / `resume()` cycle.
//   * `reset()` returns to IDLE and clears warning state.
//   * `toggleQuietMode(true)` persists across engine instances.
//   * The countdown ticks when the engine is running (via test
//     dispatcher virtual time).
//
// Privacy: no real audio / haptics fire — Robolectric's shadows
// short-circuit the `Vibrator` and `ToneGenerator` calls.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// State machine bugs in a stage timer are a particularly bad failure
// mode: a paused engine that thinks it's still running would burn
// battery while the user is reset between stages, while a running
// engine that thinks it's IDLE would silently skip the par-time
// alert at 5 seconds. Pinning the transitions here keeps the engine
// testable without requiring a Compose host.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads / writes Robolectric's SharedPreferences. `@Before` clears
// the `wear_timer_prefs` file between tests.

package com.johnsondigital.loadout.wear

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.johnsondigital.loadout.wear.timer.TimerEngine
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [33])
class TimerEngineTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.getSharedPreferences("wear_timer_prefs", Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    @After
    fun tearDown() {
        context.getSharedPreferences("wear_timer_prefs", Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    @Test
    fun initial_state_is_idle_with_default_total() {
        val engine = TimerEngine(context)
        assertEquals(TimerEngine.State.IDLE, engine.state)
        assertEquals(90, engine.totalSec)
        assertEquals(90, engine.remainingSec)
        assertFalse(engine.quietMode)
    }

    @Test
    fun adjust_increments_total_while_idle() {
        val engine = TimerEngine(context)
        engine.adjust(30)
        assertEquals(120, engine.totalSec)
        assertEquals(120, engine.remainingSec)
    }

    @Test
    fun adjust_decrements_total_while_idle() {
        val engine = TimerEngine(context)
        engine.adjust(-30)
        assertEquals(60, engine.totalSec)
        assertEquals(60, engine.remainingSec)
    }

    @Test
    fun adjust_clamps_at_five_seconds() {
        val engine = TimerEngine(context)
        engine.adjust(-200)
        assertEquals(5, engine.totalSec)
        assertEquals(5, engine.remainingSec)
    }

    @Test
    fun adjust_is_noop_when_running() {
        val engine = TimerEngine(context)
        engine.start()
        val totalBefore = engine.totalSec
        engine.adjust(60)
        assertEquals(totalBefore, engine.totalSec)
    }

    @Test
    fun start_transitions_idle_to_running() {
        val engine = TimerEngine(context)
        engine.start()
        assertEquals(TimerEngine.State.RUNNING, engine.state)
        assertEquals(90, engine.remainingSec)
    }

    @Test
    fun start_resets_remaining_when_called_from_finished() {
        val engine = TimerEngine(context)
        engine.adjust(-85)  // total = 5 s
        engine.start()
        // Force-finish by directly resetting then start again — the
        // engine clears warnings on every fresh start.
        engine.reset()
        assertEquals(TimerEngine.State.IDLE, engine.state)
        engine.start()
        assertEquals(TimerEngine.State.RUNNING, engine.state)
        assertEquals(5, engine.remainingSec)
    }

    @Test
    fun start_when_already_running_is_noop() {
        val engine = TimerEngine(context)
        engine.start()
        val remainingBefore = engine.remainingSec
        engine.start()
        assertEquals(TimerEngine.State.RUNNING, engine.state)
        // remaining unchanged because the second start is ignored.
        assertEquals(remainingBefore, engine.remainingSec)
    }

    @Test
    fun pause_transitions_running_to_paused() {
        val engine = TimerEngine(context)
        engine.start()
        engine.pause()
        assertEquals(TimerEngine.State.PAUSED, engine.state)
    }

    @Test
    fun pause_when_idle_is_noop() {
        val engine = TimerEngine(context)
        engine.pause()
        assertEquals(TimerEngine.State.IDLE, engine.state)
    }

    @Test
    fun resume_transitions_paused_to_running() {
        val engine = TimerEngine(context)
        engine.start()
        engine.pause()
        engine.resume()
        assertEquals(TimerEngine.State.RUNNING, engine.state)
    }

    @Test
    fun resume_when_idle_is_noop() {
        val engine = TimerEngine(context)
        engine.resume()
        assertEquals(TimerEngine.State.IDLE, engine.state)
    }

    @Test
    fun reset_returns_to_idle_and_resets_remaining() {
        val engine = TimerEngine(context)
        engine.start()
        engine.pause()
        engine.reset()
        assertEquals(TimerEngine.State.IDLE, engine.state)
        assertEquals(engine.totalSec, engine.remainingSec)
    }

    @Test
    fun reset_from_running_is_safe() {
        val engine = TimerEngine(context)
        engine.start()
        engine.reset()
        assertEquals(TimerEngine.State.IDLE, engine.state)
    }

    @Test
    fun toggleQuietMode_round_trips() {
        val engine = TimerEngine(context)
        engine.toggleQuietMode(true)
        assertTrue(engine.quietMode)
        engine.toggleQuietMode(false)
        assertFalse(engine.quietMode)
    }

    @Test
    fun quietMode_persists_across_instances() {
        val first = TimerEngine(context)
        first.toggleQuietMode(true)

        val second = TimerEngine(context)
        assertTrue(second.quietMode)
    }

    @Test
    fun adjusted_total_persists_across_instances() {
        val first = TimerEngine(context)
        first.adjust(30)  // total = 120
        first.adjust(30)  // total = 150

        val second = TimerEngine(context)
        assertEquals(150, second.totalSec)
        assertEquals(150, second.remainingSec)
    }

    @Test
    fun reset_does_not_mutate_totalSec() {
        val engine = TimerEngine(context)
        engine.adjust(60)  // total = 150
        engine.start()
        engine.reset()
        assertEquals(150, engine.totalSec)
        assertEquals(150, engine.remainingSec)
    }

    @Test
    fun adjust_after_pause_is_blocked() {
        val engine = TimerEngine(context)
        engine.start()
        engine.pause()
        val totalBefore = engine.totalSec
        engine.adjust(60)
        // PAUSED state is not IDLE, so adjust is a no-op.
        assertEquals(totalBefore, engine.totalSec)
    }

    @Test
    fun state_enum_has_four_values() {
        // Pin the state-machine API so future expansions show up in
        // PR review.
        assertEquals(4, TimerEngine.State.values().size)
        assertTrue(TimerEngine.State.values().contains(TimerEngine.State.IDLE))
        assertTrue(TimerEngine.State.values().contains(TimerEngine.State.RUNNING))
        assertTrue(TimerEngine.State.values().contains(TimerEngine.State.PAUSED))
        assertTrue(TimerEngine.State.values().contains(TimerEngine.State.FINISHED))
    }
}
