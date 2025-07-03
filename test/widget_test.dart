import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_remind/main.dart';

void main() {
  testWidgets('VoiceRemind app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VoiceRemindApp());

    // Verify that our app has the correct title
    expect(find.text('VoiceRemind'), findsOneWidget);

    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
