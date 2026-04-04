package vpn.asteria.com

import android.app.Application
import android.os.Build
import go.Seq
import org.amnezia.awg.backend.GoBackend
import libcore.Libcore
import libcore.BoxPlatformInterface
import libcore.NB4AInterface
import libcore.LocalDNSTransport

class AsteriaApplication : Application() {

    private val platformInterface = LibcorePlatformInterface()

    override fun onCreate() {
        super.onCreate()
        GoBackend.vpnServiceClass = AsteriaAwgVpnService::class.java
        Seq.setContext(this)
        val processName = currentProcessName()
        val cachePath = cacheDir.absolutePath + "/"
        val filesPath = filesDir.absolutePath + "/"
        val externalPath = (getExternalFilesDir(null) ?: filesDir).absolutePath + "/"
        Libcore.initCore(
            processName,
            cachePath,
            filesPath,
            externalPath,
            512,
            true,
            platformInterface,
            platformInterface,
            LocalResolver
        )
    }

    private fun currentProcessName(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) getProcessName() else packageName

    fun setVpnService(service: LibcoreVpnService?) {
        platformInterface.vpnService = service
    }
}
