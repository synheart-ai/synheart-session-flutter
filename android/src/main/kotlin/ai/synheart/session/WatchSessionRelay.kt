package ai.synheart.session

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Phone-side relay that bridges session commands and events between the
 * Flutter plugin and a companion Wear OS watch app via the Wearable Data Layer.
 *
 * Mirrors the iOS [WatchSessionRelay.swift] behaviour:
 *   1. Plugin calls [startSession] → relay sends command to watch via [MessageClient].
 *   2. Watch engine emits events → relay receives them in [onMessageReceived]
 *      and forwards to the stored [eventCallback].
 *   3. On terminal events (`session_summary` / `session_error`) the relay cleans up.
 */
class WatchSessionRelay(private val context: Context) : MessageClient.OnMessageReceivedListener {

    companion object {
        private const val TAG = "WatchSessionRelay"
        const val EVENT_PATH = "/synheart/session/event"
        const val COMMAND_PATH = "/synheart/session/command"
    }

    private val messageClient: MessageClient = Wearable.getMessageClient(context)
    private val nodeClient = Wearable.getNodeClient(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var eventCallback: ((Map<String, Any?>) -> Unit)? = null
    private var activeSessionId: String? = null

    init {
        messageClient.addListener(this)
    }

    // -- Status ---------------------------------------------------------------

    /**
     * Full connectivity snapshot for the Dart layer.
     * Matches the iOS format: { supported, reachable, paired, installed }.
     *
     * On Android, [paired] and [installed] are true when at least one connected
     * node exists — Wear OS does not expose these as separate properties.
     */
    fun getStatus(callback: (Map<String, Any>) -> Unit) {
        val supported = isPlayServicesAvailable()
        if (!supported) {
            callback(mapOf(
                "supported" to false,
                "reachable" to false,
                "paired" to false,
                "installed" to false
            ))
            return
        }

        scope.launch {
            val status = try {
                val nodes = nodeClient.connectedNodes.await()
                val hasNode = nodes.isNotEmpty()
                mapOf<String, Any>(
                    "supported" to true,
                    "reachable" to hasNode,
                    "paired" to hasNode,
                    "installed" to hasNode
                )
            } catch (e: Exception) {
                Log.w(TAG, "getStatus failed: ${e.message}")
                mapOf<String, Any>(
                    "supported" to true,
                    "reachable" to false,
                    "paired" to false,
                    "installed" to false
                )
            }

            mainHandler.post { callback(status) }
        }
    }

    /** Whether at least one Wear OS node is currently connected. */
    fun checkReachable(callback: (Boolean) -> Unit) {
        if (!isPlayServicesAvailable()) {
            Log.w(TAG, "Google Play Services NOT available — watch relay disabled")
            callback(false)
            return
        }

        scope.launch {
            val reachable = try {
                val nodes = nodeClient.connectedNodes.await()
                Log.d(TAG, "connectedNodes: ${nodes.size} node(s) found")
                for (node in nodes) {
                    Log.d(TAG, "  node: id=${node.id} name=${node.displayName} nearby=${node.isNearby}")
                }
                nodes.isNotEmpty()
            } catch (e: Exception) {
                Log.w(TAG, "connectedNodes failed: ${e.message}")
                false
            }
            mainHandler.post { callback(reachable) }
        }
    }

    // -- Session commands -----------------------------------------------------

    /**
     * Send a start-session command to the watch.
     *
     * @param config  JSON map of session configuration.
     * @param callback Called for each event the watch streams back.
     */
    fun startSession(config: Map<String, Any?>, callback: (Map<String, Any?>) -> Unit) {
        activeSessionId = config["session_id"] as? String
        eventCallback = callback

        val message = JSONObject().apply {
            put("command", "start_session")
            put("session_id", config["session_id"])
            put("mode", config["mode"])
            put("duration_sec", config["duration_sec"])
            val profile = config["profile"]
            if (profile is Map<*, *>) {
                put("profile", JSONObject().apply {
                    put("window_sec", profile["window_sec"])
                    put("emit_interval_sec", profile["emit_interval_sec"])
                })
            }
            val label = config["window_label"]
            if (label != null) put("window_label", label)
        }

        val payload = message.toString().toByteArray(Charsets.UTF_8)

        scope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                for (node in nodes) {
                    try {
                        messageClient.sendMessage(node.id, COMMAND_PATH, payload).await()
                    } catch (e: Exception) {
                        Log.w(TAG, "sendMessage failed to ${node.displayName}: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "startSession: no connected nodes: ${e.message}")
                mainHandler.post { cleanup() }
            }
        }
    }

    /** Send a stop-session command to the watch. */
    fun stopSession(sessionId: String) {
        val message = JSONObject().apply {
            put("command", "stop_session")
            put("session_id", sessionId)
        }
        val payload = message.toString().toByteArray(Charsets.UTF_8)

        scope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                for (node in nodes) {
                    try {
                        messageClient.sendMessage(node.id, COMMAND_PATH, payload).await()
                    } catch (e: Exception) {
                        Log.w(TAG, "stop sendMessage failed to ${node.displayName}: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "stopSession failed: ${e.message}")
            }
        }
    }

    // -- Receiving events from watch ------------------------------------------

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != EVENT_PATH) return

        val json = JSONObject(String(messageEvent.data, Charsets.UTF_8))
        val eventMap = jsonToMap(json)
        val type = eventMap["type"] as? String ?: ""
        Log.d(TAG, "onMessageReceived: type=$type path=${messageEvent.path} sourceNode=${messageEvent.sourceNodeId}")

        mainHandler.post {
            if (eventCallback == null) {
                Log.w(TAG, "onMessageReceived: eventCallback is null, dropping event type=$type")
            } else {
                eventCallback?.invoke(eventMap)
            }

            if (type == "session_summary" || type == "session_error") {
                cleanup()
            }
        }
    }

    // -- Lifecycle ------------------------------------------------------------

    fun dispose() {
        messageClient.removeListener(this)
        cleanup()
        scope.cancel()
    }

    private fun cleanup() {
        activeSessionId = null
        eventCallback = null
    }

    // -- Helpers --------------------------------------------------------------

    private fun isPlayServicesAvailable(): Boolean {
        return GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
    }

    /** Convert JSONObject to Map<String, Any?> recursively. */
    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> jsonToMap(value)
                is org.json.JSONArray -> jsonArrayToList(value)
                JSONObject.NULL -> null
                else -> value
            }
        }
        return map
    }

    private fun jsonArrayToList(array: org.json.JSONArray): List<Any?> {
        return (0 until array.length()).map { i ->
            when (val value = array.get(i)) {
                is JSONObject -> jsonToMap(value)
                is org.json.JSONArray -> jsonArrayToList(value)
                JSONObject.NULL -> null
                else -> value
            }
        }
    }
}
