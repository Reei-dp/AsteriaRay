package vpn.asteria.com

import android.content.Context

object VpnNotificationI18n {
    data class Strings(
        val channelName: String,
        val vpnActive: String,
        val stop: String,
        val profileFallback: String,
    )

    private val ru = Strings(
        channelName = "Asteria VPN",
        vpnActive = "VPN активен",
        stop = "Остановить",
        profileFallback = "Профиль",
    )

    private val uk = Strings(
        channelName = "Asteria VPN",
        vpnActive = "VPN активний",
        stop = "Зупинити",
        profileFallback = "Профіль",
    )

    private val en = Strings(
        channelName = "Asteria VPN",
        vpnActive = "VPN active",
        stop = "Stop",
        profileFallback = "Profile",
    )

    fun strings(context: Context): Strings {
        VpnLocaleStore.refreshFromFlutterPrefs(context)
        return when (VpnLocaleStore.languageCode) {
            "en" -> en
            "uk" -> uk
            else -> ru
        }
    }

    fun formatBytes(context: Context, bytes: Long): String {
        VpnLocaleStore.refreshFromFlutterPrefs(context)
        return when (VpnLocaleStore.languageCode) {
            "en" -> formatBytesEn(bytes)
            else -> formatBytesCyrillic(bytes)
        }
    }

    fun formatSpeed(context: Context, bytesPerSec: Long): String {
        VpnLocaleStore.refreshFromFlutterPrefs(context)
        return when (VpnLocaleStore.languageCode) {
            "en" -> formatSpeedEn(bytesPerSec)
            else -> formatSpeedCyrillic(bytesPerSec)
        }
    }

    private fun formatBytesCyrillic(bytes: Long): String = when {
        bytes < 1024 -> "$bytes Б"
        bytes < 1024 * 1024 -> "%.2f КБ".format(bytes / 1024.0)
        bytes < 1024 * 1024 * 1024 -> "%.2f МБ".format(bytes / (1024.0 * 1024.0))
        else -> "%.2f ГБ".format(bytes / (1024.0 * 1024.0 * 1024.0))
    }

    private fun formatBytesEn(bytes: Long): String = when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 -> "%.2f KB".format(bytes / 1024.0)
        bytes < 1024 * 1024 * 1024 -> "%.2f MB".format(bytes / (1024.0 * 1024.0))
        else -> "%.2f GB".format(bytes / (1024.0 * 1024.0 * 1024.0))
    }

    private fun formatSpeedCyrillic(bytesPerSec: Long): String = when {
        bytesPerSec < 1024 -> "$bytesPerSec Б/с"
        bytesPerSec < 1024 * 1024 -> "%.2f КБ/с".format(bytesPerSec / 1024.0)
        else -> "%.2f МБ/с".format(bytesPerSec / (1024.0 * 1024.0))
    }

    private fun formatSpeedEn(bytesPerSec: Long): String = when {
        bytesPerSec < 1024 -> "$bytesPerSec B/s"
        bytesPerSec < 1024 * 1024 -> "%.2f KB/s".format(bytesPerSec / 1024.0)
        else -> "%.2f MB/s".format(bytesPerSec / (1024.0 * 1024.0))
    }
}
