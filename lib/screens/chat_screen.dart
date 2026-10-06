import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../data/firebase_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'chat_info_screen.dart';
import 'home_shell.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.embedded = false,
    this.onClose,
  });

  final String chatId;

  /// Встроен справа от списка (широкий экран).
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _repo;
  late final Stream<List<Message>> _messages;
  late final Stream<List<ChatSummary>> _chats;
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _lastSeenId;

  /// Сообщение, на которое отвечаем (полоска над полем ввода).
  Message? _replyTo;

  /// Детали чата, если его нет в моём списке (публичный канал без подписки).
  Future<ChatDetails>? _preview;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ChatRepository>();
    _messages = _repo.watchMessages(widget.chatId);
    _chats = _repo.watchChats();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final reply = _replyTo;
    _input.clear();
    setState(() => _replyTo = null);
    _focus.requestFocus();
    try {
      await _repo.sendMessage(
        widget.chatId,
        text,
        replyTo: reply == null ? null : MessageRef.of(reply),
      );
    } catch (e) {
      if (!mounted) return;
      _input.text = text;
      setState(() => _replyTo = reply);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не отправлено: $e')));
    }
  }

  void _reply(Message m) {
    setState(() => _replyTo = m);
    _focus.requestFocus();
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await _repo.joinChannel(widget.chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось подписаться: $e')));
    }
    if (mounted) setState(() => _joining = false);
  }

  void _maybeMarkRead(List<Message> msgs, {required bool member}) {
    if (msgs.isEmpty || !member) return;
    final last = msgs.last;
    if (last.id == _lastSeenId) return;
    _lastSeenId = last.id;
    if (last.senderId != _repo.me?.id) _repo.markRead([widget.chatId]);
  }

  void _openInfo() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ChatInfoScreen(chatId: widget.chatId)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Scaffold(
      body: ChatBackground(
        icons: theme.patternIcons,
        shapes: theme.floatingShapes,
        child: StreamBuilder<List<ChatSummary>>(
          stream: _chats,
          builder: (context, chatSnap) {
            final mine = chatSnap.data
                ?.where((c) => c.id == widget.chatId)
                .firstOrNull;
            // Чата нет в моём списке — это публичный канал, открытый из поиска.
            if (chatSnap.hasData && mine == null) {
              _preview ??= _repo.chatDetails(widget.chatId);
            }
            return FutureBuilder<ChatDetails>(
              future: mine == null ? _preview : null,
              builder: (context, previewSnap) {
                final preview = mine == null ? previewSnap.data : null;
                final chat = mine ?? preview?.chat;
                final member = mine != null;
                return Column(
                  children: [
                    _Header(
                      chat: chat,
                      embedded: widget.embedded,
                      onBack: widget.embedded
                          ? widget.onClose
                          : () => Navigator.of(context).pop(),
                      onInfo: _openInfo,
                      onToggleMute: chat == null
                          ? null
                          : () => _repo.setMuted([chat.id], !chat.muted),
                    ),
                    Expanded(
                      child: StreamBuilder<List<Message>>(
                        stream: _messages,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(child: Text('Ошибка: ${snap.error}'));
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final msgs = snap.data!;
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _maybeMarkRead(msgs, member: member),
                          );
                          if (msgs.isEmpty) {
                            return Center(
                              child: _Pill(
                                text: 'Здесь пока пусто. Напишите первое сообщение!',
                              ),
                            );
                          }
                          return _MessageList(
                            messages: msgs,
                            myId: _repo.me!.id,
                            chat: chat,
                            onReply: chat != null && chat.canPost && member
                                ? _reply
                                : null,
                          );
                        },
                      ),
                    ),
                    if (preview != null && !preview.isMember)
                      _JoinBar(busy: _joining, onJoin: _join)
                    else if (_repo.me?.banned ?? false)
                      const _ReadOnlyBar(
                        text: 'Ваш аккаунт заблокирован модератором',
                      )
                    else if (chat == null || chat.canPost)
                      _Composer(
                        controller: _input,
                        focus: _focus,
                        onSend: _send,
                        replyTo: _replyTo,
                        onCancelReply: () => setState(() => _replyTo = null),
                      )
                    else
                      const _ReadOnlyBar(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Публичный канал без подписки: вместо поля ввода — кнопка «Подписаться».
class _JoinBar extends StatelessWidget {
  const _JoinBar({required this.busy, required this.onJoin});
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FilledButton.icon(
            onPressed: busy ? null : onJoin,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Подписаться'),
          ),
        ),
      ),
    );
  }
}

/// Вместо поля ввода в канале, где писать могут только администраторы.
class _ReadOnlyBar extends StatelessWidget {
  const _ReadOnlyBar({
    this.text = 'Писать в этот канал могут только администраторы',
  });
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.chat,
    required this.embedded,
    required this.onBack,
    required this.onInfo,
    required this.onToggleMute,
  });

  final ChatSummary? chat;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback onInfo;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = chat;
    final subtitle = c == null
        ? ''
        : switch (c.kind) {
            ChatKind.group => plural(
              c.memberCount,
              'участник',
              'участника',
              'участников',
            ),
            ChatKind.channel => plural(
              c.memberCount,
              'подписчик',
              'подписчика',
              'подписчиков',
            ),
            ChatKind.saved => 'Заметки для себя',
            ChatKind.direct => c.handle ?? '',
          };
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              RoundButton(
                icon: embedded ? Icons.close_rounded : Icons.arrow_back_rounded,
                tooltip: embedded ? 'Закрыть' : 'Назад',
                onPressed: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: c == null ? null : onInfo,
                  child: Row(
                    children: [
                      if (c != null) Avatar.chat(c, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c?.title ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.text,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (c?.verified ?? false) ...[
                                  const SizedBox(width: 6),
                                  const VerifiedBadge(),
                                ],
                              ],
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ещё',
                color: p.surfaceHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (v) {
                  if (v == 'info') onInfo();
                  if (v == 'mute') onToggleMute?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'info', child: Text('Информация')),
                  PopupMenuItem(
                    value: 'mute',
                    child: Text(
                      (c?.muted ?? false) ? 'Включить звук' : 'Без звука',
                    ),
                  ),
                ],
                child: IgnorePointer(
                  child: RoundButton(
                    icon: Icons.more_vert_rounded,
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.myId,
    required this.chat,
    required this.onReply,
  });

  final List<Message> messages;
  final String myId;
  final ChatSummary? chat;

  /// null — отвечать здесь нельзя (канал без прав, превью без подписки).
  final ValueChanged<Message>? onReply;

  @override
  Widget build(BuildContext context) {
    // Список перевёрнут, чтобы новые сообщения были снизу и прокрутка шла от них.
    final items = <Widget>[];
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;
      final mine = m.senderId == myId;
      final groupedWithNext =
          next != null &&
          next.senderId == m.senderId &&
          sameDay(next.createdAt, m.createdAt);
      items.add(
        _Bubble(
          message: m,
          mine: mine,
          showAvatar: !mine && !groupedWithNext,
          tail: !groupedWithNext,
          canDelete: mine || (chat?.isAdmin ?? false),
          onReply: onReply,
        ),
      );
      if (prev == null || !sameDay(prev.createdAt, m.createdAt)) {
        items.add(
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _Pill(text: dayLabel(m.createdAt)),
            ),
          ),
        );
      }
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          children: items,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: p.text.withValues(alpha: 0.8), fontSize: 14),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showAvatar,
    required this.tail,
    required this.canDelete,
    required this.onReply,
  });

  final Message message;
  final bool mine;
  final bool showAvatar;
  final bool tail;
  final bool canDelete;
  final ValueChanged<Message>? onReply;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = mine ? p.bubbleOut : p.bubbleIn;
    final fg = mine ? p.onBubbleOut : p.onBubbleIn;
    final isCommand =
        message.text.startsWith('/') && !message.text.contains(' ');
    const r = Radius.circular(22);
    const small = Radius.circular(8);

    final bubble = GestureDetector(
      onLongPress: () => _showActions(context),
      onSecondaryTap: () => _showActions(context),
      onDoubleTap: onReply == null ? null : () => onReply!(message),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: !mine && tail ? small : r,
            bottomRight: mine && tail ? small : r,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.forwardedFrom != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shortcut_rounded,
                      size: 15,
                      color: fg.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Переслано от ${message.forwardedFrom}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (message.replyTo case final r?)
              _Quote(
                name: r.senderName,
                text: r.text,
                color: mine ? fg : p.title,
                textColor: fg,
              ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isCommand ? (mine ? fg : p.title) : fg,
                    fontSize: 17,
                    height: 1.25,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.edited)
                        Text(
                          'изм. ',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        hhmm(message.createdAt),
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.read
                              ? Icons.done_all_rounded
                              : Icons.check_rounded,
                          size: 15,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (mine) {
      return Padding(
        padding: EdgeInsets.only(bottom: tail ? 8 : 3, left: 48),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: tail ? 8 : 3, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 40,
            child: showAvatar
                ? Avatar(name: message.senderName ?? '?', size: 34)
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bubble],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _Bubble {
  /// Ответить, переслать, копировать — всем; изменить — автору; удалить у всех —
  /// автору или админу (окончательно права проверяют правила Firestore).
  Future<void> _showActions(BuildContext context) async {
    final repo = context.read<ChatRepository>();
    final fb = repo is FirebaseRepository ? repo : null;
    final staff = fb?.isStaff ?? false;
    const danger = Color(0xFFFF6B6B);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Ответить'),
                onTap: () => Navigator.pop(ctx, 'reply'),
              ),
            ListTile(
              leading: const Icon(Icons.shortcut_rounded),
              title: const Text('Переслать'),
              onTap: () => Navigator.pop(ctx, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Копировать'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            if (fb != null && mine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Изменить'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (canDelete || staff)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: danger,
                ),
                title: const Text('Удалить', style: TextStyle(color: danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            if (fb != null && !mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Пожаловаться'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'reply':
          onReply?.call(message);
        case 'forward':
          await _forward(context, repo);
        case 'copy':
          await Clipboard.setData(ClipboardData(text: message.text));
          messenger.showSnackBar(
            const SnackBar(content: Text('Текст скопирован')),
          );
        case 'edit':
          final c = TextEditingController(text: message.text);
          final text = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Изменить сообщение'),
              content: TextField(
                controller: c,
                autofocus: true,
                maxLines: 5,
                minLines: 1,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, c.text.trim()),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
          if (text != null && text.isNotEmpty && text != message.text) {
            await fb!.editMessage(message.chatId, message.id, text);
          }
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Удалить сообщение?'),
              content: const Text('Сообщение пропадёт у всех участников чата.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Удалить', style: TextStyle(color: danger)),
                ),
              ],
            ),
          );
          if (ok == true) {
            await repo.deleteMessage(message.chatId, message.id);
            messenger.showSnackBar(
              const SnackBar(content: Text('Сообщение удалено')),
            );
          }
        case 'report':
          await fb!.report(message);
          messenger.showSnackBar(
            const SnackBar(content: Text('Жалоба отправлена модераторам')),
          );
      }
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Выбор чата и отправка копии с пометкой «Переслано от …».
  Future<void> _forward(BuildContext context, ChatRepository repo) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = await showModalBottomSheet<ChatSummary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const _ForwardSheet(),
    );
    if (target == null) return;
    await repo.sendMessage(
      target.id,
      message.text,
      forwardedFrom: message.forwardedFrom ?? message.senderName ?? '',
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Переслано: ${target.title}'),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () {
              if (context.mounted) HomeShell.openChat(context, target.id);
            },
          ),
        ),
      );
  }
}

/// Цитата в пузыре и над полем ввода.
class _Quote extends StatelessWidget {
  const _Quote({
    required this.name,
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String name;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name.isEmpty ? 'Сообщение' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Лист «Переслать в…»: чаты, куда мне можно писать.
class _ForwardSheet extends StatefulWidget {
  const _ForwardSheet();

  @override
  State<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<_ForwardSheet> {
  late final Stream<List<ChatSummary>> _chats = context
      .read<ChatRepository>()
      .watchChats();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => StreamBuilder<List<ChatSummary>>(
        stream: _chats,
        builder: (context, snap) {
          final q = _search.text.trim().toLowerCase();
          final chats =
              (snap.data ?? const <ChatSummary>[])
                  .where(
                    (c) =>
                        c.canPost &&
                        (q.isEmpty || c.title.toLowerCase().contains(q)),
                  )
                  .toList()
                ..sort((a, b) {
                  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                  return (b.lastAt ?? DateTime(0)).compareTo(
                    a.lastAt ?? DateTime(0),
                  );
                });
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Переслать в…',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 12),
              SearchPill(
                hint: 'Поиск чата',
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (!snap.hasData)
                const Center(child: CircularProgressIndicator()),
              for (var i = 0; i < chats.length; i++)
                TileCard(
                  first: i == 0,
                  last: i == chats.length - 1,
                  onTap: () => Navigator.pop(context, chats[i]),
                  child: Row(
                    children: [
                      Avatar.chat(chats[i], size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          chats[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final Message? replyTo;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasText = controller.text.trim().isNotEmpty;
    void soon() => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Вложения и голосовые появятся в следующей версии'),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTo case final r?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, color: p.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Quote(
                          name: 'Ответ ${r.senderName ?? ''}'.trim(),
                          text: r.text,
                          color: p.accent,
                          textColor: p.text,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Не отвечать',
                        icon: Icon(Icons.close_rounded, color: p.muted),
                        onPressed: onCancelReply,
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RoundButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Вложение',
                    onPressed: soon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter): onSend,
                      },
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(color: p.text, fontSize: 17),
                        decoration: InputDecoration(
                          hintText: 'Сообщение',
                          hintStyle: TextStyle(color: p.muted, fontSize: 17),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RoundButton(
                    icon: Icons.emoji_emotions_outlined,
                    tooltip: 'Стикеры',
                    onPressed: soon,
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: hasText
                        ? RoundButton(
                            key: const ValueKey('send'),
                            icon: Icons.send_rounded,
                            tooltip: 'Отправить',
                            filled: true,
                            onPressed: onSend,
                          )
                        : RoundButton(
                            key: const ValueKey('mic'),
                            icon: Icons.mic_none_rounded,
                            tooltip: 'Голосовое',
                            onPressed: soon,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
