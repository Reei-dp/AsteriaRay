package vpn.asteria.com

import android.os.Build
import libcore.BoxPlatformInterface
import libcore.NB4AInterface

class LibcorePlatformInterface : BoxPlatformInterface, NB4AInterface {

    var vpnService: LibcoreVpnService? = null

    override fun autoDetectInterfaceControl(fd: Int) {
        vpnService?.protect(fd)
    }

    override fun openTun(singTunOptionsJson: String, tunPlatformOptionsJson: String): Long {
        val service = vpnService ?: throw IllegalStateException("VPN service not set")
        return service.startVpn(singTunOptionsJson, tunPlatformOptionsJson).toLong()
    }

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        ipProto: Int,
        srcIp: String,
        srcPort: Int,
        destIp: String,
        destPort: Int
    ): Int = android.os.Process.myUid()

    override fun packageNameByUid(uid: Int): String {
        return (vpnService?.packageManager?.getPackagesForUid(uid))?.firstOrNull()
            ?: "android"
    }

    override fun uidByPackageName(packageName: String): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vpnService?.packageManager?.getPackageUid(
                    packageName,
                    android.content.pm.PackageManager.PackageInfoFlags.of(0)
                ) ?: 0
            } else {
                @Suppress("DEPRECATION")
                vpnService?.packageManager?.getPackageUid(packageName, 0) ?: 0
            }
        } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
            0
        }
    }

    override fun wifiState(): String = ""

    override fun useOfficialAssets(): Boolean = true

    override fun selector_OnProxySelected(selectorTag: String, tag: String) {}
}
