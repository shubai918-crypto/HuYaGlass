package com.bs.live_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

/** 后台播放前台服务：让 ColorOS 不杀进程、音频持续 */
class BackgroundPlayService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFY_ID, buildNotification())
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "后台播放",
                        NotificationManager.IMPORTANCE_LOW)
                )
            }
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("HuyaLive")
            .setContentText("正在后台播放直播声音")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "huyalive_bg_play"
        private const val NOTIFY_ID = 10086
    }
}
