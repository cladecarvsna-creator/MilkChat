import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../data/chat_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _username, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<ChatRepository>();
    if (!repo.isDemo && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await repo.signUp(
          email: _email.text.trim(),
          password: _password.text,
          username: _username.text.trim(),
          displayName: _name.text.trim(),
        );
      } else {
        await repo.signIn(email: _email.text.trim(), password: _password.text);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Не получилось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final demo = context.read<ChatRepository>().isDemo;
    return Scaffold(
      body: ChatBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: MilkLogo(size: 88)),
                      const SizedBox(height: 16),
                      Text(
                        'MilkChat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800, color: p.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _register ? 'Создайте аккаунт' : 'Войдите, чтобы общаться',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.muted, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      if (_register) ...[
                        _field(_name, 'Имя', Icons.person_outline,
                            validator: (v) => v!.trim().isEmpty ? 'Введите имя' : null),
                        _field(_username, 'Юзернейм', Icons.alternate_email,
                            validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(v!.trim())
                                ? null
                                : 'Латиница, цифры и _, от 3 символов'),
                      ],
                      _field(_email, 'Почта', Icons.mail_outline,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) => v!.contains('@') ? null : 'Введите почту'),
                      _field(_password, 'Пароль', Icons.lock_outline,
                          obscure: true,
                          validator: (v) => v!.length >= 6 ? null : 'Минимум 6 символов'),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFFF7A7A))),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(demo
                                ? 'Войти в демо'
                                : (_register ? 'Зарегистрироваться' : 'Войти')),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: Text(
                          _register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Регистрация',
                          style: TextStyle(color: p.title),
                        ),
                      ),
                      if (demo)
                        Text(
                          'Демо-режим: сервер не подключён, данные хранятся только '
                          'в этом окне. Можно оставить поля пустыми.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboard,
          validator: validator,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: context.palette.muted),
          ),
        ),
      );
}
