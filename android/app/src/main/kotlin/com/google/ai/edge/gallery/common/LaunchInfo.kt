package com.google.ai.edge.gallery.common

import android.content.Context
import android.content.SharedPreferences

data class LaunchInfo(val ts: Long)

fun readLaunchInfo(context: Context): LaunchInfo? {
    val prefs: SharedPreferences = context.getSharedPreferences("launch_info", Context.MODE_PRIVATE)
    val ts = prefs.getLong("launch_timestamp", 0L)
    return if (ts > 0) LaunchInfo(ts) else null
}

fun writeLaunchInfo(context: Context, launchInfo: LaunchInfo) {
    val prefs: SharedPreferences = context.getSharedPreferences("launch_info", Context.MODE_PRIVATE)
    prefs.edit().putLong("launch_timestamp", launchInfo.ts).apply()
}
