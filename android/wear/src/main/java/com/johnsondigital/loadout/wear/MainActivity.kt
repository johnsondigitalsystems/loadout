package com.johnsondigital.loadout.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Entry point for the LoadOut Wear OS companion.
 *
 * At scaffolding stage this activity hosts a single Composable that shows
 * a "Coming Soon" message. The phone <-> watch transport (via the
 * [com.google.android.gms.wearable.Wearable] Data Layer API) is wired up
 * but not yet exposed to the UI; see [PhoneDataLayerListener] for where
 * future feature code should plug in.
 */
class MainActivity : ComponentActivity() {

    // Holds the most recent payload received from the phone. Once Data
    // Layer events are flowing this state is what the UI observes; for
    // now it stays null and the stub UI ignores it.
    private val phonePayload = MutableStateFlow<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ComingSoonScreen(phonePayload.collectAsState().value)
        }
    }
}

@Composable
fun ComingSoonScreen(phonePayload: String?) {
    MaterialTheme {
        Scaffold(
            timeText = { TimeText() }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                // Tiny placeholder "icon" — a filled circle. Swap this out
                // for a real LoadOut launcher mark before any feature work
                // lands. Avoids pulling in `material-icons-extended` for a
                // single placeholder shape.
                Spacer(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colors.primary)
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "LoadOut Wear",
                    style = MaterialTheme.typography.title3
                )
                Text(
                    text = "Coming Soon",
                    style = MaterialTheme.typography.caption2,
                    color = MaterialTheme.colors.onBackground
                )
                if (phonePayload != null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = phonePayload,
                        style = MaterialTheme.typography.caption3
                    )
                }
            }
        }
    }
}

@Preview(device = "id:wearos_small_round", showSystemUi = true)
@Composable
fun ComingSoonScreenPreview() {
    ComingSoonScreen(phonePayload = null)
}
