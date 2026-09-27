import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mybaby/features/babies/baby_form.dart';

// A full-app smoke test now needs Firebase (FirebaseAuth.instance) available,
// which isn't wired up in the test binding — see docs/ARCHITECTURE.md. This
// tests the one piece of onboarding that's pure Flutter: the form itself.
void main() {
  testWidgets(
    'BabyForm requires both name and date of birth before enabling submit',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BabyForm(
              onSubmit: ({required name, required dob, sex, photo}) async {},
              submitting: false,
              submitLabel: 'Get started',
            ),
          ),
        ),
      );

      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get started'),
      );

      expect(submitButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Amaya');
      await tester.pump();

      // Name alone isn't enough — date of birth is still required.
      expect(submitButton().onPressed, isNull);
    },
  );
}
