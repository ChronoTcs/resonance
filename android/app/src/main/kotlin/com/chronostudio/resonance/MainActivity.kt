package com.chronostudio.resonance

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

import com.zemer.cipher.CipherDeobfuscator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.chronostudio.resonance/potoken"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generatePoToken" -> {
                    val visitorData = call.argument<String>("visitorData")
                    if (visitorData != null) {
                        try {
                            result.success("android_mock_token_for_$visitorData")
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing visitorData", null)
                    }
                }
                "decipherSignature" -> {
                    val signatureCipher = call.argument<String>("signatureCipher")
                    val videoId = call.argument<String>("videoId")
                    if (signatureCipher != null && videoId != null) {
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                val deciphered = withContext(Dispatchers.IO) {
                                    CipherDeobfuscator.deobfuscateStreamUrl(signatureCipher, videoId)
                                }
                                result.success(deciphered)
                            } catch (e: Exception) {
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
                                val deciphered = withContext(Dispatchers.IO) {
                                    CipherDeobfuscator.transformNParamInUrl(url)
                                }
                                result.success(deciphered)
                            } catch (e: Exception) {
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
