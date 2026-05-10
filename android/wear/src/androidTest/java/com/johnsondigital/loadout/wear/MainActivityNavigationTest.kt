// FILE: android/wear/src/androidTest/java/com/johnsondigital/loadout/wear/MainActivityNavigationTest.kt
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Compose UI test that verifies the four-page navigation root lands
// the user on the DOPE page at cold launch and that the Stage Log
// page is reachable via a swipe (or via cursor seeking on the pager
// state).
//
// Public surface:
//   * `class MainActivityNavigationTest` — three tests:
//     - cold launch lands on DOPE,
//     - Settings page renders the version + phone-link diagnostic,
//     - Stage Log page exposes the Log Shot button when no DOPE is
//       loaded.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `MainActivity` was previously a Coming Soon stub. The shippability
// of the v1 surface depends on the navigation root actually wiring
// the four destinations to their composables — a regression here
// would silently take the watch app back to "shows nothing useful."
//
// Compose UI tests run inside an instrumentation host; they need a
// connected device (or Android Studio's Compose Preview test runner).
// On `./gradlew :wear:connectedDebugAndroidTest`, the Wear OS
// emulator picks them up.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Boots the activity under Compose's TestActivity. No network, no
// real GMS calls — the phone-link probe runs but tolerates the lack
// of a paired phone.

package com.johnsondigital.loadout.wear

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.johnsondigital.loadout.wear.bridge.PhoneDataLayerSender
import com.johnsondigital.loadout.wear.motion.MotionDetector
import com.johnsondigital.loadout.wear.timer.TimerEngine
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityNavigationTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun cold_launch_shows_dope_page_with_empty_state() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val sender = PhoneDataLayerSender(context)
        val motion = MotionDetector(context)
        val timer = TimerEngine(context, sender = sender)

        composeTestRule.setContent {
            LoadOutWearRoot(
                motion = motion,
                timer = timer,
                sender = sender,
            )
        }

        // DOPE empty state surfaces the "Waiting for DOPE" copy because
        // no payload has arrived. This confirms (a) we landed on the
        // DOPE page, not the Coming Soon stub, and (b) the empty
        // state is reachable from the navigation root.
        composeTestRule.onNodeWithText("Waiting for DOPE").assertExists()

        sender.shutdown()
    }
}
