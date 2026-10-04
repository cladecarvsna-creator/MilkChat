import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milkchat/app.dart';
import 'package:milkchat/data/chat_repository.dart';
import 'package:milkchat/theme/app_theme.dart';
import 'package:milkchat/utils/format.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_repository.dart';

Future<void> pumpApp(WidgetTester tester, FakeRepository repo) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
      ChangeNotifierProvider<ChatRepository>.value(value: repo),
    ],
    child: const MilkChatApp(),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'me@milk.chat');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
  await tester.tap(find.text('Войти'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the official MilkChat channel, read-only for members', (tester) async {
    await pumpApp(tester, FakeRepository());
    expect(find.text('MilkChat'), findsOneWidget);
    await tester.tap(find.text('MilkChat'));
    await tester.pumpAndSettle();
    expect(find.text('Писать в этот канал могут только администраторы'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('own group: message is sent and nobody auto-replies', (tester) async {
    final repo = FakeRepository();
    await pumpApp(tester, repo);
    await repo.createGroup(title: 'Моя группа', memberIds: const []);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Моя группа'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Привет, молоко');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Привет, молоко'), findsOneWidget);
    expect(find.textContaining('Согласен'), findsNothing);
  });

  testWidgets('long press enters selection mode', (tester) async {
    await pumpApp(tester, FakeRepository());
    await tester.longPress(find.text('MilkChat'));
    await tester.pumpAndSettle();
    expect(find.text('1 выбрано'), findsOneWidget);
    await tester.tap(find.text('Закрепить'));
    await tester.pumpAndSettle();
    expect(find.text('1 выбрано'), findsNothing);
  });

  test('russian plurals', () {
    expect(plural(1, 'участник', 'участника', 'участников'), '1 участник');
    expect(plural(3, 'участник', 'участника', 'участников'), '3 участника');
    expect(plural(11, 'участник', 'участника', 'участников'), '11 участников');
  });
}
