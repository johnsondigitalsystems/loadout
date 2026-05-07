package com.johnsondigital.loadout.wear

import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Stub Wear OS Data Layer listener.
 *
 * When real phone <-> watch features land:
 *   1. Uncomment the `<intent-filter>` in `AndroidManifest.xml` for this
 *      service so the system delivers events here.
 *   2. Implement [onDataChanged] / [onMessageReceived] to decode payloads
 *      and forward them to the UI layer (see `MainActivity.phonePayload`
 *      for an example StateFlow that the UI observes).
 *   3. On the phone side, send messages via:
 *        Wearable.getMessageClient(context)
 *          .sendMessage(node.id, "/loadout/<feature>", payload)
 *      The path prefix `/loadout/` is reserved for this app — keep it
 *      consistent so the watch can route by prefix.
 *
 * Suggested first message paths (see README.md for details):
 *   /loadout/dope            DOPE glance — active load + zero
 *   /loadout/log_shot        Watch -> phone, shot timestamp
 *   /loadout/active_load     Phone -> watch, current load summary
 */
class PhoneDataLayerListener : WearableListenerService() {

    override fun onDataChanged(events: DataEventBuffer) {
        // Intentionally empty during scaffolding stage.
        // events.forEach { event ->
        //     val item = event.dataItem
        //     when (item.uri.path) {
        //         "/loadout/active_load" -> { /* decode + propagate */ }
        //     }
        // }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        // Intentionally empty during scaffolding stage.
        // when (messageEvent.path) {
        //     "/loadout/dope" -> { /* propagate via shared singleton */ }
        // }
    }
}
