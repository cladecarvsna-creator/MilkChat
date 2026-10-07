package app.ryzik.chat.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import app.ryzik.chat.BuildConfig
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.store by preferencesDataStore("ryzikchat")

enum class ThemeMode(val title: String) { System("Как в системе"), Light("Светлая"), Dark("Тёмная") }

/** Все пользовательские настройки приложения. */
data class AppSettings(
    val onboardingDone: Boolean = false,
    val themeMode: ThemeMode = ThemeMode.System,
    val dynamicColor: Boolean = true,
    val seedColor: Int = 0,
    val amoled: Boolean = false,
    val textSize: Float = 16f,
    val bubbleRadius: Float = 18f,
    val wallpaper: Int = 0,
    val sendByEnter: Boolean = false,
    val swipeToReply: Boolean = true,
    val animations: Boolean = true,
    val autoDownload: Boolean = true,
    val notifications: Boolean = true,
    val notificationPreview: Boolean = true,
    val groupNotifications: Boolean = true,
    val vibrate: Boolean = true,
    val showReadReceipts: Boolean = true,
    val showTyping: Boolean = true,
    val compactList: Boolean = false,
    val bigEmoji: Boolean = true,
    val quickReaction: String = "❤️",
)

/** Данные текущей сессии. Приватный ключ хранится обёрнутым ключом Android Keystore. */
data class StoredSession(
    val serverUrl: String,
    val token: String?,
    val userId: String?,
    val username: String?,
    val wrappedPrivateKey: String?,
)

class Prefs(private val context: Context) {
    private object K {
        val onboarding = booleanPreferencesKey("onboarding_done")
        val theme = stringPreferencesKey("theme_mode")
        val dynamic = booleanPreferencesKey("dynamic_color")
        val seed = intPreferencesKey("seed_color")
        val amoled = booleanPreferencesKey("amoled")
        val textSize = floatPreferencesKey("text_size")
        val radius = floatPreferencesKey("bubble_radius")
        val wallpaper = intPreferencesKey("wallpaper")
        val sendByEnter = booleanPreferencesKey("send_by_enter")
        val swipeReply = booleanPreferencesKey("swipe_reply")
        val animations = booleanPreferencesKey("animations")
        val autoDownload = booleanPreferencesKey("auto_download")
        val notifications = booleanPreferencesKey("notifications")
        val notifPreview = booleanPreferencesKey("notif_preview")
        val groupNotif = booleanPreferencesKey("group_notif")
        val vibrate = booleanPreferencesKey("vibrate")
        val readReceipts = booleanPreferencesKey("read_receipts")
        val typing = booleanPreferencesKey("typing")
        val compact = booleanPreferencesKey("compact_list")
        val bigEmoji = booleanPreferencesKey("big_emoji")
        val quickReaction = stringPreferencesKey("quick_reaction")

        val server = stringPreferencesKey("server_url")
        val token = stringPreferencesKey("token")
        val userId = stringPreferencesKey("user_id")
        val username = stringPreferencesKey("username")
        val privKey = stringPreferencesKey("wrapped_private_key")
    }

    val settings: Flow<AppSettings> = context.store.data.map { read(it) }

    private fun read(p: Preferences): AppSettings {
        val d = AppSettings()
        return AppSettings(
            onboardingDone = p[K.onboarding] ?: d.onboardingDone,
            themeMode = p[K.theme]?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() } ?: d.themeMode,
            dynamicColor = p[K.dynamic] ?: d.dynamicColor,
            seedColor = p[K.seed] ?: d.seedColor,
            amoled = p[K.amoled] ?: d.amoled,
            textSize = p[K.textSize] ?: d.textSize,
            bubbleRadius = p[K.radius] ?: d.bubbleRadius,
            wallpaper = p[K.wallpaper] ?: d.wallpaper,
            sendByEnter = p[K.sendByEnter] ?: d.sendByEnter,
            swipeToReply = p[K.swipeReply] ?: d.swipeToReply,
            animations = p[K.animations] ?: d.animations,
            autoDownload = p[K.autoDownload] ?: d.autoDownload,
            notifications = p[K.notifications] ?: d.notifications,
            notificationPreview = p[K.notifPreview] ?: d.notificationPreview,
            groupNotifications = p[K.groupNotif] ?: d.groupNotifications,
            vibrate = p[K.vibrate] ?: d.vibrate,
            showReadReceipts = p[K.readReceipts] ?: d.showReadReceipts,
            showTyping = p[K.typing] ?: d.showTyping,
            compactList = p[K.compact] ?: d.compactList,
            bigEmoji = p[K.bigEmoji] ?: d.bigEmoji,
            quickReaction = p[K.quickReaction] ?: d.quickReaction,
        )
    }

    suspend fun update(block: (AppSettings) -> AppSettings) {
        context.store.edit { p ->
            val s = block(read(p))
            p[K.onboarding] = s.onboardingDone
            p[K.theme] = s.themeMode.name
            p[K.dynamic] = s.dynamicColor
            p[K.seed] = s.seedColor
            p[K.amoled] = s.amoled
            p[K.textSize] = s.textSize
            p[K.radius] = s.bubbleRadius
            p[K.wallpaper] = s.wallpaper
            p[K.sendByEnter] = s.sendByEnter
            p[K.swipeReply] = s.swipeToReply
            p[K.animations] = s.animations
            p[K.autoDownload] = s.autoDownload
            p[K.notifications] = s.notifications
            p[K.notifPreview] = s.notificationPreview
            p[K.groupNotif] = s.groupNotifications
            p[K.vibrate] = s.vibrate
            p[K.readReceipts] = s.showReadReceipts
            p[K.typing] = s.showTyping
            p[K.compact] = s.compactList
            p[K.bigEmoji] = s.bigEmoji
            p[K.quickReaction] = s.quickReaction
        }
    }

    val session: Flow<StoredSession> = context.store.data.map { p ->
        StoredSession(
            serverUrl = p[K.server] ?: BuildConfig.DEFAULT_SERVER,
            token = p[K.token],
            userId = p[K.userId],
            username = p[K.username],
            wrappedPrivateKey = p[K.privKey],
        )
    }

    suspend fun setServer(url: String) {
        context.store.edit { it[K.server] = url.trim().trimEnd('/') }
    }

    suspend fun saveSession(token: String, userId: String, username: String, wrappedPrivateKey: String) {
        context.store.edit {
            it[K.token] = token
            it[K.userId] = userId
            it[K.username] = username
            it[K.privKey] = wrappedPrivateKey
        }
    }

    suspend fun saveWrappedKey(wrappedPrivateKey: String) {
        context.store.edit { it[K.privKey] = wrappedPrivateKey }
    }

    suspend fun clearSession() {
        context.store.edit {
            it.remove(K.token)
            it.remove(K.userId)
            it.remove(K.username)
            it.remove(K.privKey)
        }
    }
}
