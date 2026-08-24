package com.bs.live_app

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        var engine: FlutterEngine? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = flutterEngine
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.huyalive/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPlaying" -> {
                        BackgroundPlayService.instance
                            ?.setPlayingFromDart(call.arguments as? Boolean ?: true)
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val pm = this@MainActivity.getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(this@MainActivity.packageName)) {
                            @SuppressLint("BatteryLife")
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .apply { data = Uri.parse("package:${this@MainActivity.packageName}") }
                            runCatching { this@MainActivity.startActivity(intent) }
                        }
                        result.success(null)
                    }
                    "startForegroundService" -> {
                        val i = Intent(this@MainActivity, BackgroundPlayService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            this@MainActivity.startForegroundService(i)
                        } else {
                            this@MainActivity.startService(i)
                        }
                        result.success(null)
                    }
                    "stopForegroundService" -> {
                        this@MainActivity.stopService(Intent(this@MainActivity, BackgroundPlayService::class.java))
                        result.success(null)
                    }
                    "acquireWakeLock" -> {
                        val pm = this@MainActivity.getSystemService(POWER_SERVICE) as PowerManager
                        if (wakeLock == null) {
                            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "huyalive:bgplay")
                        }
                        wakeLock?.let { if (!it.isHeld) it.acquire(4 * 60 * 60 * 1000L) }
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
