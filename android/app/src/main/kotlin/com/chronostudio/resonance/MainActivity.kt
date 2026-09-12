package com.chronostudio.resonance

import android.os.Bundle
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

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.chronostudio.resonance/potoken"
    private val poTokenGenerator by lazy { PoTokenGenerator(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            if (Timber.treeCount == 0) {
                Timber.plant(Timber.DebugTree())
            }
            ZemerCipher.initialize(applicationContext, null, true)
            Log.i("ResonanceMain", "ZemerCipher initialized successfully on onCreate")
            CoroutineScope(Dispatchers.Main).launch {
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
                "generatePoToken" -> {
                    val visitorData = call.argument<String>("visitorData") ?: ""
                    val videoId = call.argument<String>("videoId") ?: ""
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val res = poTokenGenerator.getWebClientPoToken(
                                videoId = if (videoId.isNotEmpty()) videoId else "default",
                                sessionId = if (visitorData.isNotEmpty()) visitorData else "visitor_default"
                            )
                            if (res != null) {
                                result.success(
                                    mapOf(
                                        "playerPoToken" to res.playerRequestPoToken,
                                        "streamPoToken" to res.streamingDataPoToken
                                    )
                                )
                            } else {
                                result.success(null)
                            }
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                }
                "getSignatureTimestamp" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val sts = CipherDeobfuscator.signatureTimestamp()
                            result.success(sts)
                        } catch (e: Throwable) {
                            result.success(null)
                        }
                    }
                }
                "decipherSignature" -> {
                    val signatureCipher = call.argument<String>("signatureCipher")
                    val videoId = call.argument<String>("videoId")
                    if (signatureCipher != null && videoId != null) {
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                Log.d("ResonanceMain", "[decipherSignature] Starting for videoId=$videoId (cipherLen=${signatureCipher.length})")
                                val deciphered = CipherDeobfuscator.deobfuscateStreamUrl(signatureCipher, videoId)
                                Log.d("ResonanceMain", "[decipherSignature] Result: ${if (deciphered != null) "SUCCESS (len=${deciphered.length})" else "NULL"}")
                                result.success(deciphered)
                            } catch (e: Throwable) {
                                Log.e("ResonanceMain", "[decipherSignature] Error: ${e.message}", e)
                                result.error("ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing arguments", null)
                    }
                }
                "decipherN" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                Log.d("ResonanceMain", "[decipherN] Starting n-transform")
                                val deciphered = CipherDeobfuscator.transformNParamInUrl(url)
                                Log.d("ResonanceMain", "[decipherN] Result: ${if (deciphered != null) "SUCCESS" else "NULL"}")
                                result.success(deciphered)
                            } catch (e: Throwable) {
                                Log.e("ResonanceMain", "[decipherN] Error: ${e.message}", e)
                                result.error("ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing url", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
