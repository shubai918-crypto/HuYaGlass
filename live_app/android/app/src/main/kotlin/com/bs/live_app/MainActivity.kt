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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.huyalive/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val already = pm.isIgnoringBatteryOptimizations(packageName)
                        if (!already) {
                            @SuppressLint("BatteryLife")
                            val dialog = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .apply { data = Uri.parse("package:$packageName") }
                            val ok = runCatching { startActivity(dialog); true }.getOrDefault(false)
                            if (!ok) openAppDetails() // ★ ColorOS 拦截时兜底
                        }
                        result.success(already)
                    }
                    "openAppDetails" -> {
                        openAppDetails()
                        result.success(true)
                    }
                    "startForegroundService" -> {
                        val i = Intent(this, BackgroundPlayService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i)
                        else startService(i)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopService(Intent(this, BackgroundPlayService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAppDetails() {
        runCatching {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .apply { data = Uri.parse("package:$packageName") }
            )
        }
    }
}
