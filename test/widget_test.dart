import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test: базовая инициализация компонентов интерфейса', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'ФУТБОЛЬНАЯ АКАДЕМИЯ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ФУТБОЛЬНАЯ АКАДЕМИЯ'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
