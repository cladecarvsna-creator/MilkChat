# MilkChat 🥛

Мессенджер и соцсеть для **Android, веба и десктопа** (Windows, macOS, Linux) на одной кодовой базе Flutter.
Сервер — [Supabase](https://supabase.com): вход по почте, сообщения в реальном времени, хранилище аватарок.

| Чаты | Переписка | Оформление | Выделение |
|---|---|---|---|
| ![](docs/screenshots/chats.png) | ![](docs/screenshots/chat.png) | ![](docs/screenshots/themes.png) | ![](docs/screenshots/select.png) |

![Десктоп](docs/screenshots/desktop.png)

## Что уже есть

- Вход и регистрация (почта + пароль, юзернейм).
- Чаты: личные, группы, каналы и «Избранное». Поиск по чатам и по людям.
- Переписка с узорным фоном, разделителями дат, галочками «доставлено/прочитано».
- Долгое нажатие на чат → выделение: закрепить, прочитать, без звука, в архив, удалить.
- Профиль группы/собеседника, создание групп и каналов, контакты.
- Мой профиль: аватарка, имя, юзернейм, «о себе».
- Настройки и лист «Оформление»: светлая/тёмная тема, 8 цветов, плавающие фигуры и узор на фоне.
- На широком экране (десктоп, веб) список чатов и переписка показываются рядом.

## Запуск

Нужен [Flutter](https://docs.flutter.dev/get-started/install) (stable).

```bash
flutter pub get
flutter run -d chrome     # веб
flutter run -d windows    # или macos / linux
flutter run               # подключённый Android
```

Без ключей Supabase приложение стартует в **демо-режиме**: данные живут в памяти, собеседники отвечают сами.

## Подключение сервера

1. Создайте проект на [supabase.com](https://supabase.com).
2. Откройте **SQL Editor**, вставьте содержимое [`supabase/schema.sql`](supabase/schema.sql) и выполните.
3. Возьмите **Project URL** и **Publishable key** (Project Settings → API Keys) и запускайте так:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
            --dart-define=SUPABASE_KEY=sb_publishable_xxxx
```

Чтобы готовые сборки из GitHub Actions тоже подключались к серверу, добавьте те же значения
в **Settings → Secrets and variables → Actions** как `SUPABASE_URL` и `SUPABASE_KEY`.

## Сборки

Workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) на каждый push проверяет код,
прогоняет тесты и собирает веб, APK, Windows, Linux и macOS — файлы лежат во вкладке **Actions → Artifacts**.

Вручную:

```bash
flutter build web          # build/web
flutter build apk          # build/app/outputs/flutter-apk/app-release.apk
flutter build windows      # build/windows/x64/runner/Release
```

## Структура

```
lib/
  data/        источник данных: Supabase и демо
  models/      пользователь, чат, сообщение
  screens/     экраны: вход, чаты, переписка, контакты, профиль, настройки, темы
  theme/       палитра из акцентного цвета, светлая и тёмная темы
  widgets/     аватарки, плитки, фон с узором, логотип
supabase/      схема базы, права доступа, функции
tool/          генерация иконок (python3 tool/make_icons.py)
```

Шрифт Nunito — SIL Open Font License (`assets/fonts/OFL.txt`).
