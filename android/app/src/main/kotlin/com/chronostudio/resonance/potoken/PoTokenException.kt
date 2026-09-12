package com.chronostudio.resonance.potoken

open class PoTokenException(message: String, cause: Throwable? = null) : Exception(message, cause)

class BadWebViewException(message: String, cause: Throwable? = null) : PoTokenException(message, cause)
