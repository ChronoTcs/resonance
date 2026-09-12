package com.chronostudio.resonance.potoken

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject

fun parseChallengeData(rawChallengeData: String): String {
    val scrambled = JSONArray(rawChallengeData)
    val challengeData = if (scrambled.length() > 1 && scrambled.optString(1).isNotEmpty()) {
        val descrambled = descramble(scrambled.getString(1))
        JSONArray(descrambled)
    } else {
        scrambled.getJSONArray(0)
    }

    val messageId = challengeData.getString(0)
    val interpreterHash = challengeData.getString(3)
    val program = challengeData.getString(4)
    val globalName = challengeData.getString(5)
    val clientExperimentsStateBlob = challengeData.optString(7, "")

    val wrappedScript = challengeData.optJSONArray(1)?.let { arr ->
        var str: String? = null
        for (i in 0 until arr.length()) {
            if (!arr.isNull(i)) {
                val s = arr.optString(i, "")
                if (s.isNotEmpty() && s != "null") {
                    str = s
                    break
                }
            }
        }
        str
    }

    val wrappedUrl = challengeData.optJSONArray(2)?.let { arr ->
        var str: String? = null
        for (i in 0 until arr.length()) {
            if (!arr.isNull(i)) {
                val s = arr.optString(i, "")
                if (s.isNotEmpty() && s != "null") {
                    str = s
                    break
                }
            }
        }
        str
    }

    val interpreterJs = JSONObject().apply {
        put("privateDoNotAccessOrElseSafeScriptWrappedValue", wrappedScript ?: JSONObject.NULL)
        put("privateDoNotAccessOrElseTrustedResourceUrlWrappedValue", wrappedUrl ?: JSONObject.NULL)
    }

    val result = JSONObject().apply {
        put("messageId", messageId)
        put("interpreterJavascript", interpreterJs)
        put("interpreterHash", interpreterHash)
        put("program", program)
        put("globalName", globalName)
        put("clientExperimentsStateBlob", clientExperimentsStateBlob)
    }

    return result.toString()
}

fun parseIntegrityTokenData(rawIntegrityTokenData: String): Pair<String, Long> {
    val integrityTokenData = JSONArray(rawIntegrityTokenData)
    val tokenBase64 = integrityTokenData.getString(0)
    val durationSeconds = integrityTokenData.getLong(1)
    return base64ToU8(tokenBase64) to durationSeconds
}

fun stringToU8(identifier: String): String {
    return newUint8Array(identifier.toByteArray(Charsets.UTF_8))
}

fun u8ToBase64(poToken: String): String {
    val bytes = poToken.split(",")
        .filter { it.trim().isNotEmpty() }
        .map { it.trim().toInt().toByte() }
        .toByteArray()
    val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
    return base64.replace("+", "-").replace("/", "_").trimEnd('=')
}

private fun descramble(scrambledChallenge: String): String {
    val bytes = base64ToByteArray(scrambledChallenge)
    val descrambled = ByteArray(bytes.size) { i -> (bytes[i] + 97).toByte() }
    return String(descrambled, Charsets.UTF_8)
}

private fun base64ToU8(base64: String): String {
    return newUint8Array(base64ToByteArray(base64))
}

private fun newUint8Array(contents: ByteArray): String {
    val unsignedList = contents.map { (it.toInt() and 0xFF).toString() }
    return "new Uint8Array([" + unsignedList.joinToString(",") + "])"
}

private fun base64ToByteArray(base64: String): ByteArray {
    var base64Mod = base64.replace('-', '+').replace('_', '/').replace('.', '=')
    while (base64Mod.length % 4 != 0) {
        base64Mod += "="
    }
    return Base64.decode(base64Mod, Base64.DEFAULT)
}
