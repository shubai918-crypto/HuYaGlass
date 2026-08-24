package com.bs.live_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.MethodChannel

/** 媒体前台服务：全部使用系统内置类，无需任何 androidx 依赖 */
class BackgroundPlayService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var mediaSession: MediaSession? = null
    private var playing = true
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> { invokeDart("pause"); playing = false; refreshUi() }
            ACTION_PLAY -> { invokeDart("play"); playing = true; refreshUi() }
            ACTION_STOP -> {
                invokeDart("stop")
                stopSelf()
                return START_NOT_STICKY
            }
        }
        startForeground(NOTIFY_ID, buildNotification())
        acquireLocks()
        ensureSession()
        return START_STICKY
    }

    fun setPlayingFromDart(v: Boolean) {
        playing = v
        refreshUi()
    }

    private fun invokeDart(method: String) {
        val engine = MainActivity.engine ?: return
        mainHandler.post {
            runCatching {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod(method, null)
            }
        }
    }

    private fun acquireLocks() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (wakeLock == null) {
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "huyalive:bgplay")
        }
        wakeLock?.let { if (!it.isHeld) it.acquire(4 * 60 * 60 * 1000L) }

        val wm = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        if (wifiLock == null) {
            wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "huyalive:wifi")
        }
        wifiLock?.let { if (!it.isHeld) it.acquire() }
    }

    private fun ensureSession() {
        if (mediaSession == null) {
            mediaSession = MediaSession(this, "huyalive").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onPause() { invokeDart("pause"); playing = false; refreshUi() }
                    override fun onPlay() { invokeDart("play"); playing = true; refreshUi() }
                    override fun onStop() { invokeDart("stop"); stopSelf() }
                })
            }
        }
        mediaSession?.setPlaybackState(
            PlaybackState.Builder()
                .setState(
                    if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    0, 1f)
                .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP)
                .build()
        )
        mediaSession?.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, "HuyaLive 直播")
                .putString(MediaMetadata.METADATA_KEY_ARTIST, "正在后台播放直播声音")
                .build()
        )
        mediaSession?.isActive = true
    }

    private fun refreshUi() {
        ensureSession()
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFY_ID, buildNotification())
    }

    private fun servicePi(action: String, code: Int): PendingIntent =
        PendingIntent.getService(
            this, code,
            Intent(this, BackgroundPlayService::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "后台播放", NotificationManager.IMPORTANCE_LOW)
                )
            }
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentPi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val pauseAction = Notification.Action.Builder(
            android.R.drawable.ic_media_pause, "暂停", servicePi(ACTION_PAUSE, 1)).build()
        val playAction = Notification.Action.Builder(
            android.R.drawable.ic_media_play, "播放", servicePi(ACTION_PLAY, 2)).build()
        val stopAction = Notification.Action.Builder(
            android.R.drawable.ic_delete, "关闭", servicePi(ACTION_STOP, 3)).build()

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("HuyaLive")
            .setContentText("正在后台播放直播声音")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(contentPi)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .addAction(if (playing) pauseAction else playAction)
            .addAction(stopAction)
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
            .build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        runCatching { startService(Intent(this, BackgroundPlayService::class.java)) }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        instance = null
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "com.huyalive/background"
        private const val CHANNEL_ID = "huyalive_bg_play"
        private const val NOTIFY_ID = 10086
        private const val ACTION_PAUSE = "huyalive.pause"
        private const val ACTION_PLAY = "huyalive.play"
        private const val ACTION_STOP = "huyalive.stop"
        var instance: BackgroundPlayService? = null
            private set
    }
}
