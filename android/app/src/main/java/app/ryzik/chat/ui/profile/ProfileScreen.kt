package app.ryzik.chat.ui.profile

import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PersonRemove
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ryzik.chat.RyzikApp
import app.ryzik.chat.data.AuthState
import app.ryzik.chat.data.Badge
import app.ryzik.chat.data.userMessage
import app.ryzik.chat.ui.components.Avatar
import app.ryzik.chat.ui.components.BadgeChip
import app.ryzik.chat.ui.components.NameWithBadges
import app.ryzik.chat.ui.components.formatLastSeen
import kotlinx.coroutines.launch

/** Профиль пользователя. Администратор видит здесь управление бейджами. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ProfileScreen(userId: String, onBack: () -> Unit, onOpenChat: (String) -> Unit) {
    val repo = RyzikApp.instance.repo
    val users by repo.users.collectAsState()
    val auth by repo.auth.collectAsState()
    val me = (auth as? AuthState.LoggedIn)?.me
    val user = users[userId]
    val scope = rememberCoroutineScope()
    var allBadges by remember { mutableStateOf<List<Badge>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(userId) {
        runCatching { repo.loadUser(userId) }.onFailure { error = it.userMessage() }
        if (me?.isAdmin == true) allBadges = runCatching { repo.badges() }.getOrDefault(emptyList())
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("Профиль") },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Назад") } },
        )
    }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (user == null) {
                Text(error ?: "Загрузка…", Modifier.padding(32.dp))
                return@Column
            }
            val pop = remember { Animatable(0.6f) }
            LaunchedEffect(Unit) { pop.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessLow)) }
            Spacer(Modifier.height(16.dp))
            Avatar(
                user.displayName, repo.avatarUrl(user.avatarFileId), 120.dp,
                online = user.online,
                modifier = Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value },
            )
            Spacer(Modifier.height(16.dp))
            NameWithBadges(user.displayName, emptyList(), user.isAdmin, MaterialTheme.typography.headlineSmall, isPremium = user.isPremium)
            Text("@${user.username}", color = MaterialTheme.colorScheme.primary)
            Text(
                formatLastSeen(user.online, user.lastSeen),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (user.bio.isNotBlank()) {
                Spacer(Modifier.height(12.dp))
                Text(user.bio, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp))
            }

            if (user.badges.isNotEmpty() || user.isAdmin) {
                Spacer(Modifier.height(16.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    if (user.isAdmin) BadgeChip(Badge("admin", "🛡️", "Администратор", color = "#6750A4"))
                    user.badges.forEach { BadgeChip(it) }
                }
            }

            if (user.id != me?.id) {
                Spacer(Modifier.height(20.dp))
                Button(onClick = {
                    scope.launch { runCatching { repo.openDirect(user.id) }.onSuccess { onOpenChat(it.id) }.onFailure { error = it.userMessage() } }
                }) {
                    Icon(Icons.AutoMirrored.Filled.Chat, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Написать")
                }
            }

            Spacer(Modifier.height(20.dp))
            ElevatedCard(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                ListItem(
                    headlineContent = { Text("Ключ шифрования") },
                    supportingContent = {
                        Text(repo.fingerprintOf(user), fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
                    },
                    leadingContent = { Icon(Icons.Default.Lock, null) },
                )
                Text(
                    "Сверьте эти цифры с собеседником при встрече: если совпадают, никто не подменил ключи.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
                )
            }

            if (me?.isAdmin == true) {
                Spacer(Modifier.height(16.dp))
                ElevatedCard(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.AdminPanelSettings, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(8.dp))
                            Text("Администрирование", style = MaterialTheme.typography.titleMedium)
                        }
                        Spacer(Modifier.height(12.dp))
                        Text("Бейджи пользователя", style = MaterialTheme.typography.labelLarge)
                        Spacer(Modifier.height(8.dp))
                        if (allBadges.isEmpty()) {
                            Text(
                                "Бейджей пока нет. Создайте их в «Настройки → Админ-панель».",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            allBadges.forEach { b ->
                                val has = user.badges.any { it.id == b.id }
                                FilterChip(
                                    selected = has,
                                    onClick = {
                                        scope.launch {
                                            runCatching {
                                                if (has) repo.revokeBadge(user.id, b.id) else repo.grantBadge(user.id, b.id)
                                            }.onFailure { error = it.userMessage() }
                                        }
                                    },
                                    label = { Text("${b.emoji} ${b.title}") },
                                )
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Star, null)
                            Spacer(Modifier.width(8.dp))
                            Text("Премиум", Modifier.weight(1f))
                            Switch(checked = user.isPremium, onCheckedChange = { v ->
                                scope.launch { runCatching { repo.setPremium(user.id, v) }.onFailure { error = it.userMessage() } }
                            })
                        }
                        if (user.id != me?.id) {
                            Spacer(Modifier.height(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Verified, null)
                                Spacer(Modifier.width(8.dp))
                                Text("Администратор", Modifier.weight(1f))
                                Switch(checked = user.isAdmin, onCheckedChange = { v ->
                                    scope.launch { runCatching { repo.setAdmin(user.id, v) }.onFailure { error = it.userMessage() } }
                                })
                            }
                        }
                    }
                }
            }
            AnimatedVisibility(error != null) {
                Text(error.orEmpty(), color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp))
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

/** Информация о чате: для личного — профиль собеседника, для группы — участники. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ChatInfoScreen(
    chatId: String,
    onBack: () -> Unit,
    onOpenProfile: (String) -> Unit,
    onOpenChat: (String) -> Unit,
    onAddMembers: () -> Unit,
    onLeft: () -> Unit,
) {
    val repo = RyzikApp.instance.repo
    val chats by repo.chats.collectAsState()
    val users by repo.users.collectAsState()
    val chat = chats.firstOrNull { it.id == chatId }
    val scope = rememberCoroutineScope()
    var renaming by remember { mutableStateOf(false) }
    var newTitle by remember { mutableStateOf("") }
    var newDescription by remember { mutableStateOf("") }
    val myId = repo.myId

    if (chat?.type == "direct") {
        val peer = repo.peerOf(chat)
        if (peer != null) {
            ProfileScreen(peer.id, onBack, onOpenChat)
            return
        }
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text(when (chat?.type) { "saved" -> "Избранное"; "channel" -> "Канал"; else -> "Группа" }) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Назад") } },
            actions = {
                val owner = chat?.members?.any { it.user.id == myId && it.role == "owner" } == true
                if ((chat?.type == "group" && owner) || (chat?.type == "channel" && (chat.myRole == "owner" || chat.myRole == "admin"))) {
                    IconButton(onClick = { newTitle = chat.title; newDescription = chat.description; renaming = true }) { Icon(Icons.Default.Edit, "Изменить") }
                }
            },
        )
    }) { padding ->
        if (chat == null) return@Scaffold
        val owner = chat.members.any { it.user.id == myId && it.role == "owner" }
        androidx.compose.foundation.lazy.LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            item {
                Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Avatar(repo.chatTitle(chat), repo.avatarUrl(chat.avatarFileId), 110.dp, saved = chat.type == "saved")
                    Spacer(Modifier.height(12.dp))
                    Text(repo.chatTitle(chat), style = MaterialTheme.typography.headlineSmall)
                    if (chat.type == "group") Text("участников: ${chat.members.size}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (chat.type == "channel") {
                        Text(app.ryzik.chat.ui.chats.subscribersText(chat.memberCount), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (chat.description.isNotBlank()) {
                            Spacer(Modifier.height(12.dp))
                            Text(chat.description, textAlign = TextAlign.Center)
                        }
                    }
                    if (chat.type == "saved") Text(
                        "Здесь хранятся ваши заметки и сохранённые сообщения. Они тоже зашифрованы.",
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (chat.type == "channel") {
                if (chat.myRole != null) item {
                    ListItem(
                        headlineContent = { Text(if (chat.muted) "Включить звук" else "Выключить звук") },
                        leadingContent = { Icon(if (chat.muted) Icons.Default.Notifications else Icons.Default.NotificationsOff, null) },
                        modifier = Modifier.clickable { scope.launch { runCatching { repo.setMuted(chat.id, !chat.muted) } } },
                    )
                }
                item {
                    Text("Администраторы", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 16.dp, top = 8.dp))
                }
                items(chat.members.size, key = { chat.members[it].user.id }) { i ->
                    val m = chat.members[i]
                    val u = users[m.user.id] ?: m.user
                    ListItem(
                        headlineContent = { NameWithBadges(u.displayName, u.badges, u.isAdmin, MaterialTheme.typography.bodyLarge, isPremium = u.isPremium) },
                        supportingContent = { Text(if (m.role == "owner") "владелец" else "админ") },
                        leadingContent = { Avatar(u.displayName, repo.avatarUrl(u.avatarFileId), 44.dp, online = u.online) },
                        trailingContent = {
                            if (chat.myRole == "owner" && m.role == "admin") IconButton(onClick = {
                                scope.launch { runCatching { repo.setChannelAdmin(chat.id, u.id, false) } }
                            }) { Icon(Icons.Default.PersonRemove, "Снять админа") }
                        },
                        modifier = Modifier.clickable { onOpenProfile(u.id) },
                    )
                }
                item {
                    if (chat.myRole == null) {
                        ListItem(
                            headlineContent = { Text("Подписаться", color = MaterialTheme.colorScheme.primary) },
                            leadingContent = { Icon(Icons.Default.PersonAdd, null, tint = MaterialTheme.colorScheme.primary) },
                            modifier = Modifier.clickable { scope.launch { runCatching { repo.subscribe(chat.id) } } },
                        )
                    } else if (chat.myRole != "owner") {
                        ListItem(
                            headlineContent = { Text("Отписаться", color = MaterialTheme.colorScheme.error) },
                            leadingContent = { Icon(Icons.AutoMirrored.Filled.ExitToApp, null, tint = MaterialTheme.colorScheme.error) },
                            modifier = Modifier.clickable { scope.launch { runCatching { repo.leave(chat.id) }.onSuccess { onLeft() } } },
                        )
                    }
                }
            }
            if (chat.type == "group") {
                if (owner) item {
                    ListItem(
                        headlineContent = { Text("Добавить участников") },
                        leadingContent = { Icon(Icons.Default.PersonAdd, null, tint = MaterialTheme.colorScheme.primary) },
                        modifier = Modifier.clickable(onClick = onAddMembers),
                    )
                }
                items(chat.members.size, key = { chat.members[it].user.id }) { i ->
                    val m = chat.members[i]
                    val u = users[m.user.id] ?: m.user
                    ListItem(
                        headlineContent = { NameWithBadges(u.displayName, u.badges, u.isAdmin, MaterialTheme.typography.bodyLarge) },
                        supportingContent = { Text(if (m.role == "owner") "владелец" else formatLastSeen(u.online, u.lastSeen)) },
                        leadingContent = { Avatar(u.displayName, repo.avatarUrl(u.avatarFileId), 44.dp, online = u.online) },
                        trailingContent = {
                            if (owner && u.id != myId) IconButton(onClick = {
                                scope.launch { runCatching { repo.removeMember(chat.id, u.id) } }
                            }) { Icon(Icons.Default.PersonRemove, "Исключить") }
                        },
                        modifier = Modifier.animateItem().clickable { onOpenProfile(u.id) },
                    )
                }
                item {
                    ListItem(
                        headlineContent = { Text("Покинуть группу", color = MaterialTheme.colorScheme.error) },
                        leadingContent = { Icon(Icons.AutoMirrored.Filled.ExitToApp, null, tint = MaterialTheme.colorScheme.error) },
                        modifier = Modifier.clickable {
                            scope.launch { runCatching { repo.removeMember(chat.id, myId!!) }.onSuccess { onLeft() } }
                        },
                    )
                }
            }
        }
    }

    if (renaming && chat != null) {
        AlertDialog(
            onDismissRequest = { renaming = false },
            title = { Text(if (chat.type == "channel") "Канал" else "Название группы") },
            text = {
                Column {
                    OutlinedTextField(newTitle, { newTitle = it.take(128) }, singleLine = true, label = { Text("Название") })
                    if (chat.type == "channel") {
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(newDescription, { newDescription = it.take(500) }, label = { Text("Описание") }, maxLines = 5)
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    renaming = false
                    scope.launch {
                        runCatching {
                            if (chat.type == "channel") repo.updateChannel(chat.id, newTitle.trim(), newDescription.trim())
                            else repo.renameGroup(chat.id, newTitle.trim())
                        }
                    }
                }) { Text("Сохранить") }
            },
            dismissButton = { TextButton(onClick = { renaming = false }) { Text("Отмена") } },
        )
    }
}
