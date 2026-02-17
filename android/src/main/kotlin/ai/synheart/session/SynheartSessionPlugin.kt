package ai.synheart.session

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/** Flutter plugin entry point for Synheart Session on Android. */
class SynheartSessionPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val engine = SessionEngine()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "ai.synheart.session/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "ai.synheart.session/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // -- MethodCallHandler --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession" -> handleStartSession(call, result)
            "stopSession" -> handleStopSession(call, result)
            "getStatus" -> handleGetStatus(result)
            else -> result.notImplemented()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleStartSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<String, Any>
        if (args == null) {
            result.error("invalid_state", "Invalid arguments", null)
            return
        }

        try {
            val config = SessionConfig.fromMap(args)
            engine.start(config) { event ->
                eventSink?.success(event)
            }
            result.success(null)
        } catch (e: SessionError) {
            result.error(e.code.value, e.message, null)
        } catch (e: Exception) {
            result.error("invalid_state", e.message, null)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleStopSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<String, Any>
        val sessionId = args?.get("session_id") as? String
        if (sessionId == null) {
            result.error("invalid_state", "Missing session_id", null)
            return
        }

        try {
            engine.stop(sessionId)
            result.success(null)
        } catch (e: SessionError) {
            result.error(e.code.value, e.message, null)
        } catch (e: Exception) {
            result.error("invalid_state", e.message, null)
        }
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        result.success(engine.getStatus())
    }

    // -- EventChannel.StreamHandler --

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
