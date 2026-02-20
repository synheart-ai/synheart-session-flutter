package ai.synheart.session

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Flutter plugin entry point for Synheart Session on Android.
 *
 * After the refactor to Dart-side `LiveSessionEngine`, this plugin only
 * handles the Wear OS watch relay path. All local session compute is done
 * in Dart. The watch relay is kept because the Wearable Data Layer requires
 * a native host.
 */
class SynheartSessionPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var watchRelay: WatchSessionRelay? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "ai.synheart.session/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "ai.synheart.session/events")
        eventChannel.setStreamHandler(this)

        watchRelay = WatchSessionRelay(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        watchRelay?.dispose()
        watchRelay = null
    }

    // -- MethodCallHandler ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession" -> handleStartSession(call, result)
            "stopSession" -> handleStopSession(call, result)
            "getStatus" -> result.success(null) // Local status handled in Dart
            "getWatchStatus" -> handleGetWatchStatus(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("invalid_state", "Invalid arguments", null)
            return
        }

        @Suppress("UNCHECKED_CAST")
        val config = args as Map<String, Any?>

        val relay = watchRelay
        if (relay == null) {
            result.success(null)
            return
        }

        val sink: (Map<String, Any?>) -> Unit = { event ->
            eventSink?.success(event)
        }

        relay.checkReachable { reachable ->
            if (reachable) {
                relay.startSession(config, sink)
            }
            // If watch not reachable, just return — Dart LiveSessionEngine handles locally
            result.success(null)
        }
    }

    private fun handleStopSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val sessionId = args?.get("session_id") as? String
        if (sessionId == null) {
            result.error("invalid_state", "Missing session_id", null)
            return
        }

        watchRelay?.stopSession(sessionId)
        result.success(null)
    }

    private fun handleGetWatchStatus(result: MethodChannel.Result) {
        val relay = watchRelay
        if (relay == null) {
            result.success(mapOf(
                "supported" to false,
                "reachable" to false,
                "paired" to false,
                "installed" to false
            ))
            return
        }

        relay.getStatus { status ->
            result.success(status)
        }
    }

    // -- EventChannel.StreamHandler -------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
