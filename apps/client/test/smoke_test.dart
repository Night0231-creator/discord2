import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veylor/main.dart';

void main() {
  testWidgets('shows sign-in screen after loading saved session', (tester) async {
    await tester.pumpWidget(const VeylorApp());
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao Veylor'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
