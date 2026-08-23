package com.bs.live_app

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity   // ★ 关键：之前漏了这行
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.huyalive/background"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestIgnoreBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                        @SuppressLint("BatteryLife")
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        ).apply { data = Uri.parse("package:$packageName") }
                        runCatching { startActivity(intent) }
                    }
                    result.success(null)
                }
                "acquireWakeLock" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    if (wakeLock == null) {
                        wakeLock = pm.newWakeLock(
                            PowerManager.PARTIAL_WAKE_LOCK,
                            "huyalive:bgplay"
                        )
                    }
                    wakeLock?.acquire(60 * 60 * 1000L)
                    result.success(null)
                }
                "releaseWakeLock" -> {
                    wakeLock?.let { if (it.isHeld) it.release() }
                    wakeLock = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
