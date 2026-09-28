import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybaby/core/theme/app_theme.dart';
import 'package:mybaby/data/models/task.dart';
import 'package:mybaby/shared/widgets/task_row.dart';

void main() {
  Widget wrap(Widget child) {
    return AppThemeScope(
      theme: AppTheme.light(),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  testWidgets('tapping the checkbox invokes onToggle', (tester) async {
    var toggled = false;
    final task = Task(
      id: '1',
      title: 'Buy diapers',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      wrap(
        TaskRow(
          task: task,
          onToggle: () => toggled = true,
          onTap: () {},
          onOpenActions: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.circle));
    expect(toggled, isTrue);
  });

  testWidgets('a completed task renders its title with strikethrough', (
    tester,
  ) async {
    final task = Task(
      id: '1',
      title: 'Buy diapers',
      completedAt: DateTime(2026, 1, 2),
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      wrap(TaskRow(task: task, onToggle: () {}, onTap: () {}, onOpenActions: () {})),
    );

    final text = tester.widget<Text>(find.text('Buy diapers'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });
}
