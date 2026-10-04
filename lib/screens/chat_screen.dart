import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'chat_info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.embedded = false, this.onClose});

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
    _input.clear();
    _focus.requestFocus();
    try {
      await _repo.sendMessage(widget.chatId, text);
    } catch (e) {
      if (!mounted) return;
      _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не отправлено: $e')),
      );
    }
  }

  void _maybeMarkRead(List<Message> msgs) {
    if (msgs.isEmpty) return;
    final last = msgs.last;
    if (last.id == _lastSeenId) return;
    _lastSeenId = last.id;
    if (last.senderId != _repo.me?.id) _repo.markRead([widget.chatId]);
  }

  void _openInfo() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatInfoScreen(chatId: widget.chatId),
      ));

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Scaffold(
      body: ChatBackground(
        icons: theme.patternIcons,
        shapes: theme.floatingShapes,
        child: Column(
          children: [
            StreamBuilder<List<ChatSummary>>(
              stream: _chats,
              builder: (context, snap) {
                final chat = snap.data?.where((c) => c.id == widget.chatId).firstOrNull;
                return _Header(
                  chat: chat,
                  embedded: widget.embedded,
                  onBack: widget.embedded ? widget.onClose : () => Navigator.of(context).pop(),
                  onInfo: _openInfo,
                  onToggleMute: chat == null
                      ? null
                      : () => _repo.setMuted([chat.id], !chat.muted),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _messages,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Ошибка: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final msgs = snap.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _maybeMarkRead(msgs));
                  if (msgs.isEmpty) {
                    return Center(
                      child: _Pill(text: 'Здесь пока пусто. Напишите первое сообщение!'),
                    );
                  }
                  return _MessageList(messages: msgs, myId: _repo.me!.id);
                },
              ),
            ),
            _Composer(
              controller: _input,
              focus: _focus,
              onSend: _send,
            ),
          ],
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
            ChatKind.group => plural(c.memberCount, 'участник', 'участника', 'участников'),
            ChatKind.channel => plural(c.memberCount, 'подписчик', 'подписчика', 'подписчиков'),
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
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (c?.verified ?? false) ...[
                                  const SizedBox(width: 6),
                                  const VerifiedBadge(),
                                ],
                              ],
                            ),
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.muted, fontSize: 14)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (v) {
                  if (v == 'info') onInfo();
                  if (v == 'mute') onToggleMute?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'info', child: Text('Информация')),
                  PopupMenuItem(
                    value: 'mute',
                    child: Text((c?.muted ?? false) ? 'Включить звук' : 'Без звука'),
                  ),
                ],
                child: IgnorePointer(
                  child: RoundButton(icon: Icons.more_vert_rounded, onPressed: () {}),
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
  const _MessageList({required this.messages, required this.myId});

  final List<Message> messages;
  final String myId;

  @override
  Widget build(BuildContext context) {
    // Список перевёрнут, чтобы новые сообщения были снизу и прокрутка шла от них.
    final items = <Widget>[];
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;
      final mine = m.senderId == myId;
      final groupedWithNext = next != null &&
          next.senderId == m.senderId &&
          sameDay(next.createdAt, m.createdAt);
      items.add(_Bubble(
        message: m,
        mine: mine,
        showAvatar: !mine && !groupedWithNext,
        tail: !groupedWithNext,
      ));
      if (prev == null || !sameDay(prev.createdAt, m.createdAt)) {
        items.add(Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _Pill(text: dayLabel(m.createdAt)),
          ),
        ));
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
      child: Text(text, style: TextStyle(color: p.text.withValues(alpha: 0.8), fontSize: 14)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showAvatar,
    required this.tail,
  });

  final Message message;
  final bool mine;
  final bool showAvatar;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = mine ? p.bubbleOut : p.bubbleIn;
    final fg = mine ? p.onBubbleOut : p.onBubbleIn;
    final isCommand = message.text.startsWith('/') && !message.text.contains(' ');
    const r = Radius.circular(22);
    const small = Radius.circular(8);

    final bubble = GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст скопирован'), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
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
        child: Wrap(
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
                  Text(hhmm(message.createdAt),
                      style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(message.read ? Icons.done_all_rounded : Icons.check_rounded,
                        size: 15, color: fg.withValues(alpha: 0.75)),
                  ],
                ],
              ),
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

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.onSend});

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasText = controller.text.trim().isNotEmpty;
    void soon() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вложения и голосовые появятся в следующей версии')),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RoundButton(icon: Icons.add_rounded, tooltip: 'Вложение', onPressed: soon),
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RoundButton(icon: Icons.emoji_emotions_outlined, tooltip: 'Стикеры', onPressed: soon),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
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
        ),
      ),
    );
  }
}
