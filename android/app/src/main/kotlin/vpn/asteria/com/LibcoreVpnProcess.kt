package vpn.asteria.com

import android.app.ActivityManager
import android.content.Context
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * LibcoreVpnService runs in [LIBCORE_PROCESS_SUFFIX] so sing-box does not share native heap with
 * AmneziaWG (wg-go). Companion-object state is per-process; use this helper from the main process.
 */
object LibcoreVpnProcess {
    const val LIBCORE_PROCESS_SUFFIX = ":libcorevpn"
    private const val STATS_FILE = "libcore_vpn_stats_bytes"

    fun libcoreProcessName(context: Context): String =
        context.packageName + LIBCORE_PROCESS_SUFFIX

    fun isLibcoreProcessRunning(context: Context): Boolean {
        val want = libcoreProcessName(context)
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
}
