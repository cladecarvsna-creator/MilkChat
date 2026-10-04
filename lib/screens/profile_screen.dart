import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Мой профиль: аватарка, имя, юзернейм, о себе.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final repo = context.read<ChatRepository>();
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.xFile.readAsBytes();
      await repo.updateProfile(avatarBytes: bytes, avatarExt: files.first.extension);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось загрузить: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final repo = context.watch<ChatRepository>();
    final me = repo.me!;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _pickAvatar(context),
                  child: Stack(
                    children: [
                      Avatar.profile(me, size: 140),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: p.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.background, width: 3),
                          ),
                          child: Icon(Icons.photo_camera_rounded, color: p.onAccent, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                me.displayName.isEmpty ? me.username : me.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: p.text),
              ),
              const SizedBox(height: 4),
              Text('@${me.username}',
                  textAlign: TextAlign.center, style: TextStyle(color: p.title, fontSize: 16)),
              const SizedBox(height: 24),
              _Field(
                icon: Icons.person_outline,
                title: 'Имя',
                value: me.displayName,
                first: true,
                onSave: (v) => repo.updateProfile(displayName: v),
              ),
              _Field(
                icon: Icons.alternate_email,
                title: 'Юзернейм',
                value: me.username,
                validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(v)
                    ? null
                    : 'Латиница, цифры и _, от 3 символов',
                onSave: (v) => repo.updateProfile(username: v),
              ),
              _Field(
                icon: Icons.info_outline,
                title: 'О себе',
                value: me.bio,
                last: true,
                multiline: true,
                onSave: (v) => repo.updateProfile(bio: v),
              ),
              TileCard(
                onTap: () => repo.signOut(),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 16),
                    Text('Выйти из аккаунта',
                        style: TextStyle(
                            color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.title,
    required this.value,
    required this.onSave,
    this.first = false,
    this.last = false,
    this.multiline = false,
    this.validator,
  });

  final IconData icon;
  final String title;
  final String value;
  final Future<void> Function(String) onSave;
  final bool first;
  final bool last;
  final bool multiline;
  final String? Function(String)? validator;

  Future<void> _edit(BuildContext context) async {
    final p = context.palette;
    final c = TextEditingController(text: value);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(errorText: error),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена', style: TextStyle(color: p.muted))),
            TextButton(
              onPressed: () {
                final err = validator?.call(c.text.trim());
                if (err != null) return setState(() => error = err);
                Navigator.pop(ctx, c.text.trim());
              },
              child: Text('Сохранить', style: TextStyle(color: p.title)),
            ),
          ],
        ),
      ),
    );
    if (result == null || result == value) return;
    try {
      await onSave(result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TileCard(
      first: first,
      last: last,
      onTap: () => _edit(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: p.text.withValues(alpha: 0.75)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Не указано' : value,
                    style: TextStyle(color: p.text, fontSize: 17)),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 20, color: p.muted),
        ],
      ),
    );
  }
}
