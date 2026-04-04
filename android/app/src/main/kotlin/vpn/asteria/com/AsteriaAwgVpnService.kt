package vpn.asteria.com

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.amnezia.awg.backend.GoBackend
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * AmneziaWG [GoBackend] VPN service with a persistent tray notification (same idea as [LibcoreVpnService]).
 *
 * Stats polling must not call [AwgVpnController.getStatsUploadDownload] (JNI → awgGetConfig) on the main thread;
 * that races with the Go stack and can SIGSEGV during/after handshake.
 */
class AsteriaAwgVpnService : GoBackend.VpnService() {

    private val statsExecutor = Executors.newSingleThreadScheduledExecutor()
    private var statsFuture: ScheduledFuture<*>? = null

    override fun onCreate() {
        super.onCreate()
        isInstanceAlive = true
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(0L, 0L),
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )
        startStatsLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Thread { AwgVpnController.stopSync(this@AsteriaAwgVpnService) }.start()
            return START_NOT_STICKY
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        statsFuture?.cancel(false)
        statsFuture = null
        statsExecutor.shutdownNow()
        super.onDestroy()
        // After GoBackend tears down the tun + stopSelf(), the VPN slot is fully free for LibcoreVpnService.
        isInstanceAlive = false
        pendingDestroyLatch?.countDown()
        pendingDestroyLatch = null
    }

    private fun startStatsLoop() {
        statsFuture = statsExecutor.scheduleAtFixedRate(
            {
                if (!AwgVpnController.isActive()) return@scheduleAtFixedRate
                try {
                    val (tx, rx) = AwgVpnController.getStatsUploadDownload()
                    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    mgr.notify(NOTIFICATION_ID, buildNotification(tx, rx))
                } catch (_: Exception) {
                }
            },
            5L,
            3L,
            TimeUnit.SECONDS,
        )
    }

    private fun buildNotification(tx: Long, rx: Long): Notification {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Asteria VPN", NotificationManager.IMPORTANCE_DEFAULT).apply {
                        setShowBadge(false)
                        enableLights(false)
                        enableVibration(false)
                        setSound(null, null)
                    },
                )
            }
        }

        val profile = AwgVpnController.lastAwgProfileLabel ?: "AmneziaWG"
        val title = "Asteria • ${formatBytes(tx)}↑ ${formatBytes(rx)}↓"
        val expanded = "$profile\n[AmneziaWG]\nVPN активен"

        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPi = PendingIntent.getActivity(
            this,
            0,
            openApp,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = Intent(this, AsteriaAwgVpnService::class.java).apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this,
            3,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(profile)
            .setStyle(NotificationCompat.BigTextStyle().bigText(expanded).setSummaryText("VPN активен"))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentIntent(contentPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Остановить", stopPi)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .build()
    }

    private fun formatBytes(bytes: Long): String = when {
        bytes < 1024 -> "$bytes Б"
        bytes < 1024 * 1024 -> "%.2f КБ".format(bytes / 1024.0)
        bytes < 1024 * 1024 * 1024 -> "%.2f МБ".format(bytes / (1024.0 * 1024.0))
        else -> "%.2f ГБ".format(bytes / (1024.0 * 1024.0 * 1024.0))
    }

    companion object {
        private const val CHANNEL_ID = "asteria_vpn_channel"
        private const val NOTIFICATION_ID = 102
        private const val ACTION_STOP = "vpn.asteria.com.action.STOP_AWG"

        @Volatile
        private var pendingDestroyLatch: CountDownLatch? = null

        /** True while the foreground [AsteriaAwgVpnService] exists (tunnel may already be DOWN). */
        @Volatile
        private var isInstanceAlive: Boolean = false

        fun isServiceInstanceAlive(): Boolean = isInstanceAlive

        /** Call before stopping AWG so handoff can wait until [onDestroy] (VPN slot released). */
        fun armDestroyLatch(latch: CountDownLatch) {
            pendingDestroyLatch = latch
        }

        fun clearDestroyLatch() {
            pendingDestroyLatch = null
        }
    }
}
