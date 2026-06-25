import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget smoke test', (WidgetTester tester) async {
    // Build a simple MaterialApp containing a text widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Chatrix AI'),
          ),
        ),
      ),
    );

    // Verify that our text is present
    expect(find.text('Chatrix AI'), findsOneWidget);
    expect(find.text('Not Present'), findsNothing);
  });
}
