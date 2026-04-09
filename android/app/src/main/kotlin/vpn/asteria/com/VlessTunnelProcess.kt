package vpn.asteria.com

import android.app.ActivityManager
import android.content.Context
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets

/**
 * [LibxrayVpnService] runs in [VLESS_TUNNEL_PROCESS_SUFFIX] so Xray-core does not share native heap
 * with AmneziaWG (wg-go). Companion state is per-process; use from the main process for stats/errors.
 */
object VlessTunnelProcess {
    const val VLESS_TUNNEL_PROCESS_SUFFIX = ":xrayvpn"
    private const val STATS_FILE = "xray_vpn_stats_bytes"
    private const val TUN_ESTABLISHED_FILE = "xray_vpn_tun_established"
    private const val LAST_START_ERROR_FILE = "xray_last_start_error.txt"

    fun tunnelProcessName(context: Context): String =
        context.packageName + VLESS_TUNNEL_PROCESS_SUFFIX

    fun isTunnelProcessRunning(context: Context): Boolean {
        val want = tunnelProcessName(context)
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return am.runningAppProcesses?.any { it.processName == want } == true
    }

    fun readStatsFromDisk(context: Context): Pair<Long, Long> {
        val f = File(context.filesDir, STATS_FILE)
        if (!f.exists() || f.length() < 16) return Pair(0L, 0L)
        return try {
            FileInputStream(f).use { fis ->
                DataInputStream(fis).use { dis ->
                    Pair(dis.readLong(), dis.readLong())
                }
            }
        } catch (_: Exception) {
            Pair(0L, 0L)
        }
    }

    fun writeStatsToDisk(context: Context, upload: Long, download: Long) {
        try {
            val f = File(context.filesDir, STATS_FILE)
            FileOutputStream(f).use { fos ->
                DataOutputStream(fos).use { dos ->
                    dos.writeLong(upload)
                    dos.writeLong(download)
                }
            }
        } catch (_: Exception) {
        }
    }

    fun clearTunEstablished(context: Context) {
        try {
            File(context.filesDir, TUN_ESTABLISHED_FILE).delete()
        } catch (_: Exception) {
        }
    }

    fun setTunEstablished(context: Context) {
        try {
            FileOutputStream(File(context.filesDir, TUN_ESTABLISHED_FILE)).use { it.write(1) }
        } catch (_: Exception) {
        }
    }

    fun isVpnTunEstablished(context: Context): Boolean =
        try {
            val f = File(context.filesDir, TUN_ESTABLISHED_FILE)
            f.exists() && f.length() > 0L
        } catch (_: Exception) {
            false
        }

    fun clearLastStartError(context: Context) {
        try {
            File(context.filesDir, LAST_START_ERROR_FILE).delete()
        } catch (_: Exception) {
        }
    }

    fun setLastStartError(context: Context, message: String) {
        try {
            File(context.filesDir, LAST_START_ERROR_FILE).writeBytes(
                message.take(4000).toByteArray(StandardCharsets.UTF_8),
            )
        } catch (_: Exception) {
        }
    }

    fun getLastStartError(context: Context): String? {
        return try {
            val f = File(context.filesDir, LAST_START_ERROR_FILE)
            if (!f.exists() || f.length() == 0L) null
            else f.readText(StandardCharsets.UTF_8).trim().ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }
}
