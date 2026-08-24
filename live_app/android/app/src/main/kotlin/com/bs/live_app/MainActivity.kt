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
    companion object {
        var engine: FlutterEngine? = null   // ★ 新增：给 Service 反向调 Dart 用
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        engine = flutterEngine              // ★ 新增
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.huyalive/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ★ 新增：Dart 同步播放状态到通知栏
                    "setPlaying" -> {
                        BackgroundPlayService.instance
                            ?.setPlayingFromDart(call.arguments as? Boolean ?: true)
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> { /* 原有逻辑保留 */ }
                    "startForegroundService" -> { /* 原有逻辑保留 */ }
                    "stopForegroundService" -> { /* 原有逻辑保留 */ }
                    "acquireWakeLock" -> { /* 原有逻辑保留 */ }
                    "releaseWakeLock" -> { /* 原有逻辑保留 */ }
                    else -> result.notImplemented()
                }
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
