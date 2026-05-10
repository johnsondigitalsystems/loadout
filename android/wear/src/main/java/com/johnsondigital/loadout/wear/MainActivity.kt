// FILE: android/wear/src/main/java/com/johnsondigital/loadout/wear/MainActivity.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Entry point for the LoadOut Wear OS companion. Hosts the four-page
// navigation root and owns the lifecycles of the singletons every screen
// shares (`MotionDetector`, `TimerEngine`, `PhoneDataLayerSender`).
//
// Public surface:
//   * `class MainActivity : ComponentActivity()` — the launcher activity.
//     `onCreate` instantiates the engines, polls the phone-link state on
//     a 3-second cadence, and renders `LoadOutWearRoot`. `onDestroy`
//     tears the sender executor + engines down.
//   * `@Composable LoadOutWearRoot(...)` — the navigation root. Hosts a
//     `HorizontalPager` over the four feature pages (Timer, DOPE, Stage
//     Log, Settings), with a `HorizontalPageIndicator` overlaid at the
//     bottom edge of the watch face. Wear OS users swipe horizontally
//     to flip between pages — this is the same idiom watchOS users get
//     from the parent's `TabView`.
//   * `@Composable AppPage(index)` — dispatches the four pages by index
//     so the pager can defer page composition until needed.
//
// The activity does NOT create or persist `WatchAppState` directly —
// `WatchAppState` is a process-singleton, populated by the
// `bridge.PhoneDataLayerListener` service when the phone publishes a
// payload. Both the activity and the listener share the same process
// when the activity is open, so the screens see snapshots immediately.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Every Wear OS app has exactly one `Activity` subclass that the launcher
// targets. Splitting the activity from the screens (which live in
// `screens/`) lets us swap in a different navigation host without
// touching the feature composables; the screens stay testable in
// isolation.
//
// We construct the heavy singletons HERE rather than in a global
// `Application` subclass because:
//   1. They each take a `Context` and `MotionDetector`/`TimerEngine`
//      both extend `ViewModel` — `ViewModelProvider` would let us
//      lifecycle-scope them, but for a single-activity Wear app the
//      `MainActivity` lifetime IS the process lifetime, so direct
//      ownership is just as correct and avoids the `ViewModelProvider`
//      ceremony.
//   2. `PhoneDataLayerSender.shutdown()` MUST run on `onDestroy` to
//      release the single-thread executor; an `Application`-scoped
//      lifecycle would never see a shutdown signal.
//
// (For Compose newcomers: `setContent { ... }` installs a Compose root
// inside the activity. Everything inside that block is declarative — it
// re-runs whenever any `mutableStateOf` / `StateFlow` it reads emits
// a new value. The block is not a one-shot; treat it as a description
// of the UI that's continuously evaluated.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`HorizontalPager` is foundation-pager, not wear-pager.** Wear OS
//    Compose 1.3.x doesn't ship a wear-tuned pager yet — we use the
//    foundation `HorizontalPager` and pair it with Wear's
//    `HorizontalPageIndicator`. Watch out: the foundation pager assumes
//    a phone-sized viewport for some defaults; we pin the page size to
//    `PageSize.Fill` so each page exactly fills the watch face.
//
// 2. **`rememberPagerState(initialPage = 1)` lands the user on DOPE.**
//    DOPE is the screen the shooter looks at most — landing them there
//    on cold launch saves a swipe. The `initialPage` MUST be set inside
//    `rememberPagerState` (not by mutating `currentPage` afterwards),
//    otherwise the pager momentarily shows page 0 then animates to
//    page 1.
//
// 3. **Phone-link polling runs on a coroutine.** GMS's `NodeClient`
//    has no `Flow` API — only `Task<List<Node>>`. We use a
//    `LaunchedEffect(Unit)` in the root composable to poll every 3 s
//    and update a `mutableStateOf<PhoneLinkState>`. 3 s is a deliberate
//    trade-off: faster polls would burn battery; slower polls would
//    leave the Settings diagnostic stale.
//
// 4. **`MotionDetector.applySensitivity` runs on every active-load
//    update.** When the phone first opens after the watch app is
//    installed, it pushes `shot_capture_sensitivity` along with
//    `active_load`. The `LaunchedEffect(sensitivity)` in `StageLogScreen`
//    is what consumes the wire value; the activity doesn't have to
//    intervene.
//
// 5. **`TimerEngine` is a `ViewModel` but we instantiate it directly.**
//    Normally you'd use `viewModels { factory }`. We don't — the
//    engine's `viewModelScope` works whether or not it was retrieved
//    via the framework, and the tighter coupling makes the
//    `PhoneDataLayerSender` injection cleaner. If we ever needed the
//    engine to survive activity recreation (Wear OS doesn't rotate, so
//    we don't), we'd switch to the framework `ViewModelProvider`.
//
// 6. **`Theme.DeviceDefault` is intentionally not Material 3.** Wear
//    OS Compose ships with `MaterialTheme` (Material 2-flavoured)
//    appropriate for round watch faces. The activity sets up the wear
//    `MaterialTheme` inside `setContent`; the manifest's
//    `Theme.DeviceDefault` is the host theme for the activity window
//    (window background, system UI) and is correct as-is.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `AndroidManifest.xml` — registers the activity as the app launcher.
// - All `screens/*` composables — passed the `MotionDetector`,
//   `TimerEngine`, and `PhoneDataLayerSender` instances created here.
// - `state/WatchAppState.kt` — read for snapshots; the activity itself
//   does not write to it (the listener service does).
//
// This file ships on a separate Gradle sub-project (`:wear`), not in
// the main `:app` module.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Constructs `PhoneDataLayerSender`, which holds GMS client refs.
//   Released in `onDestroy` via `sender.shutdown()`.
// - Constructs `MotionDetector` (registers no sensors yet — Stage Log
//   does that on first frame).
// - Constructs `TimerEngine` (no timer running yet — engine is idle on
//   construction).
// - Polls the Wearable Data Layer for phone-link state every 3 s while
//   the activity is in composition. Stops automatically when the
//   composition leaves.
// - No HTTP, no Firebase, no analytics. Privacy contract from
//   CLAUDE.md §13/§15.

package com.johnsondigital.loadout.wear

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Wearable
import com.johnsondigital.loadout.wear.bridge.PhoneDataLayerSender
import com.johnsondigital.loadout.wear.motion.MotionDetector
import com.johnsondigital.loadout.wear.screens.DopeScreen
import com.johnsondigital.loadout.wear.screens.FirearmGlanceScreen
import com.johnsondigital.loadout.wear.screens.SettingsScreen
import com.johnsondigital.loadout.wear.screens.StageLogScreen
import com.johnsondigital.loadout.wear.screens.TimerScreen
import com.johnsondigital.loadout.wear.timer.TimerEngine
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers

/**
 * Phone-link diagnostic state surfaced on the Settings screen and
 * available to any future feature that wants to gate behaviour on
 * connectivity. Not user-facing branding — keep the strings descriptive,
 * not branded.
 */
enum class PhoneLinkState {
    /** Initial state — the link probe hasn't run yet. */
    UNKNOWN,

    /** No paired phone is currently visible to GMS. */
    NOT_PAIRED,

    /**
     * A phone is paired but the LoadOut phone app hasn't advertised
     * the `loadout_phone_companion` capability — meaning the app isn't
     * installed, or hasn't run since pairing.
     */
    APP_NOT_INSTALLED,

    /**
     * A phone is paired AND has the LoadOut app installed, but isn't
     * currently reachable (Bluetooth dropped, phone rebooting, etc.).
     */
    NOT_REACHABLE,

    /**
     * Bluetooth is up, phone has the LoadOut app, the watch can talk
     * to the phone right now.
     */
    REACHABLE,
}

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "MainActivity"

        /** Capability the phone-side `WatchBridge` advertises. */
        const val PHONE_CAPABILITY = "loadout_phone_companion"

        /**
         * How often the root composable re-probes the phone-link state
         * (ms). 3 s is a deliberate trade-off between battery and the
         * Settings diagnostic going stale. Internal-but-not-private so
         * the `LaunchedEffect` in the root composable can read it
         * without needing a passthrough function.
         */
        const val PHONE_LINK_POLL_MS = 3000L

        /** Page indices used by the pager. Matches `AppPage` switch. */
        const val PAGE_TIMER = 0
        const val PAGE_DOPE = 1
        const val PAGE_STAGE_LOG = 2
        const val PAGE_FIREARM = 3
        const val PAGE_SETTINGS = 4
        const val PAGE_COUNT = 5
    }

    private lateinit var sender: PhoneDataLayerSender
    private lateinit var motion: MotionDetector
    private lateinit var timer: TimerEngine

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sender = PhoneDataLayerSender(applicationContext)
        motion = MotionDetector(applicationContext)
        timer = TimerEngine(applicationContext, sender = sender)

        setContent {
            MaterialTheme {
                LoadOutWearRoot(
                    motion = motion,
                    timer = timer,
                    sender = sender,
                )
            }
        }
    }

    override fun onDestroy() {
        // Release GMS executor BEFORE the activity dies; otherwise the
        // single-thread executor sits holding the GMS callback handles
        // until the JVM clears them, which can starve the next launch.
        sender.shutdown()
        super.onDestroy()
    }
}

/**
 * Root navigation composable. Hosts the four feature pages and the
 * Settings page in a horizontal pager, with the Wear-OS page indicator
 * overlay along the bottom edge.
 *
 * Lifts the phone-link probe up here (instead of inside Settings) so
 * the indicator dot we'd add to feature pages later — for "Phone
 * disconnected" warnings — has a single source of truth.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun LoadOutWearRoot(
    motion: MotionDetector,
    timer: TimerEngine,
    sender: PhoneDataLayerSender,
) {
    val pagerState = rememberPagerState(
        initialPage = MainActivity.PAGE_DOPE,
        pageCount = { MainActivity.PAGE_COUNT },
    )

    var phoneLink by remember { mutableStateOf(PhoneLinkState.UNKNOWN) }
    val context = androidx.compose.ui.platform.LocalContext.current

    // Poll the GMS capability client every 3 s while the root is in
    // composition. The probe is two queries chained: "any node has the
    // capability?" then "is one of those nodes reachable?".
    LaunchedEffect(Unit) {
        val capabilityClient = Wearable.getCapabilityClient(context)
        while (true) {
            phoneLink = withContext(Dispatchers.IO) {
                probePhoneLink(capabilityClient)
            }
            delay(MainActivity.PHONE_LINK_POLL_MS)
        }
    }

    Scaffold(
        timeText = { TimeText() },
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                pageSize = PageSize.Fill,
            ) { pageIndex ->
                AppPage(
                    pageIndex = pageIndex,
                    motion = motion,
                    timer = timer,
                    sender = sender,
                    phoneLink = phoneLink,
                )
            }

            HorizontalPageIndicator(
                pageIndicatorState = object : PageIndicatorState {
                    override val pageOffset: Float
                        get() = pagerState.currentPageOffsetFraction
                    override val selectedPage: Int
                        get() = pagerState.currentPage
                    override val pageCount: Int
                        get() = MainActivity.PAGE_COUNT
                },
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = 4.dp),
            )
        }
    }
}

/**
 * Dispatches the page index to the right feature composable. Each
 * branch only mounts when the pager actually scrolls into it, so the
 * Stage Log accelerometer (for example) doesn't run while the user is
 * looking at the Timer page.
 */
@Composable
fun AppPage(
    pageIndex: Int,
    motion: MotionDetector,
    timer: TimerEngine,
    sender: PhoneDataLayerSender,
    phoneLink: PhoneLinkState,
) {
    when (pageIndex) {
        MainActivity.PAGE_TIMER -> TimerScreen(engine = timer)
        MainActivity.PAGE_DOPE -> DopeScreen()
        MainActivity.PAGE_STAGE_LOG -> StageLogScreen(motion = motion, sender = sender)
        MainActivity.PAGE_FIREARM -> FirearmGlanceScreen()
        MainActivity.PAGE_SETTINGS -> SettingsScreen(phoneLink = phoneLink, motion = motion)
        else -> {
            // Should be unreachable — `PAGE_COUNT` matches the cases.
            Log.w("MainActivity", "AppPage: unexpected page index $pageIndex")
        }
    }
}

/**
 * Synchronous phone-link probe. Runs on the IO dispatcher because both
 * `Tasks.await` calls block.
 *
 * Returns the most accurate state we can determine in two queries:
 *   - All-nodes query: nothing back ⇒ `NOT_PAIRED`
 *   - Reachable-nodes query: nothing back ⇒ either `APP_NOT_INSTALLED`
 *     (we have all-nodes but no reachable ones with the capability) or
 *     `NOT_REACHABLE` (depending on whether the all-nodes query
 *     surfaced anyone with the capability).
 */
private fun probePhoneLink(capabilityClient: CapabilityClient): PhoneLinkState {
    return try {
        val all = Tasks.await(
            capabilityClient.getCapability(
                "loadout_phone_companion",
                CapabilityClient.FILTER_ALL,
            )
        ).nodes
        if (all.isEmpty()) {
            // No node EVER advertised the capability. Could be unpaired
            // entirely, or the phone is paired but the LoadOut app has
            // never run. From the watch's side these look identical —
            // both surfaces as "phone app not detected". We use
            // `NOT_PAIRED` because that's the more common case for a
            // brand-new install.
            return PhoneLinkState.NOT_PAIRED
        }
        val reachable = Tasks.await(
            capabilityClient.getCapability(
                "loadout_phone_companion",
                CapabilityClient.FILTER_REACHABLE,
            )
        ).nodes
        if (reachable.isEmpty()) {
            PhoneLinkState.NOT_REACHABLE
        } else {
            PhoneLinkState.REACHABLE
        }
    } catch (t: Throwable) {
        // GMS occasionally throws on cold-start before the wearable
        // service has finished bootstrapping. Treat the failure as
        // "we don't know yet" rather than escalating it as an error;
        // the next poll cycle will retry.
        Log.d("MainActivity", "probePhoneLink: ${t.message}")
        PhoneLinkState.UNKNOWN
    }
}
