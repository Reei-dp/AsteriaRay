package vpn.asteria.com

import android.content.Context

/** Synced from Flutter [AppSettingsNotifier] via MethodChannel and SharedPreferences. */
object VpnLocaleStore {
    val languageCode: String
        get() = languageCodeInternal

    @Volatile
    private var languageCodeInternal: String = "ru"

    fun setLanguageCode(code: String?) {
        if (!code.isNullOrBlank()) {
            languageCodeInternal = code
        }
    }

    fun refreshFromFlutterPrefs(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val stored = prefs.getString("flutter.settings.locale_code", null)
        if (!stored.isNullOrBlank()) {
            languageCodeInternal = stored
        }
    }

    val isEnglish: Boolean
        get() = languageCodeInternal == "en"
}
