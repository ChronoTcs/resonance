package com.chronostudio.resonance.discord

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.Process
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class DiscordRpcBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "DiscordRpcBridge"
        const val CHANNEL_NAME = "com.chronostudio.resonance/discord_rpc"
        private const val DISCORD_ACTION = "com.discord.socialsdk.rpc.IDiscordRpcService"
        private val DISCORD_PACKAGES = arrayOf("com.discord", "com.discord.canary", "com.discord.ptb")
    }

    private var isInitialized = false
    private var applicationId: Long = 1481352932568862823L
    private var rpcService: com.discord.socialsdk.rpc.IDiscordRpcService? = null
    private var rpcConnection: com.discord.socialsdk.rpc.IDiscordRpcConnection? = null
    private var isBound = false
    private var pendingActivityPayload: String? = null

    private val rpcCallback = object : com.discord.socialsdk.rpc.IDiscordRpcCallback.Stub() {
        override fun onFrame(frame: String) {
            Log.i(TAG, "Received frame from Discord: $frame")
        }

        override fun onClose(code: Int, message: String) {
            Log.w(TAG, "Discord RPC connection closed: $code - $message")
            rpcConnection = null
        }
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            Log.i(TAG, "Connected to Discord RPC Binder service: $name")
            try {
                val service = com.discord.socialsdk.rpc.IDiscordRpcService.Stub.asInterface(binder)
                rpcService = service
                val conn = service.connect(applicationId, "1", rpcCallback)
                rpcConnection = conn
                Log.i(TAG, "Handshake established with Discord RPC connection")
                pendingActivityPayload?.let { payload ->
                    conn.sendFrame(payload)
                    pendingActivityPayload = null
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to connect to Discord RPC connection: ${e.message}", e)
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.w(TAG, "Discord RPC service disconnected: $name")
            rpcService = null
            rpcConnection = null
            isBound = false
        }
    }

    init {
        try {
            com.discord.socialsdk.DiscordSocialSdkInit.setEngineActivity(activity)
            Log.i(TAG, "DiscordSocialSdkInit.setEngineActivity initialized successfully")
        } catch (e: Throwable) {
            Log.w(TAG, "DiscordSocialSdkInit error: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val appId = call.argument<String>("applicationId") ?: "1481352932568862823"
                initialize(appId, result)
            }
            "updatePresence" -> {
                val args = call.arguments as? Map<String, Any?>
                updatePresence(args, result)
            }
            "clearPresence" -> {
                clearPresence(result)
            }
            "dispose" -> {
                dispose(result)
            }
            else -> result.notImplemented()
        }
    }

    private fun bindDiscordService() {
        if (isBound) return
        for (pkg in DISCORD_PACKAGES) {
            val intent = Intent(DISCORD_ACTION).setPackage(pkg)
            try {
                val success = activity.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
                if (success) {
                    isBound = true
                    Log.i(TAG, "Bound to Discord service on package: $pkg")
                    return
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Failed binding to $pkg: ${e.message}")
            }
        }
        Log.w(TAG, "Discord app not installed or no package matched")
    }

    private fun initialize(appId: String, result: MethodChannel.Result) {
        applicationId = appId.toLongOrNull() ?: 1481352932568862823L
        bindDiscordService()
        isInitialized = true
        result.success(true)
    }

    private fun updatePresence(params: Map<String, Any?>?, result: MethodChannel.Result) {
        if (!isInitialized || params == null) {
            result.success(false)
            return
        }

        try {
            val activityJson = JSONObject()
            val appName = (params["name"] as? String)?.takeIf { it.isNotEmpty() } ?: "Resonance"
            activityJson.put("name", appName)
            activityJson.put("type", 2) // 2 = Listening

            val details = params["details"] as? String
            if (!details.isNullOrEmpty()) {
                activityJson.put("details", details)
            }

            val state = params["state"] as? String
            if (!state.isNullOrEmpty()) {
                activityJson.put("state", state)
            }

            val rawStart = (params["startTimestamp"] as? Number)?.toLong()
            val startTs = if (rawStart != null && rawStart in 1..99999999999L) rawStart * 1000L else rawStart
            val rawEnd = (params["endTimestamp"] as? Number)?.toLong()
            val endTs = if (rawEnd != null && rawEnd in 1..99999999999L) rawEnd * 1000L else rawEnd
            if (startTs != null || endTs != null) {
                val tsJson = JSONObject()
                if (startTs != null) tsJson.put("start", startTs)
                if (endTs != null) tsJson.put("end", endTs)
                activityJson.put("timestamps", tsJson)
            } else {
                activityJson.put("timestamps", JSONObject.NULL)
            }

            // Assets
            val largeImage = params["largeImage"] as? String
            val largeText = params["largeText"] as? String
            val smallImage = params["smallImage"] as? String
            val smallText = params["smallText"] as? String
            if (!largeImage.isNullOrEmpty() || !smallImage.isNullOrEmpty()) {
                val assetsJson = JSONObject()
                if (!largeImage.isNullOrEmpty()) assetsJson.put("large_image", largeImage)
                if (!largeText.isNullOrEmpty()) assetsJson.put("large_text", largeText)
                if (!smallImage.isNullOrEmpty()) assetsJson.put("small_image", smallImage)
                if (!smallText.isNullOrEmpty()) assetsJson.put("small_text", smallText)
                activityJson.put("assets", assetsJson)
            } else {
                activityJson.put("assets", JSONObject.NULL)
            }

            // Buttons
            val button1Label = params["button1Label"] as? String
            val button1Url = params["button1Url"] as? String
            val button2Label = params["button2Label"] as? String
            val button2Url = params["button2Url"] as? String
            val buttonsArray = JSONArray()
            if (!button1Label.isNullOrEmpty() && !button1Url.isNullOrEmpty()) {
                val b1 = JSONObject()
                b1.put("label", button1Label)
                b1.put("url", button1Url)
                buttonsArray.put(b1)
            }
            if (!button2Label.isNullOrEmpty() && !button2Url.isNullOrEmpty()) {
                val b2 = JSONObject()
                b2.put("label", button2Label)
                b2.put("url", button2Url)
                buttonsArray.put(b2)
            }
            if (buttonsArray.length() > 0) {
                activityJson.put("buttons", buttonsArray)
            }

            val frame = JSONObject()
            frame.put("cmd", "SET_ACTIVITY")
            val args = JSONObject()
            args.put("pid", Process.myPid())
            args.put("activity", activityJson)
            frame.put("args", args)
            frame.put("nonce", UUID.randomUUID().toString())

            val frameStr = frame.toString()
            Log.i(TAG, "Dispatching SET_ACTIVITY frame: $frameStr")
            sendFrameWithReconnect(frameStr)
            result.success(true)
        } catch (e: Throwable) {
            Log.e(TAG, "updatePresence error: ${e.message}", e)
            result.success(false)
        }
    }

    private fun sendFrameWithReconnect(frameStr: String) {
        val conn = rpcConnection
        if (conn != null) {
            try {
                conn.sendFrame(frameStr)
                return
            } catch (e: Throwable) {
                Log.w(TAG, "sendFrame failed on active connection, reconnecting: ${e.message}")
                rpcConnection = null
            }
        }

        // Connection is null (either not yet connected, closed via onClose, or DeadObjectException).
        // If service binder is still bound, try re-establishing the RPC session directly first.
        val service = rpcService
        if (isBound && service != null) {
            try {
                val newConn = service.connect(applicationId, "1", rpcCallback)
                if (newConn != null) {
                    rpcConnection = newConn
                    newConn.sendFrame(frameStr)
                    pendingActivityPayload = null
                    Log.i(TAG, "Re-established Discord RPC session on existing bound service")
                    return
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to reconnect on existing binder, rebinding service: ${e.message}")
            }
            // Existing binder is dead or rejected connect; unbind cleanly so bindDiscordService() can rebind.
            try {
                activity.unbindService(serviceConnection)
            } catch (_: Throwable) {}
            isBound = false
            rpcService = null
        }

        pendingActivityPayload = frameStr
        bindDiscordService()
    }

    private fun clearPresence(result: MethodChannel.Result) {
        try {
            val frame = JSONObject()
            frame.put("cmd", "SET_ACTIVITY")
            val args = JSONObject()
            args.put("pid", Process.myPid())
            args.put("activity", JSONObject.NULL)
            frame.put("args", args)
            frame.put("nonce", UUID.randomUUID().toString())

            val conn = rpcConnection
            if (conn != null) {
                conn.sendFrame(frame.toString())
            }
        } catch (e: Throwable) {
            Log.w(TAG, "clearPresence error: ${e.message}")
            rpcConnection = null
        }
        pendingActivityPayload = null
        result.success(true)
    }

    fun destroy() {
        try {
            rpcConnection?.disconnect()
            if (isBound) {
                activity.unbindService(serviceConnection)
                isBound = false
            }
        } catch (_: Throwable) {}
        rpcConnection = null
        rpcService = null
        isInitialized = false
    }

    private fun dispose(result: MethodChannel.Result) {
        clearPresence(result)
        destroy()
    }
}
