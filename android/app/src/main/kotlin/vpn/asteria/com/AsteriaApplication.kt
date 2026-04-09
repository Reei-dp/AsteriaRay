package vpn.asteria.com

import android.app.Application
import go.Seq
import org.amnezia.awg.backend.GoBackend

class AsteriaApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        GoBackend.vpnServiceClass = AsteriaAwgVpnService::class.java
        // Required by gomobile (AmneziaWG / libv2ray).
        Seq.setContext(this)
    }
}
