package vpn.asteria.com

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import libcore.Libcore
import libcore.BoxInstance
import org.json.JSONObject
import java.io.File

class LibcoreVpnService : VpnService() {

    companion object {
        private const val TAG = "LibcoreVpnService"
        private const val CHANNEL_ID = "asteria_vpn_channel"
        private const val NOTIFICATION_ID = 101
        private const val EXTRA_CONFIG = "configPath"
        private const val EXTRA_PROFILE_NAME = "profileName"
        private const val EXTRA_TRANSPORT = "transport"

        private var boxInstance: BoxInstance? = null
        private var fileDescriptor: ParcelFileDescriptor? = null
        private var uploadBytes: Long = 0L
        private var downloadBytes: Long = 0L
        private var lastRxBytes: Long = 0L
        private var lastTxBytes: Long = 0L
        private var currentProfileName: String? = null
        private var currentTransport: String? = null
        private var serviceInstance: LibcoreVpnService? = null
        private var onVpnStoppedCallback: (() -> Unit)? = null

        fun setOnVpnStoppedCallback(callback: (() -> Unit)?) {
            onVpnStoppedCallback = callback
        }

        fun start(context: Context, configPath: String, profileName: String? = null, transport: String? = null) {
            val intent = Intent(context, LibcoreVpnService::class.java).apply {
                putExtra(EXTRA_CONFIG, configPath)
                putExtra(EXTRA_PROFILE_NAME, profileName)
                putExtra(EXTRA_TRANSPORT, transport)
            }
            Log.i(TAG, "Start service config=$configPath, profile=$profileName, transport=$transport")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun updateNotification(context: Context) {
            serviceInstance?.updateNotificationInternal()
        }

        fun stop(context: Context) {
            boxInstance?.close()
            boxInstance = null
            fileDescriptor?.close()
            fileDescriptor = null
            uploadBytes = 0L
            downloadBytes = 0L
            lastRxBytes = 0L
            lastTxBytes = 0L
            currentProfileName = null
            currentTransport = null
            context.stopService(Intent(context, LibcoreVpnService::class.java))
            onVpnStoppedCallback?.invoke()
        }

        fun getStats(): Pair<Long, Long> = Pair(uploadBytes, downloadBytes)

        fun updateStats(upload: Long, download: Long) {
            uploadBytes = upload
            downloadBytes = download
        }
    }

    private var currentRxSpeed: Long = 0L
    private var currentTxSpeed: Long = 0L
    private var statsTrackingThread: Thread? = null
    private var isTrackingStats = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_VPN") {
            stop(this)
            return START_NOT_STICKY
        }

        val configPath = intent?.getStringExtra(EXTRA_CONFIG)
        if (configPath.isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        currentProfileName = intent.getStringExtra(EXTRA_PROFILE_NAME)
        currentTransport = intent.getStringExtra(EXTRA_TRANSPORT)
        serviceInstance = this

        (application as? AsteriaApplication)?.setVpnService(this)
        DefaultNetworkMonitor.ensureStarted(this)

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        try {
            val configContent = File(configPath).readText()
            if (configContent.isBlank()) {
                Log.e(TAG, "Config is empty")
                stopSelf()
                return START_NOT_STICKY
            }

            boxInstance = Libcore.newSingBoxInstance(configContent, LocalResolver)
            boxInstance!!.setAsMain()  // starts protect server so proxy sockets get protect() and bypass VPN
            boxInstance!!.start()

            startStatsTracking()
            Log.i(TAG, "Libcore service started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start libcore service: ${e.message}", e)
            stopSelf()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        (application as? AsteriaApplication)?.setVpnService(null)
        DefaultNetworkMonitor.ensureStopped()
        stopStatsTracking()
        boxInstance?.close()
        boxInstance = null
        fileDescriptor?.close()
        fileDescriptor = null
        uploadBytes = 0L
        downloadBytes = 0L
        lastRxBytes = 0L
        lastTxBytes = 0L
        currentProfileName = null
        currentTransport = null
        serviceInstance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    fun startVpn(tunOptionsJson: String, tunPlatformOptionsJson: String): Int {
        Log.d(TAG, "startVpn called, tunOptions length=${tunOptionsJson.length}")
        if (prepare(this) != null) {
            throw IllegalStateException("VPN permission not granted")
        }

        var mtu = 1500
        val addresses = mutableListOf<Pair<String, Int>>()

        try {
            val json = JSONObject(tunOptionsJson)
            if (json.has("mtu")) mtu = json.optInt("mtu", 1500)
            if (json.has("inet4_address")) {
                val arr = json.getJSONArray("inet4_address")
                for (i in 0 until arr.length()) {
                    val s = arr.getString(i)
                    val parts = s.split("/")
                    addresses.add(Pair(parts[0], parts.getOrNull(1)?.toIntOrNull() ?: 30))
                }
            }
            if (json.has("inet6_address")) {
                val arr = json.getJSONArray("inet6_address")
                for (i in 0 until arr.length()) {
                    val s = arr.getString(i)
                    val parts = s.split("/")
                    addresses.add(Pair(parts[0], parts.getOrNull(1)?.toIntOrNull() ?: 126))
                }
            }
            if (json.has("address")) {
                val arr = json.getJSONArray("address")
                for (i in 0 until arr.length()) {
                    val s = arr.getString(i)
                    val parts = s.split("/")
                    addresses.add(Pair(parts[0], parts.getOrNull(1)?.toIntOrNull() ?: if (s.contains(":")) 126 else 30))
                }
            }
        } catch (_: Exception) {}

        if (addresses.isEmpty()) {
            addresses.add(Pair("172.19.0.1", 30))
            addresses.add(Pair("fdfe:dcba:9876::1", 126))
        }

        val configureIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
        )
        val builder = Builder()
            .setConfigureIntent(configureIntent)
            .setSession("Asteria VPN")
            .setMtu(mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        for ((addr, prefix) in addresses) {
            builder.addAddress(addr, prefix)
        }

        // DNS must point to the TUN "router" (sing-box) so DNS queries go through the tunnel
        val hasIpv4 = addresses.any { !it.first.contains(":") }
        val hasIpv6 = addresses.any { it.first.contains(":") }
        if (hasIpv4) builder.addDnsServer("172.19.0.2")
        if (hasIpv6) builder.addDnsServer("fdfe:dcba:9876::2")
        if (!hasIpv4 && !hasIpv6) builder.addDnsServer("172.19.0.2")
        // Explicit route for TUN DNS router so DNS goes through tunnel (like NekoBox)
        if (hasIpv4) builder.addRoute("172.19.0.2", 32)
        builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)

        // Use system default network; explicit setUnderlyingNetworks can break on some devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val network = (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)?.activeNetwork
                ?: try { DefaultNetworkMonitor.require() } catch (_: Exception) { null }
            network?.let { builder.setUnderlyingNetworks(arrayOf(it)) }
        }

        val pfd = builder.establish() ?: throw IllegalStateException("Failed to establish VPN")
        fileDescriptor = pfd
        Log.i(TAG, "VPN established fd=${pfd.fd}")
        return pfd.fd
    }

    private fun startStatsTracking() {
        isTrackingStats = true
        val appUid = android.os.Process.myUid()
        statsTrackingThread = Thread {
            var lastUidRxBytes = TrafficStats.getUidRxBytes(appUid)
            var lastUidTxBytes = TrafficStats.getUidTxBytes(appUid)
            while (isTrackingStats) {
                try {
                    if (boxInstance != null) {
                        val currentRxBytes = TrafficStats.getUidRxBytes(appUid)
                        val currentTxBytes = TrafficStats.getUidTxBytes(appUid)
                        if (currentRxBytes != TrafficStats.UNSUPPORTED.toLong() &&
                            currentTxBytes != TrafficStats.UNSUPPORTED.toLong()) {
                            val rxDiff = if (lastUidRxBytes > 0 && currentRxBytes >= lastUidRxBytes) currentRxBytes - lastUidRxBytes else 0L
                            val txDiff = if (lastUidTxBytes > 0 && currentTxBytes >= lastUidTxBytes) currentTxBytes - lastUidTxBytes else 0L
                            downloadBytes += rxDiff
                            uploadBytes += txDiff
                            currentRxSpeed = rxDiff
                            currentTxSpeed = txDiff
                            lastUidRxBytes = currentRxBytes
                            lastUidTxBytes = currentTxBytes
                            updateNotificationInternal()
                        }
                    }
                    Thread.sleep(1000)
                } catch (_: InterruptedException) { break } catch (e: Exception) { Log.e(TAG, "Stats error: ${e.message}") }
            }
        }
        statsTrackingThread?.start()
    }

    private fun stopStatsTracking() {
        isTrackingStats = false
        statsTrackingThread?.interrupt()
        statsTrackingThread = null
    }

    private fun updateNotificationInternal() {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, buildNotification())
    }

    private fun formatBytes(bytes: Long): String = when {
        bytes < 1024 -> "$bytes Б"
        bytes < 1024 * 1024 -> "%.2f кБ".format(bytes / 1024.0)
        bytes < 1024 * 1024 * 1024 -> "%.2f МБ".format(bytes / (1024.0 * 1024.0))
        else -> "%.2f ГБ".format(bytes / (1024.0 * 1024.0 * 1024.0))
    }

    private fun formatSpeed(bytes: Long): String = when {
        bytes < 1024 -> "$bytes Б/с"
        bytes < 1024 * 1024 -> "%.2f кБ/с".format(bytes / 1024.0)
        else -> "%.2f МБ/с".format(bytes / (1024.0 * 1024.0))
    }

    private fun buildNotification(): Notification {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                mgr.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Asteria VPN", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    setSound(null, null)
                })
            }
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
        val pendingIntent = PendingIntent.getActivity(this, 0, openAppIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stopIntent = Intent(this, LibcoreVpnService::class.java).apply { action = "STOP_VPN" }
        val stopPendingIntent = PendingIntent.getService(this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val profileName = currentProfileName ?: "Профиль"
        val transport = currentTransport?.uppercase() ?: "VLESS"
        val titleText = "Asteria • ${formatBytes(uploadBytes)}↑ ${formatBytes(downloadBytes)}↓"
        val expandedText = "$profileName\n[VLESS - $transport]\n${formatSpeed(currentTxSpeed)}↑ ${formatSpeed(currentRxSpeed)}↓"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(titleText)
            .setContentText(profileName)
            .setStyle(NotificationCompat.BigTextStyle().bigText(expandedText).setSummaryText("VPN активен"))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Остановить", stopPendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .build()
    }
}
