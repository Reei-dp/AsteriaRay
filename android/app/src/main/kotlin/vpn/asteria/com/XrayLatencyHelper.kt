package vpn.asteria.com

import android.content.Context
import go.Seq
import libv2ray.Libv2ray

/** Shared libv2ray env + [MeasureOutboundDelay] for subscription latency tests. */
object XrayLatencyHelper {
    @Volatile
    private var coreEnvInitialized = false

    fun ensureCoreEnv(workDir: String) {
        synchronized(this) {
            if (!coreEnvInitialized) {
                Libv2ray.initCoreEnv(workDir, "")
                coreEnvInitialized = true
            }
        }
    }

    /**
     * Runs a short-lived Xray instance and measures HTTP RTT through the VLESS outbound.
     * @return milliseconds, or -1 on failure (matches libv2ray).
     */
    fun measureOutboundDelay(
        context: Context,
        workDir: String,
        configJson: String,
        testUrl: String,
    ): Long {
        Seq.setContext(context.applicationContext)
        ensureCoreEnv(workDir)
        return Libv2ray.measureOutboundDelay(configJson, testUrl)
    }
}
