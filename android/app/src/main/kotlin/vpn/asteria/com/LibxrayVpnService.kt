package vpn.asteria.com

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.util.Log
import androidx.core.app.NotificationCompat
import go.Seq
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray
import libv2ray.Protector
import java.io.File

/**
 * VLESS via **Xray-core** ([AndroidLibXrayLite]): [CoreController.startLoop] with VPN
 * [ParcelFileDescriptor.fd] as `xray.tun.fd` (see upstream [libv2ray_main.go]).
 */
class LibxrayVpnService : VpnService() {

    companion object {
        private const val TAG = "LibxrayVpnService"
        const val ACTION_STOP_VPN = "vpn.asteria.ACTION_STOP_XRAY_VPN"
        const val ACTION_XRAY_VPN_STOPPED = "vpn.asteria.ACTION_XRAY_VPN_STOPPED"
        private const val CHANNEL_ID = "asteria_vpn_channel"
        private const val NOTIFICATION_ID = 101
        private const val EXTRA_CONFIG = "configPath"
        private const val EXTRA_PROFILE_NAME = "profileName"
        private const val EXTRA_TRANSPORT = "transport"
        private var coreController: CoreController? = null
        private var fileDescriptor: ParcelFileDescriptor? = null
        private var uploadBytes: Long = 0L
        private var downloadBytes: Long = 0L
        private var lastRxBytes: Long = 0L
        private var lastTxBytes: Long = 0L
        private var currentProfileName: String? = null
        private var currentTransport: String? = null
        private var serviceInstance: LibxrayVpnService? = null
        @Volatile
        private var coreEnvInitialized = false

        fun start(context: Context, configPath: String, profileName: String? = null, transport: String? = null) {
            val intent = Intent(context, LibxrayVpnService::class.java).apply {
                putExtra(EXTRA_CONFIG, configPath)
                putExtra(EXTRA_PROFILE_NAME, profileName)
                putExtra(EXTRA_TRANSPORT, transport)
            }
            Log.i(TAG, "Request LibxrayVpnService (caller pid=${Process.myPid()}) config=$configPath transport=$transport")
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
            val intent = Intent(context, LibxrayVpnService::class.java).apply {
                action = ACTION_STOP_VPN
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.w(TAG, "startService(ACTION_STOP_VPN) failed, fallback stopService", e)
                try {
                    context.stopService(Intent(context, LibxrayVpnService::class.java))
                } catch (e2: Exception) {
                    Log.w(TAG, "stopService fallback failed", e2)
                }
            }
        }

        fun getStats(context: Context): Pair<Long, Long> = VlessTunnelProcess.readStatsFromDisk(context)

        fun isXrayTunnelRunning(context: Context): Boolean =
            VlessTunnelProcess.isTunnelProcessRunning(context)

        fun updateStats(upload: Long, download: Long) {
            uploadBytes = upload
            downloadBytes = download
        }
    }

    private var currentRxSpeed: Long = 0L
    private var currentTxSpeed: Long = 0L
    private var statsTrackingThread: Thread? = null
    private var isTrackingStats = false

    private fun shutdownVpnSession() {
        VlessTunnelProcess.clearTunEstablished(applicationContext)
        stopStatsTracking()
        try {
            coreController?.stopLoop()
        } catch (t: Throwable) {
            Log.e(TAG, "coreController.stopLoop", t)
        }
        coreController = null
        try {
            fileDescriptor?.close()
        } catch (_: Exception) {
        }
        fileDescriptor = null
        DefaultNetworkMonitor.ensureStopped()
        uploadBytes = 0L
        downloadBytes = 0L
        lastRxBytes = 0L
        lastTxBytes = 0L
        currentProfileName = null
        currentTransport = null
        serviceInstance = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand pid=${Process.myPid()} action=${intent?.action} hasConfig=${!intent?.getStringExtra(EXTRA_CONFIG).isNullOrEmpty()}")
        if (intent?.action == ACTION_STOP_VPN) {
            Log.i(TAG, "ACTION_STOP_VPN: shutdown tunnel → stopForeground → stopSelf")
            shutdownVpnSession()
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(Service.STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(false)
                }
            } catch (e: Exception) {
                Log.w(TAG, "stopForeground", e)
            }
            stopSelf()
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
        Seq.setContext(applicationContext)

        DefaultNetworkMonitor.ensureStarted(this)

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        try {
            Log.i(TAG, "step: read config")
            val configContent = File(configPath).readText()
            if (configContent.isBlank()) {
                Log.e(TAG, "Config is empty")
                stopSelf()
                return START_NOT_STICKY
            }

            VlessTunnelProcess.clearTunEstablished(applicationContext)
            VlessTunnelProcess.clearLastStartError(applicationContext)

            try {
                coreController?.stopLoop()
            } catch (_: Throwable) {
            }
            coreController = null

            Log.i(TAG, "step: establish VPN interface")
            val pfd = tryEstablishVpnTun()
            fileDescriptor = pfd

            val workDirPath = File(configPath).parentFile?.absolutePath
            if (workDirPath != null) {
                synchronized(LibxrayVpnService::class.java) {
                    if (!coreEnvInitialized) {
                        Libv2ray.initCoreEnv(workDirPath, "")
                        coreEnvInitialized = true
                    }
                }
            }

            // Matches gomobile bindings (see v2rayNG CoreCallback : CoreCallbackHandler).
            val cb = object : CoreCallbackHandler {
                override fun startup(): Long = 0L
                override fun shutdown(): Long = 0L
                override fun onEmitStatus(l: Long, s: String?): Long = 0L
            }

            coreController = Libv2ray.newCoreController(cb)
            // Outbound sockets must bypass the VPN interface or uplink traffic loops into TUN (Go ignores addDisallowedApplication).
            Libv2ray.registerProtector(
                object : Protector {
                    override fun protectFd(fd: Int): Boolean = protect(fd)
                },
            )
            Log.i(TAG, "step: Xray startLoop (tun fd=${pfd.fd})")
            coreController!!.startLoop(configContent, pfd.fd)

            startStatsTracking()
            Log.i(TAG, "Xray service started")
        } catch (e: Throwable) {
            val msg = e.message ?: e.javaClass.simpleName
            VlessTunnelProcess.setLastStartError(applicationContext, msg)
            Log.e(TAG, "Failed to start Xray service: $msg", e)
            shutdownVpnSession()
            stopSelf()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        shutdownVpnSession()
        super.onDestroy()
        sendStoppedBroadcast()
    }

    private fun sendStoppedBroadcast() {
        try {
            sendBroadcast(
                Intent(ACTION_XRAY_VPN_STOPPED).setPackage(packageName),
            )
        } catch (e: Exception) {
            Log.w(TAG, "sendStoppedBroadcast", e)
        }
    }

    override fun onBind(intent: Intent?) = null

    /** Fresh [Builder] each attempt — [Builder.establish] may not be safely retried on one builder. */
    private fun tryEstablishVpnTun(): ParcelFileDescriptor {
        if (prepare(this) != null) {
            throw IllegalStateException("VPN permission not granted")
        }

        val mtu = 1500
        val addresses = mutableListOf<Pair<String, Int>>()
        addresses.add(Pair("172.19.0.1", 30))
        addresses.add(Pair("fdfe:dcba:9876::1", 126))

        val hasIpv4 = addresses.any { !it.first.contains(":") }
        val hasIpv6 = addresses.any { it.first.contains(":") }

        var pfd: ParcelFileDescriptor? = null
        repeat(8) { attempt ->
            pfd = tryEstablishVpnTunOnce(mtu, addresses, hasIpv4, hasIpv6)
            if (pfd != null) {
                VlessTunnelProcess.setTunEstablished(applicationContext)
                Log.i(TAG, "VPN established fd=${pfd!!.fd}")
                return pfd!!
            }
            Log.w(TAG, "establish() returned null (attempt ${attempt + 1}/8), VPN slot may be busy")
            try {
                Thread.sleep(400)
            } catch (_: InterruptedException) {
            }
        }
        throw IllegalStateException("Failed to establish VPN")
    }

    private fun tryEstablishVpnTunOnce(
        mtu: Int,
        addresses: MutableList<Pair<String, Int>>,
        hasIpv4: Boolean,
        hasIpv6: Boolean,
    ): ParcelFileDescriptor? {
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

        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            Log.w(TAG, "addDisallowedApplication", e)
        }

        for ((addr, prefix) in addresses) {
            builder.addAddress(addr, prefix)
        }

        if (hasIpv4) builder.addDnsServer("172.19.0.2")
        if (hasIpv6) builder.addDnsServer("fdfe:dcba:9876::2")
        if (!hasIpv4 && !hasIpv6) builder.addDnsServer("172.19.0.2")
        if (hasIpv4) builder.addRoute("172.19.0.2", 32)
        builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val network = (getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)?.activeNetwork
                ?: try { DefaultNetworkMonitor.require() } catch (_: Exception) { null }
            network?.let { builder.setUnderlyingNetworks(arrayOf(it)) }
        }

        return builder.establish()
    }

    private fun startStatsTracking() {
        isTrackingStats = true
        val appUid = Process.myUid()
        statsTrackingThread = Thread {
            var lastUidRxBytes = TrafficStats.getUidRxBytes(appUid)
            var lastUidTxBytes = TrafficStats.getUidTxBytes(appUid)
            while (isTrackingStats) {
                try {
                    if (coreController != null) {
                        val currentRxBytes = TrafficStats.getUidRxBytes(appUid)
                        val currentTxBytes = TrafficStats.getUidTxBytes(appUid)
                        if (currentRxBytes != TrafficStats.UNSUPPORTED.toLong() &&
                            currentTxBytes != TrafficStats.UNSUPPORTED.toLong()
                        ) {
                            val rxDiff = if (lastUidRxBytes > 0 && currentRxBytes >= lastUidRxBytes) currentRxBytes - lastUidRxBytes else 0L
                            val txDiff = if (lastUidTxBytes > 0 && currentTxBytes >= lastUidTxBytes) currentTxBytes - lastUidTxBytes else 0L
                            downloadBytes += rxDiff
                            uploadBytes += txDiff
                            currentRxSpeed = rxDiff
                            currentTxSpeed = txDiff
                            lastUidRxBytes = currentRxBytes
                            lastUidTxBytes = currentTxBytes
                            VlessTunnelProcess.writeStatsToDisk(applicationContext, uploadBytes, downloadBytes)
                            updateNotificationInternal()
                        }
                    }
                    Thread.sleep(1000)
                } catch (_: InterruptedException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Stats error: ${e.message}")
                }
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
        val stopIntent = Intent(this, LibxrayVpnService::class.java).apply { action = ACTION_STOP_VPN }
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
