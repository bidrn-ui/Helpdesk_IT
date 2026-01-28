import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_f_security/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProjectFApp());

    // Verify that the login page is shown
    expect(find.text('Helpdesk IT / Ticket Keluhan Kampus'), findsOneWidget);
    expect(find.text('Secure Vulnerability Management'), findsOneWidget);
  });
}
