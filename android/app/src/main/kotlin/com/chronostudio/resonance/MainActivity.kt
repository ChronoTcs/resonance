package com.chronostudio.resonance

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import android.os.Build
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

import com.zemer.cipher.CipherDeobfuscator
import com.zemer.cipher.ZemerCipher
import timber.log.Timber
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import com.chronostudio.resonance.potoken.PoTokenGenerator
import com.chronostudio.resonance.discord.DiscordRpcBridge

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.chronostudio.resonance/potoken"
    @Suppress("unused")
    private val keepNotificationIcon = R.drawable.ic_stat_music
    private val poTokenGenerator by lazy { PoTokenGenerator(applicationContext) }
    private var discordRpcBridge: DiscordRpcBridge? = null

    private val wakeLock: PowerManager.WakeLock? by lazy {
        try {
            val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
            pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Resonance::AudioWakeLock")?.apply {
                setReferenceCounted(false)
            }
        } catch (e: Throwable) {
            Log.w("ResonanceMain", "Failed to create WakeLock: ${e.message}")
            null
        }
    }

    private val wifiLock: WifiManager.WifiLock? by lazy {
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            @Suppress("DEPRECATION")
            val lockType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wm?.createWifiLock(lockType, "Resonance::AudioWifiLock")?.apply {
                setReferenceCounted(false)
            }
        } catch (e: Throwable) {
            Log.w("ResonanceMain", "Failed to create WifiLock: ${e.message}")
            null
        }
    }

    private fun updatePlaybackLocks(active: Boolean) {
        try {
            if (active) {
                if (wakeLock?.isHeld == false) {
                    wakeLock?.acquire(4 * 60 * 60 * 1000L) // 4-hour safety cap per acquire
                }
                if (wifiLock?.isHeld == false) {
                    wifiLock?.acquire()
                }
            } else {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                }
                if (wifiLock?.isHeld == true) {
                    wifiLock?.release()
                }
            }
        } catch (e: Throwable) {
            Log.w("ResonanceMain", "updatePlaybackLocks($active) error: ${e.message}")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
        try {
            if (Timber.treeCount == 0) {
                Timber.plant(Timber.DebugTree())
            }
            ZemerCipher.initialize(applicationContext, null, true)
            Log.i("ResonanceMain", "ZemerCipher initialized successfully on onCreate")
            CoroutineScope(Dispatchers.Default).launch {
                try {
                    CipherDeobfuscator.prewarm()
                    Log.i("ResonanceMain", "CipherDeobfuscator prewarmed successfully")
                } catch (e: Throwable) {
                    Log.w("ResonanceMain", "CipherDeobfuscator prewarm failed: ${e.message}")
                }
            }
        } catch (e: Throwable) {
            Log.e("ResonanceMain", "Failed to initialize ZemerCipher on onCreate: ${e.message}", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            ZemerCipher.initialize(applicationContext, null, true)
        } catch (_: Throwable) {}
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPlaybackLocks" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    updatePlaybackLocks(active)
                    result.success(true)
                }
                "generatePoToken" -> {
                    val visitorData = call.argument<String>("visitorData") ?: ""
                    val videoId = call.argument<String>("videoId") ?: ""
                    CoroutineScope(Dispatchers.Default).launch {
                        try {
                            val res = poTokenGenerator.getWebClientPoToken(
                                videoId = if (videoId.isNotEmpty()) videoId else "default",
                                sessionId = if (visitorData.isNotEmpty()) visitorData else "visitor_default"
                            )
                            if (res != null) {
                                runOnUiThread {
                                    result.success(
                                        mapOf(
                                            "playerPoToken" to res.playerRequestPoToken,
                                            "streamPoToken" to res.streamingDataPoToken
                                        )
                                    )
                                }
                            } else {
                                runOnUiThread { result.success(null) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(null) }
                        }
                    }
                }
                "getSignatureTimestamp" -> {
                    CoroutineScope(Dispatchers.Default).launch {
                        try {
                            val sts = CipherDeobfuscator.signatureTimestamp()
                            runOnUiThread { result.success(sts) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.success(null) }
                        }
                    }
                }
                "decipherSignature" -> {
                    val signatureCipher = call.argument<String>("signatureCipher")
                    val videoId = call.argument<String>("videoId")
                    if (signatureCipher != null && videoId != null) {
                        CoroutineScope(Dispatchers.Default).launch {
                            try {
                                Log.d("ResonanceMain", "[decipherSignature] Starting for videoId=$videoId (cipherLen=${signatureCipher.length})")
                                val deciphered = CipherDeobfuscator.deobfuscateStreamUrl(signatureCipher, videoId)
                                Log.d("ResonanceMain", "[decipherSignature] Result: ${if (deciphered != null) "SUCCESS (len=${deciphered.length})" else "NULL"}")
                                runOnUiThread { result.success(deciphered) }
                            } catch (e: Throwable) {
                                Log.e("ResonanceMain", "[decipherSignature] Error: ${e.message}", e)
                                runOnUiThread { result.error("ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing arguments", null)
                    }
                }
                "decipherN" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        CoroutineScope(Dispatchers.Default).launch {
                            try {
                                Log.d("ResonanceMain", "[decipherN] Starting n-transform")
                                val deciphered = CipherDeobfuscator.transformNParamInUrl(url)
                                Log.d("ResonanceMain", "[decipherN] Result: ${if (deciphered != null) "SUCCESS" else "NULL"}")
                                runOnUiThread { result.success(deciphered) }
                            } catch (e: Throwable) {
                                Log.e("ResonanceMain", "[decipherN] Error: ${e.message}", e)
                                runOnUiThread { result.error("ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing url", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        val bridge = DiscordRpcBridge(this)
        discordRpcBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DiscordRpcBridge.CHANNEL_NAME)
            .setMethodCallHandler(bridge)
    }

    override fun onDestroy() {
        updatePlaybackLocks(false)
        discordRpcBridge?.destroy()
        discordRpcBridge = null
        super.onDestroy()
    }
}
