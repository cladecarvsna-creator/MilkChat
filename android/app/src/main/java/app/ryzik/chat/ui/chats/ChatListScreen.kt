package app.ryzik.chat.ui.chats

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Unarchive
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ryzik.chat.RyzikApp
import app.ryzik.chat.data.AuthState
import app.ryzik.chat.data.Chat
import app.ryzik.chat.data.User
import app.ryzik.chat.ui.components.Avatar
import app.ryzik.chat.ui.components.BadgeIcons
import app.ryzik.chat.ui.components.TypingDots
import app.ryzik.chat.ui.components.formatListTime
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Filter(val title: String) { All("Все"), Unread("Непрочитанные"), Personal("Личные"), Groups("Группы") }

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ChatListScreen(
    onOpenChat: (String) -> Unit,
    onNewChat: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenProfile: (String) -> Unit,
) {
    val app = RyzikApp.instance
    val repo = app.repo
    val chats by repo.chats.collectAsState()
    val users by repo.users.collectAsState()
    val typing by repo.typing.collectAsState()
    val connected by repo.connected.collectAsState()
    val loading by repo.chatsLoading.collectAsState()
    val auth by repo.auth.collectAsState()
    val settings by app.prefs.settings.collectAsState(initial = null)
    val me = (auth as? AuthState.LoggedIn)?.me
    val scope = rememberCoroutineScope()

    var searching by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    var foundUsers by remember { mutableStateOf<List<User>>(emptyList()) }
    var filter by remember { mutableStateOf(Filter.All) }
    var showArchive by remember { mutableStateOf(false) }
    var menuChat by remember { mutableStateOf<Chat?>(null) }

    LaunchedEffect(query) {
        if (query.length < 2) { foundUsers = emptyList(); return@LaunchedEffect }
        delay(300)
        foundUsers = runCatching { repo.searchUsers(query) }.getOrDefault(emptyList())
    }

    val listState = rememberLazyListState()
    val expandedFab by remember { derivedStateOf { listState.firstVisibleItemIndex == 0 } }
    val scroll = TopAppBarDefaults.pinnedScrollBehavior()

    val archivedCount = chats.count { it.archived }
    val visible = chats.filter { c ->
        val title = repo.chatTitle(c)
        (if (showArchive) c.archived else !c.archived) &&
            (query.isBlank() || title.contains(query, ignoreCase = true)) &&
            when (filter) {
                Filter.All -> true
                Filter.Unread -> c.unread > 0
                Filter.Personal -> c.type != "group"
                Filter.Groups -> c.type == "group"
            }
    }

    Scaffold(
        modifier = Modifier.nestedScroll(scroll.nestedScrollConnection),
        topBar = {
            Column {
                TopAppBar(
                    scrollBehavior = scroll,
                    navigationIcon = {
                        AnimatedContent(searching || showArchive, label = "nav") { back ->
                            if (back) IconButton(onClick = { searching = false; query = ""; showArchive = false }) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, "Назад")
                            } else IconButton(onClick = onOpenSettings) {
                                Avatar(me?.displayName ?: "?", repo.avatarUrl(me?.avatarFileId), 34.dp)
                            }
                        }
                    },
                    title = {
                        AnimatedContent(searching, label = "title", transitionSpec = { fadeIn() togetherWith fadeOut() }) { s ->
                            if (s) TextField(
                                value = query,
                                onValueChange = { query = it },
                                placeholder = { Text("Поиск чатов и людей") },
                                singleLine = true,
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0f),
                                    unfocusedContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0f),
                                    focusedIndicatorColor = MaterialTheme.colorScheme.surface.copy(alpha = 0f),
                                    unfocusedIndicatorColor = MaterialTheme.colorScheme.surface.copy(alpha = 0f),
                                ),
                                modifier = Modifier.fillMaxWidth(),
                            ) else Column {
                                Text(if (showArchive) "Архив" else "RyzikChat", fontWeight = FontWeight.Bold)
                                AnimatedVisibility(!connected) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("Соединение", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Spacer(Modifier.width(4.dp))
                                        TypingDots(MaterialTheme.colorScheme.onSurfaceVariant, 3.dp)
                                    }
                                }
                            }
                        }
                    },
                    actions = {
                        AnimatedContent(searching, label = "act") { s ->
                            if (s) IconButton(onClick = { query = "" }) { Icon(Icons.Default.Close, "Очистить") }
                            else IconButton(onClick = { searching = true }) { Icon(Icons.Default.Search, "Поиск") }
                        }
                    },
                )
                AnimatedVisibility(!searching && !showArchive) {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(bottom = 4.dp),
                    ) {
                        items(Filter.entries) { f ->
                            FilterChip(selected = filter == f, onClick = { filter = f }, label = { Text(f.title) })
                        }
                    }
                }
                AnimatedVisibility(loading && chats.isEmpty()) { LinearProgressIndicator(Modifier.fillMaxWidth()) }
            }
        },
        floatingActionButton = {
            AnimatedVisibility(!searching, enter = scaleIn(spring(Spring.DampingRatioMediumBouncy)), exit = scaleOut()) {
                ExtendedFloatingActionButton(
                    onClick = onNewChat,
                    expanded = expandedFab,
                    icon = { Icon(Icons.Default.Edit, null) },
                    text = { Text("Новый чат") },
                )
            }
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = loading,
            onRefresh = { scope.launch { repo.refreshChats() } },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LazyColumn(state = listState, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 96.dp)) {
                if (!searching && !showArchive && archivedCount > 0) {
                    item(key = "archive") {
                        ListItem(
                            headlineContent = { Text("Архив") },
                            supportingContent = { Text("Чатов: $archivedCount") },
                            leadingContent = {
                                Box(Modifier.size(56.dp).clip(CircleShape).background(MaterialTheme.colorScheme.secondaryContainer), contentAlignment = Alignment.Center) {
                                    Icon(Icons.Default.Archive, null, tint = MaterialTheme.colorScheme.onSecondaryContainer)
                                }
                            },
                            modifier = Modifier.animateItem().combinedClickable(onClick = { showArchive = true }),
                        )
                    }
                }
                items(visible, key = { it.id }) { chat ->
                    ChatRow(
                        chat = chat,
                        title = repo.chatTitle(chat),
                        peer = repo.peerOf(chat)?.let { users[it.id] ?: it },
                        preview = repo.previewOf(chat.lastMessage),
                        typingNames = typing[chat.id].orEmpty().keys.mapNotNull { users[it]?.displayName },
                        myId = me?.id,
                        compact = settings?.compactList == true,
                        avatarUrl = repo.avatarUrl(if (chat.type == "direct") repo.peerOf(chat)?.avatarFileId else chat.avatarFileId),
                        modifier = Modifier
                            .animateItem()
                            .combinedClickable(onClick = { onOpenChat(chat.id) }, onLongClick = { menuChat = chat }),
                    )
                }
                if (searching && foundUsers.isNotEmpty()) {
                    item(key = "people") {
                        Text(
                            "Люди",
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
                        )
                    }
                    items(foundUsers, key = { "u_" + it.id }) { u ->
                        ListItem(
                            headlineContent = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(u.displayName, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    BadgeIcons(u.badges, u.isAdmin)
                                }
                            },
                            supportingContent = { Text("@${u.username}") },
                            leadingContent = { Avatar(u.displayName, repo.avatarUrl(u.avatarFileId), 48.dp, online = u.online) },
                            modifier = Modifier.animateItem().combinedClickable(
                                onClick = {
                                    scope.launch {
                                        runCatching { repo.openDirect(u.id) }.onSuccess { onOpenChat(it.id) }
                                    }
                                },
                                onLongClick = { onOpenProfile(u.id) },
                            ),
                        )
                    }
                }
                if (visible.isEmpty() && !loading && !(searching && foundUsers.isNotEmpty())) {
                    item(key = "empty") { EmptyState(searching, Modifier.animateItem()) }
                }
            }
        }
    }

    menuChat?.let { chat ->
        ModalBottomSheet(onDismissRequest = { menuChat = null }) {
            Text(
                repo.chatTitle(chat),
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            fun act(block: suspend () -> Unit) {
                menuChat = null
                scope.launch { runCatching { block() } }
            }
            ListItem(
                headlineContent = { Text(if (chat.pinned) "Открепить" else "Закрепить") },
                leadingContent = { Icon(Icons.Default.PushPin, null) },
                modifier = Modifier.combinedClickable(onClick = { act { repo.setPinned(chat.id, !chat.pinned) } }),
            )
            ListItem(
                headlineContent = { Text(if (chat.muted) "Включить уведомления" else "Без звука") },
                leadingContent = { Icon(if (chat.muted) Icons.Default.Notifications else Icons.Default.NotificationsOff, null) },
                modifier = Modifier.combinedClickable(onClick = { act { repo.setMuted(chat.id, !chat.muted) } }),
            )
            if (chat.type != "saved") {
                ListItem(
                    headlineContent = { Text(if (chat.archived) "Вернуть из архива" else "В архив") },
                    leadingContent = { Icon(if (chat.archived) Icons.Default.Unarchive else Icons.Default.Archive, null) },
                    modifier = Modifier.combinedClickable(onClick = { act { repo.setArchived(chat.id, !chat.archived) } }),
                )
            }
            if (chat.type == "group") {
                ListItem(
                    headlineContent = { Text("Покинуть группу", color = MaterialTheme.colorScheme.error) },
                    leadingContent = { Icon(Icons.AutoMirrored.Filled.ExitToApp, null, tint = MaterialTheme.colorScheme.error) },
                    modifier = Modifier.combinedClickable(onClick = { act { repo.removeMember(chat.id, me!!.id) } }),
                )
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun ChatRow(
    chat: Chat,
    title: String,
    peer: User?,
    preview: String,
    typingNames: List<String>,
    myId: String?,
    compact: Boolean,
    avatarUrl: String?,
    modifier: Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val avatarSize = if (compact) 44.dp else 56.dp
    Row(
        modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = if (compact) 6.dp else 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(title, avatarUrl, avatarSize, online = peer?.online == true, saved = chat.type == "saved")
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                    Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (peer != null) BadgeIcons(peer.badges, peer.isAdmin, 16.dp)
                    if (chat.muted) Icon(Icons.Default.NotificationsOff, null, Modifier.padding(start = 4.dp).size(14.dp), tint = scheme.outline)
                }
                val last = chat.lastMessage
                if (last != null && last.senderId == myId && chat.type != "saved") {
                    Icon(Icons.Default.DoneAll, null, Modifier.size(16.dp), tint = scheme.primary)
                    Spacer(Modifier.width(4.dp))
                }
                Text(
                    formatListTime(chat.lastMessage?.createdAt ?: chat.createdAt),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (chat.unread > 0) scheme.primary else scheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) {
                    AnimatedContent(typingNames.isNotEmpty(), label = "typing", transitionSpec = { fadeIn() togetherWith fadeOut() }) { isTyping ->
                        if (isTyping) Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                if (chat.type == "group") "${typingNames.first()} печатает" else "печатает",
                                style = MaterialTheme.typography.bodyMedium,
                                color = scheme.primary,
                            )
                            Spacer(Modifier.width(4.dp))
                            TypingDots(scheme.primary, 4.dp)
                        } else Row(verticalAlignment = Alignment.CenterVertically) {
                            if (chat.type != "saved" && chat.lastMessage != null) {
                                Icon(Icons.Default.Lock, null, Modifier.size(12.dp), tint = scheme.outline)
                                Spacer(Modifier.width(4.dp))
                            }
                            Text(
                                preview.ifEmpty { if (chat.type == "saved") "Сохраняйте сюда важное" else "Нет сообщений" },
                                style = MaterialTheme.typography.bodyMedium,
                                color = scheme.onSurfaceVariant,
                                maxLines = if (compact) 1 else 2,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
                if (chat.pinned && chat.unread == 0) {
                    Icon(Icons.Default.PushPin, null, Modifier.size(16.dp), tint = scheme.outline)
                }
                UnreadBadge(chat.unread, chat.muted)
            }
        }
    }
}

@Composable
private fun UnreadBadge(count: Int, muted: Boolean) {
    val scale by animateFloatAsState(if (count > 0) 1f else 0f, spring(Spring.DampingRatioMediumBouncy), label = "unread")
    if (scale <= 0.01f) return
    val scheme = MaterialTheme.colorScheme
    Box(
        Modifier
            .padding(start = 6.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .defaultMinSize(minWidth = 22.dp, minHeight = 22.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(if (muted) scheme.outline else scheme.primary)
            .padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(count, label = "count") { c ->
            Text(if (c > 999) "999+" else c.coerceAtLeast(1).toString(), style = MaterialTheme.typography.labelSmall, color = scheme.onPrimary)
        }
    }
}

@Composable
private fun EmptyState(searching: Boolean, modifier: Modifier) {
    Column(modifier.fillMaxWidth().padding(48.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(if (searching) "🔍" else "💬", style = MaterialTheme.typography.displayMedium)
        Spacer(Modifier.height(12.dp))
        Text(
            if (searching) "Ничего не нашлось" else "Здесь пока пусто. Нажмите «Новый чат», чтобы найти друзей.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
