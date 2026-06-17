import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tide_app/main.dart';

void main() {
  testWidgets('Tide App onboarding screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TideApp());

    // Verify that the onboarding screen renders successfully.
    expect(find.text('Bring Balance\nto Your Day'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap the 'Get Started' button and trigger a frame.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the Login Screen.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });
}
