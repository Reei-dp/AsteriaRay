package vpn.asteria.com

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.amnezia.awg.backend.GoBackend
import org.amnezia.awg.backend.Tunnel
import org.amnezia.awg.config.Config
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Wraps AmneziaWG [GoBackend] (userspace) for Flutter. All setState calls run on a single worker thread.
 */
object AwgVpnController {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var backend: GoBackend? = null
    private var activeTunnel: Tunnel? = null

    @Volatile
    private var onStopped: (() -> Unit)? = null

    /** When true, tunnel DOWN does not emit [onStopped] (AWG→VLESS handoff; avoids stale EventChannel events). */
    @Volatile
    private var suppressStoppedEvent = false

    fun setSuppressStoppedEvent(suppress: Boolean) {
        suppressStoppedEvent = suppress
    }

    /** Used by [AsteriaAwgVpnService] notification title/subtext. */
    @Volatile
    var lastAwgProfileLabel: String? = null
        private set

    /**
     * True after AmneziaWG was brought up in this process. Used for VLESS handoff: [stopSync] can be a
     * no-op (Dart already disconnected) while wg-go is still unwinding — need extra cooldown vs Xray VLESS.
     */
    @Volatile
    var awgWasUsedThisProcess: Boolean = false
        private set

    fun setOnStoppedCallback(cb: (() -> Unit)?) {
        onStopped = cb
    }

    fun isActive(): Boolean = activeTunnel != null

    fun start(
        context: Context,
        confText: String,
        displayName: String,
        done: (Result<Unit>) -> Unit,
    ) {
        executor.execute {
            try {
                val app = context.applicationContext
                if (backend == null) {
                    backend = GoBackend(app)
                }
                lastAwgProfileLabel = displayName.ifBlank { "AmneziaWG" }
                val cfg = Config.parse(
                    BufferedReader(
                        InputStreamReader(confText.byteInputStream(StandardCharsets.UTF_8)),
                    ),
                )
                val tunnelName = sanitizeTunnelName(displayName)
                val t = object : Tunnel {
                    override fun getName(): String = tunnelName

                    override fun onStateChange(newState: Tunnel.State) {
                        if (newState == Tunnel.State.DOWN) {
                            activeTunnel = null
                            lastAwgProfileLabel = null
                            if (!suppressStoppedEvent) {
                                mainHandler.post { onStopped?.invoke() }
                            }
                        }
                    }
                }
                activeTunnel = t
                backend!!.setState(t, Tunnel.State.UP, cfg)
                awgWasUsedThisProcess = true
                mainHandler.post { done(Result.success(Unit)) }
            } catch (e: Exception) {
                activeTunnel = null
                lastAwgProfileLabel = null
                mainHandler.post { done(Result.failure(e)) }
            }
        }
    }

    /**
     * Blocks until the tunnel is down (for handoff to VLESS / process stop).
     */
    fun stopSync(context: Context) {
        val latch = CountDownLatch(1)
        executor.execute {
            try {
                val b = backend
                val t = activeTunnel
                if (b != null && t != null) {
                    b.setState(t, Tunnel.State.DOWN, null)
                }
                activeTunnel = null
                lastAwgProfileLabel = null
            } catch (_: Exception) {
            } finally {
                latch.countDown()
            }
        }
        latch.await(20, TimeUnit.SECONDS)
    }

    fun getStatsUploadDownload(): Pair<Long, Long> {
        val b = backend ?: return Pair(0L, 0L)
        val t = activeTunnel ?: return Pair(0L, 0L)
        return try {
            val s = b.getStatistics(t)
            Pair(s.totalTx(), s.totalRx())
        } catch (_: Exception) {
            Pair(0L, 0L)
        }
    }

    private fun sanitizeTunnelName(name: String): String {
        val cleaned = name.replace(Regex("[^a-zA-Z0-9_=+.-]"), "_").take(15)
        return if (cleaned.isEmpty()) "AsteriaWG" else cleaned
    }
}
