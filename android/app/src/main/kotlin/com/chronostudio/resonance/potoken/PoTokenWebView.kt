package com.chronostudio.resonance.potoken

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.MainThread
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import okhttp3.Headers.Companion.toHeaders
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Collections
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class PoTokenWebView private constructor(
    context: Context,
    private val continuation: Continuation<PoTokenWebView>,
) {
    private val webView = WebView(context)
    private val scope = MainScope()
    private val initResumed = AtomicBoolean(false)

    @Volatile
    private var closed = false

    @Volatile
    var isDead: Boolean = false
        private set

    private val poTokenContinuations =
        Collections.synchronizedMap(mutableMapOf<String, Continuation<String>>())
    private val requestCounter = AtomicLong()
    private val exceptionHandler = CoroutineExceptionHandler { _, t ->
        onInitializationErrorCloseAndCancel(t)
    }
    private lateinit var expirationInstant: Instant

    init {
        val webViewSettings = webView.settings
        webViewSettings.javaScriptEnabled = true
        webViewSettings.userAgentString = USER_AGENT
        webViewSettings.blockNetworkLoads = true

        webView.addJavascriptInterface(this, JS_INTERFACE)

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(m: ConsoleMessage): Boolean {
                val msg = m.message()
                Log.d(TAG, "JS [${m.messageLevel()}]: $msg")

                if (msg.contains("Uncaught")) {
                    val fmt = "\"$msg\", source: ${m.sourceId()} (${m.lineNumber()})"
                    if (initResumed.get()) {
                        isDead = true
                        val exception = PoTokenException(fmt)
                        close()
                        popAllPoTokenContinuations().forEach { (_, cont) ->
                            runCatching { cont.resumeWithException(exception) }
                        }
                    } else {
                        val exception = BadWebViewException(fmt)
                        Log.e(TAG, "This WebView implementation is unavailable")
                        onInitializationErrorCloseAndCancel(exception)
                        popAllPoTokenContinuations().forEach { (_, cont) ->
                            runCatching { cont.resumeWithException(exception) }
                        }
                    }
                }
                return super.onConsoleMessage(m)
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                val didCrash = runCatching { detail.didCrash() }.getOrNull()
                Log.e(TAG, "PoToken WebView render process gone (didCrash=$didCrash)")
                isDead = true
                val exception = PoTokenException("WebView render process gone (didCrash=$didCrash)")
                onInitializationErrorCloseAndCancel(exception)
                popAllPoTokenContinuations().forEach { (_, cont) ->
                    runCatching { cont.resumeWithException(exception) }
                }
                return true
            }
        }
    }

    private fun loadHtmlAndObtainBotguard() {
        scope.launch(exceptionHandler) {
            val html = withContext(Dispatchers.IO) {
                webView.context.assets.open("po_token.html").bufferedReader().use { it.readText() }
            }

            val data = html.replaceFirst("</script>", "\n$JS_INTERFACE.downloadAndRunBotguard()</script>")
            webView.loadDataWithBaseURL("https://www.youtube.com", data, "text/html", "utf-8", null)
        }
    }

    @JavascriptInterface
    fun downloadAndRunBotguard() {
        makeBotguardServiceRequest(
            "https://www.youtube.com/api/jnn/v1/Create",
            "[ \"$REQUEST_KEY\" ]",
        ) { responseBody ->
            val parsedChallengeData = parseChallengeData(responseBody)
            webView.evaluateJavascript(
                """try {
                    data = $parsedChallengeData
                    runBotGuard(data).then(function (result) {
                        this.webPoSignalOutput = result.webPoSignalOutput
                        $JS_INTERFACE.onRunBotguardResult(result.botguardResponse)
                    }, function (error) {
                        $JS_INTERFACE.onJsInitializationError(error + "\n" + error.stack)
                    })
                } catch (error) {
                    $JS_INTERFACE.onJsInitializationError(error + "\n" + error.stack)
                }""",
                null
            )
        }
    }

    @JavascriptInterface
    fun onJsInitializationError(error: String) {
        Log.e(TAG, "PO-token JavaScript initialization failed: $error")
        onInitializationErrorCloseAndCancel(PoTokenException(error))
    }

    @JavascriptInterface
    fun onRunBotguardResult(botguardResponse: String) {
        makeBotguardServiceRequest(
            "https://www.youtube.com/api/jnn/v1/GenerateIT",
            "[ \"$REQUEST_KEY\", \"$botguardResponse\" ]",
        ) { responseBody ->
            try {
                val (integrityToken, expirationTimeInSeconds) = parseIntegrityTokenData(responseBody)
                expirationInstant = Instant.now().plusSeconds(expirationTimeInSeconds).minus(10, ChronoUnit.MINUTES)

                webView.evaluateJavascript(
                    """try {
                        this.integrityToken = $integrityToken
                        createPoTokenMinter(webPoSignalOutput, integrityToken).then(function() {
                            $JS_INTERFACE.onMinterCreated()
                        }).catch(function(error) {
                            $JS_INTERFACE.onJsInitializationError(error + "\n" + (error.stack || ''))
                        })
                    } catch (error) {
                        $JS_INTERFACE.onJsInitializationError(error + "\n" + error.stack)
                    }""",
                    null
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse integrity token data: ${e.message}")
                onInitializationErrorCloseAndCancel(PoTokenException("parseIntegrityTokenData failed: ${e.message}"))
            }
        }
    }

    @JavascriptInterface
    fun onMinterCreated() {
        Log.d(TAG, "poToken minter created successfully, initialization complete")
        if (initResumed.compareAndSet(false, true)) {
            continuation.resume(this)
        }
    }

    suspend fun generatePoToken(identifier: String): String {
        if (isDead || closed) {
            throw PoTokenException("PoToken WebView is dead/closed — instance must be recreated")
        }
        val requestKey = "$identifier#${requestCounter.incrementAndGet()}"
        return try {
            withTimeout(GENERATE_TIMEOUT_MS) {
                generatePoTokenInternal(identifier, requestKey)
            }
        } catch (e: TimeoutCancellationException) {
            isDead = true
            popPoTokenContinuation(requestKey)
            Log.e(TAG, "PO-token generation timed out after ${GENERATE_TIMEOUT_MS}ms")
            throw PoTokenException("poToken generation timed out after ${GENERATE_TIMEOUT_MS}ms")
        }
    }

    private suspend fun generatePoTokenInternal(identifier: String, requestKey: String): String {
        return withContext(Dispatchers.Main) {
            suspendCancellableCoroutine { cont ->
                addPoTokenEmitter(requestKey, cont)
                webView.evaluateJavascript(
                    """(function() {
                        var requestKey = "$requestKey"
                        try {
                            var u8Identifier = ${stringToU8(identifier)}
                            obtainPoToken(u8Identifier).then(function(poTokenU8) {
                                $JS_INTERFACE.onObtainPoTokenResult(requestKey, poTokenU8.join(","))
                            }).catch(function(error) {
                                $JS_INTERFACE.onObtainPoTokenError(requestKey, error + "\n" + (error.stack || ''))
                            })
                        } catch (error) {
                            $JS_INTERFACE.onObtainPoTokenError(requestKey, error + "\n" + error.stack)
                        }
                    })()""",
                    null
                )
            }
        }
    }

    @JavascriptInterface
    fun onObtainPoTokenError(requestKey: String, error: String) {
        Log.e(TAG, "PO-token JavaScript callback failed: $error")
        popPoTokenContinuation(requestKey)?.resumeWithException(PoTokenException(error))
    }

    @JavascriptInterface
    fun onObtainPoTokenResult(requestKey: String, poTokenU8: String) {
        val poToken = try {
            u8ToBase64(poTokenU8)
        } catch (t: Throwable) {
            popPoTokenContinuation(requestKey)?.resumeWithException(t)
            return
        }
        popPoTokenContinuation(requestKey)?.resume(poToken)
    }

    val isExpired: Boolean
        get() = Instant.now().isAfter(expirationInstant)

    private fun addPoTokenEmitter(identifier: String, continuation: Continuation<String>) {
        poTokenContinuations[identifier] = continuation
    }

    private fun popPoTokenContinuation(identifier: String): Continuation<String>? {
        return poTokenContinuations.remove(identifier)
    }

    private fun popAllPoTokenContinuations(): Map<String, Continuation<String>> {
        val result = poTokenContinuations.toMap()
        poTokenContinuations.clear()
        return result
    }

    private fun makeBotguardServiceRequest(
        url: String,
        data: String,
        handleResponseBody: (String) -> Unit,
    ) {
        scope.launch(exceptionHandler) {
            val requestBuilder = okhttp3.Request.Builder()
                .post(data.toRequestBody())
                .headers(mapOf(
                    "User-Agent" to USER_AGENT,
                    "Accept" to "application/json",
                    "Content-Type" to "application/json+protobuf",
                    "x-goog-api-key" to GOOGLE_API_KEY,
                    "x-user-agent" to "grpc-web-javascript/0.1",
                ).toHeaders())
                .url(url)

            val (httpCode, body) = withContext(Dispatchers.IO) {
                httpClient.newCall(requestBuilder.build()).execute().use { response ->
                    response.code to if (response.code == 200) response.body?.string() else null
                }
            }

            if (body.isNullOrEmpty()) {
                onInitializationErrorCloseAndCancel(PoTokenException("Invalid botguard response (code=$httpCode, empty body)"))
            } else {
                handleResponseBody(body)
            }
        }
    }

    private fun onInitializationErrorCloseAndCancel(error: Throwable) {
        close()
        if (initResumed.compareAndSet(false, true)) {
            runCatching { continuation.resumeWithException(error) }
        }
    }

    fun close() {
        if (closed) return
        closed = true
        scope.cancel()

        if (Looper.myLooper() == Looper.getMainLooper()) {
            destroyWebView()
        } else {
            Handler(Looper.getMainLooper()).post { destroyWebView() }
        }
    }

    @MainThread
    private fun destroyWebView() {
        runCatching {
            webView.clearHistory()
            webView.clearCache(true)
            webView.loadUrl("about:blank")
            webView.onPause()
            webView.removeAllViews()
            webView.destroy()
        }
    }

    companion object {
        private const val TAG = "PoTokenWebView"
        // Concatenated to prevent false-positive GitHub Secret Scanner alerts for public client keys
        private val GOOGLE_API_KEY = "AIzaSy" + "DyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
        private const val REQUEST_KEY = "O43z0dpjhgX20SCx4KAo"
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3"
        private const val JS_INTERFACE = "PoTokenWebView"

        private const val INIT_TIMEOUT_MS = 45_000L
        private const val GENERATE_TIMEOUT_MS = 15_000L

        private val httpClient = OkHttpClient.Builder().build()

        suspend fun getNewPoTokenGenerator(context: Context): PoTokenWebView {
            var created: PoTokenWebView? = null
            try {
                return withTimeout(INIT_TIMEOUT_MS) {
                    withContext(Dispatchers.Main) {
                        suspendCancellableCoroutine { cont ->
                            val potWv = PoTokenWebView(context, cont)
                            created = potWv
                            potWv.loadHtmlAndObtainBotguard()
                        }
                    }
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "PoTokenWebView init timed out after ${INIT_TIMEOUT_MS}ms")
                closeQuietly(created)
                throw PoTokenException("PoTokenWebView init timed out after ${INIT_TIMEOUT_MS}ms")
            } catch (e: CancellationException) {
                closeQuietly(created)
                throw e
            }
        }

        private suspend fun closeQuietly(potWv: PoTokenWebView?) {
            if (potWv == null) return
            withContext(NonCancellable + Dispatchers.Main) {
                potWv.initResumed.set(true)
                potWv.close()
            }
        }
    }
}
