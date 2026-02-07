package com.easystreet.ui

import android.content.Context
import android.content.SharedPreferences

object DisclaimerManager {

    private const val PREFS_NAME = "disclaimer"
    private const val KEY_HAS_SEEN = "hasSeenDisclaimer_v1"

    fun hasSeenDisclaimer(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_HAS_SEEN, false)
    }

    fun markDisclaimerSeen(context: Context) {
        getPrefs(context).edit().putBoolean(KEY_HAS_SEEN, true).apply()
    }

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    const val DISCLAIMER_TITLE = "Important Notice"

    const val DISCLAIMER_BODY =
        "EasyStreet provides street sweeping schedule information based on data " +
        "from the City of San Francisco's open data portal. This information is " +
        "provided for convenience only and may not reflect the most current schedules.\n\n" +
        "Always check posted street signs for the official sweeping schedule at " +
        "your parking location. EasyStreet is not responsible for parking tickets " +
        "or towing resulting from reliance on information displayed in this app."

    const val ATTRIBUTION_TEXT = "Data: City of San Francisco (data.sfgov.org)"
}
