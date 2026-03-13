package vpn.asteria.com

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import java.net.NetworkInterface

object DefaultNetworkMonitor {
    private var listener: Any? = null
    private var connectivityManager: ConnectivityManager? = null
    private var defaultNetwork: Network? = null
    
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Log.d("DefaultNetworkMonitor", "Network available: $network")
            defaultNetwork = network
            checkDefaultInterfaceUpdate(network)
        }
        
        override fun onLost(network: Network) {
            Log.d("DefaultNetworkMonitor", "Network lost: $network")
            if (defaultNetwork == network) {
                defaultNetwork = null
            }
            checkDefaultInterfaceUpdate(null)
        }
        
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            Log.d("DefaultNetworkMonitor", "Network capabilities changed: $network")
            if (defaultNetwork == network) {
                checkDefaultInterfaceUpdate(network)
            }
        }
    }
    
    fun setListener(context: Context?, newListener: Any?) {
        val oldListener = listener
        listener = newListener
        
        if (oldListener == null && newListener != null) {
            // Start monitoring
            if (context != null) {
                connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()
                connectivityManager?.registerNetworkCallback(request, networkCallback)
                
                // Get current default network
                defaultNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    connectivityManager?.activeNetwork
                } else {
                    null
                }
                
                if (defaultNetwork != null) {
                    checkDefaultInterfaceUpdate(defaultNetwork)
                }
                
                Log.d("DefaultNetworkMonitor", "Started network monitoring, defaultNetwork=$defaultNetwork")
            }
        } else if (oldListener != null && newListener == null) {
            // Stop monitoring
            connectivityManager?.unregisterNetworkCallback(networkCallback)
            connectivityManager = null
            defaultNetwork = null
            Log.d("DefaultNetworkMonitor", "Stopped network monitoring")
        }
    }
    
    private fun checkDefaultInterfaceUpdate(network: Network?) {
        // Kept for compatibility; libcore does not use interface listener
    }

    fun networkHandle(): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && defaultNetwork != null) {
            defaultNetwork!!.networkHandle
        } else {
            0L
        }
    }

    fun ensureStarted(context: Context) {
        if (connectivityManager != null) return
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager?.registerNetworkCallback(request, networkCallback)
        defaultNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) connectivityManager?.activeNetwork else null
    }

    fun ensureStopped() {
        connectivityManager?.unregisterNetworkCallback(networkCallback)
        connectivityManager = null
        defaultNetwork = null
    }
    
    fun require(): Network {
        if (defaultNetwork != null) {
            return defaultNetwork!!
        }
        // Try to get active network if defaultNetwork is null
        if (connectivityManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNetwork = connectivityManager!!.activeNetwork
            if (activeNetwork != null) {
                defaultNetwork = activeNetwork
                return activeNetwork
            }
        }
        throw IllegalStateException("No default network available")
    }
}
