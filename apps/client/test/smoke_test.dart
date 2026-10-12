import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veylor/main.dart';

void main() {
  testWidgets('Veylor app starts with a scaffold', (tester) async {
    await tester.pumpWidget(const VeylorApp());
    // The secure storage plugin is platform-native and may not complete in a widget test.
    // Verify the boot shell without waiting for the indeterminate loading animation.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
