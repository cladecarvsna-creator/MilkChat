import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milkchat/app.dart';
import 'package:milkchat/data/chat_repository.dart';
import 'package:milkchat/data/demo_repository.dart';
import 'package:milkchat/theme/app_theme.dart';
import 'package:milkchat/utils/format.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, DemoRepository repo) async {
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
  await tester.tap(find.text('Войти в демо'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo: chat list, open chat, send message', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = DemoRepository();
    await pumpApp(tester, repo);

    expect(find.text('Группа Коров'), findsOneWidget);
    expect(find.text('Найти в MilkChat'), findsOneWidget);

    await tester.tap(find.text('Sherlock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Привет, молоко');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Привет, молоко'), findsOneWidget);

    // Дать демо-собеседнику «ответить», чтобы таймеры не висели после теста.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('long press enters selection mode', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, DemoRepository());
    await tester.longPress(find.text('Sherlock'));
    await tester.pumpAndSettle();
    expect(find.text('1 выбрано'), findsOneWidget);
    expect(find.text('Закрепить'), findsOneWidget);

    await tester.tap(find.text('Закрепить'));
    await tester.pumpAndSettle();
    expect(find.text('1 выбрано'), findsNothing);
  });

  test('russian plurals', () {
    expect(plural(1, 'участник', 'участника', 'участников'), '1 участник');
    expect(plural(3, 'участник', 'участника', 'участников'), '3 участника');
    expect(plural(11, 'участник', 'участника', 'участников'), '11 участников');
    expect(plural(22, 'участник', 'участника', 'участников'), '22 участника');
  });
}
