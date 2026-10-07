package app.ryzik.chat.ui.channel

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import app.ryzik.chat.RyzikApp
import app.ryzik.chat.data.userMessage
import app.ryzik.chat.ui.components.Avatar
import kotlinx.coroutines.launch

/** Создание канала: название и описание. Писать в канал может только владелец и его админы. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewChannelScreen(onBack: () -> Unit, onOpenChat: (String) -> Unit) {
    val repo = RyzikApp.instance.repo
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    val pop by animateFloatAsState(if (shown) 1f else 0.3f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessLow), label = "pop")

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Назад") } },
                title = { Text("Новый канал") },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {
                if (busy) return@FloatingActionButton
                if (title.isBlank()) { error = "Придумайте название канала"; return@FloatingActionButton }
                busy = true
                scope.launch {
                    runCatching { repo.createChannel(title.trim(), description.trim()) }
                        .onSuccess { onOpenChat(it.id) }
                        .onFailure { error = it.userMessage() }
                    busy = false
                }
            }) {
                if (busy) CircularProgressIndicator(Modifier.size(24.dp)) else Icon(Icons.Default.Check, "Создать")
            }
        },
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.graphicsLayer { scaleX = pop; scaleY = pop }) {
                if (title.isBlank()) {
                    Icon(Icons.Default.Campaign, null, Modifier.size(96.dp), tint = MaterialTheme.colorScheme.primary)
                } else Avatar(title, null, 96.dp)
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it.take(128); error = null },
                label = { Text("Название канала") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = description,
                onValueChange = { description = it.take(500) },
                label = { Text("Описание (необязательно)") },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )
            if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
            Text(
                "В канал пишете вы и назначенные вами админы. Остальные подписываются, читают и ставят реакции. " +
                    "Каналы публичные: их можно найти через поиск, поэтому сообщения в них не шифруются сквозным шифрованием.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(72.dp))
        }
    }
}
