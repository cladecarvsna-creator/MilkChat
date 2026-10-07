package app.ryzik.chat

import android.Manifest
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import app.ryzik.chat.data.ChatRepository
import app.ryzik.chat.data.Prefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class RyzikApp : Application() {
    lateinit var prefs: Prefs
        private set
    lateinit var repo: ChatRepository
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = Prefs(this)
        repo = ChatRepository(this, prefs)
        createChannel()
        scope.launch {
            repo.incoming.collect { (chat, msg) ->
                val s = prefs.settings.first()
                val foreground = ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
                if (!s.notifications || chat.muted) return@collect
                if (chat.type == "group" && !s.groupNotifications) return@collect
                if (foreground && repo.openChatId == chat.id) return@collect
                if (foreground) return@collect
                val sender = repo.users.value[msg.senderId]?.displayName ?: "Новое сообщение"
                val title = if (chat.type == "group") "$sender · ${chat.title}" else sender
                val text = if (s.notificationPreview) {
                    msg.content?.let { repo.previewText(msg.type, it) } ?: "🔒 Сообщение"
                } else "Новое сообщение"
                notify(chat.id, title, text, s.vibrate)
            }
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL, "Сообщения", NotificationManager.IMPORTANCE_HIGH)
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun notify(chatId: String, title: String, text: String, vibrate: Boolean) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_CHAT_ID, chatId)
        }
        val pi = PendingIntent.getActivity(this, chatId.hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .apply { if (!vibrate) setVibrate(longArrayOf(0)) }
            .build()
        NotificationManagerCompat.from(this).notify(chatId.hashCode(), n)
    }

    companion object {
        const val CHANNEL = "messages"
        lateinit var instance: RyzikApp
            private set
    }
}
