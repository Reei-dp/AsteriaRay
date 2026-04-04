package vpn.asteria.com

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val statsExecutor = Executors.newSingleThreadExecutor()
    /** VPN handoff uses [CountDownLatch.await]; must not run on the main thread (onDestroy runs on main). */
    private val vpnHandoffExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val channelName = "lumaray/vpn"
    private val eventChannelName = "lumaray/vpn/events"
    private val requestVpn = 1001
    private var pendingResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private val libcoreStoppedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            eventSink?.success(EVENT_VPN_STOPPED_LIBCORE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler(::handleMethodCall)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        ContextCompat.registerReceiver(
            this,
            libcoreStoppedReceiver,
            IntentFilter(LibcoreVpnService.ACTION_LIBCORE_VPN_STOPPED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        AwgVpnController.setOnStoppedCallback {
            eventSink?.success(EVENT_VPN_STOPPED_AWG)
        }
    }

    companion object {
        /** EventChannel payloads — Dart filters stale teardown vs active tunnel. */
        const val EVENT_VPN_STOPPED_LIBCORE = "vpnStopped:libcore"
        const val EVENT_VPN_STOPPED_AWG = "vpnStopped:awg"
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareVpn" -> prepareVpn(result)
            "startVpn" -> handleStartVpn(call, result)
            "stopVpn" -> {
                AwgVpnController.stopSync(this)
                LibcoreVpnService.stop(this)
                result.success(true)
            }
            "getStats" -> {
                statsExecutor.execute {
                    val stats = try {
                        if (AwgVpnController.isActive()) {
                            AwgVpnController.getStatsUploadDownload()
                        } else {
                            LibcoreVpnService.getStats(this@MainActivity)
                        }
                    } catch (e: Exception) {
                        Log.w("MainActivity", "getStats failed", e)
                        Pair(0L, 0L)
                    }
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "upload" to stats.first,
                                "download" to stats.second,
                            ),
                        )
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleStartVpn(call: MethodCall, result: MethodChannel.Result) {
        val mode = call.argument<String>("mode") ?: "singbox"
        if (mode == "awg") {
            val conf = call.argument<String>("conf")
            val profileName = call.argument<String>("profileName") ?: "AWG"
            if (conf.isNullOrBlank()) {
                result.error("args", "Missing conf", null)
                return
            }
            vpnHandoffExecutor.execute {
                try {
                    val hadLibcore = LibcoreVpnService.isLibcoreRunning(this@MainActivity)
                    LibcoreVpnService.stop(this@MainActivity)
                    if (hadLibcore) {
                        var waited = 0L
                        while (LibcoreVpnService.isLibcoreRunning(this@MainActivity) && waited < 5000) {
                            Thread.sleep(100)
                            waited += 100
                        }
                    }
                    sleepAfterVpnHandoff(100L)
                    AwgVpnController.start(this@MainActivity, conf, profileName) { res ->
                        if (res.isSuccess) {
                            result.success(true)
                        } else {
                            val err = res.exceptionOrNull()
                            Log.e("MainActivity", "AWG start failed", err)
                            result.error("awg", err?.message ?: "unknown", null)
                        }
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "AWG handoff failed", e)
                    mainHandler.post { result.error("handoff", e.message ?: "unknown", null) }
                }
            }
            return
        }

        val configPath = call.argument<String>("configPath")
        val profileName = call.argument<String>("profileName")
        val transport = call.argument<String>("transport")
        if (configPath == null) {
            result.error("args", "Missing configPath", null)
            return
        }
        vpnHandoffExecutor.execute {
            AwgVpnController.setSuppressStoppedEvent(true)
            try {
                val hadAwgTunnel = AwgVpnController.isActive()
                // Tunnel can be DOWN while AsteriaAwgVpnService is still alive (async stopSelf / onDestroy).
                val awgServiceAlive = AsteriaAwgVpnService.isServiceInstanceAlive()
                val awgUsedBefore = AwgVpnController.awgWasUsedThisProcess
                val needAwgTeardownWait = hadAwgTunnel || awgServiceAlive
                val awgLatch = if (needAwgTeardownWait) {
                    CountDownLatch(1).also { AsteriaAwgVpnService.armDestroyLatch(it) }
                } else {
                    null
                }
                try {
                    AwgVpnController.stopSync(this@MainActivity)
                    if (awgUsedBefore || awgServiceAlive) {
                        try {
                            stopService(Intent(this@MainActivity, AsteriaAwgVpnService::class.java))
                        } catch (e: Exception) {
                            Log.w("MainActivity", "stopService(AsteriaAwgVpnService)", e)
                        }
                    }
                    awgLatch?.await(8, TimeUnit.SECONDS)
                } finally {
                    if (needAwgTeardownWait) AsteriaAwgVpnService.clearDestroyLatch()
                }
                // VLESS→AWG: Libcore onDestroy is waited. AWG→VLESS: stopSync is often a no-op while wg-go
                // still unwinds — long cooldown when awgWasUsedThisProcess (see AwgVpnController).
                // awgUsedBefore: stopSync may be no-op after Flutter disconnect(); extra ms for wg-go + VPN slot.
                // If logs show AWG fully down before this line, "Lost connection" right after Libcore is usually ADB, not a crash.
                // After AWG, wg-go must fully quiesce; starting Libcore from the main looper has crashed
                // libwg-go (SIGSEGV on main) — keep startForegroundService off the UI thread here.
                val cooldownMs = when {
                    needAwgTeardownWait -> 1800L
                    awgUsedBefore -> 3500L
                    else -> 200L
                }
                sleepAfterVpnHandoff(cooldownMs)
                Log.i(
                    "MainActivity",
                    "VLESS handoff: after ${cooldownMs}ms cooldown → Libcore start on handoff thread (hadTunnel=$hadAwgTunnel awgAlive=$awgServiceAlive needWait=$needAwgTeardownWait awgUsedBefore=$awgUsedBefore)",
                )
                LibcoreVpnService.start(this@MainActivity, configPath, profileName, transport)
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e("MainActivity", "VLESS handoff failed", e)
                mainHandler.post { result.error("handoff", e.message ?: "unknown", null) }
            } finally {
                AwgVpnController.setSuppressStoppedEvent(false)
            }
        }
    }

    /**
     * Android releases the VPN slot asynchronously after [VpnService.stopSelf]. Starting another
     * VpnService (Libcore vs AmneziaWG) immediately can crash or fail establish(); a short pause avoids that.
     */
    private fun sleepAfterVpnHandoff(ms: Long) {
        try {
            Thread.sleep(ms)
        } catch (_: InterruptedException) {
        }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingResult = result
            startActivityForResult(intent, requestVpn)
        } else {
            result.success(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestVpn) {
            val res = pendingResult
            pendingResult = null
            if (res != null) {
                res.success(resultCode == Activity.RESULT_OK)
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(libcoreStoppedReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
