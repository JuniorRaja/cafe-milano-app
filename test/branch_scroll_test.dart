// Scroll position across a bottom-bar switch.
//
// `StatefulShellRoute.indexedStack` keeps every branch alive, scroll position
// and all. That is right for a back press out of a pushed screen and wrong for
// a tab switch — coming back to Orders half way down is not where the day
// starts. See docs/features/10b-device-pass.md, J3.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/widgets/shell/branch_scroll.dart';

void main() {
  /// The signal `StatefulShellRoute` actually gives a branch: it wraps each one
  /// in a `TickerMode`, enabled only for the branch on screen.
  Widget branch({required bool active}) => MaterialApp(
        home: TickerMode(
          enabled: active,
          child: BranchScrollScope(
            child: ListView(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 60, child: Text('Row $i')),
              ],
            ),
          ),
        ),
      );

  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('leaving a branch returns it to the top', (tester) async {
    await tester.pumpWidget(branch(active: true));

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0));

    // Switch away. The reset lands after this frame, while the branch is
    // offstage, so nothing is seen moving.
    await tester.pumpWidget(branch(active: false));
    await tester.pump();

    // Switch back.
    await tester.pumpWidget(branch(active: true));
    await tester.pump();

    expect(offset(tester), 0);
  });

  testWidgets('staying on a branch keeps its position', (tester) async {
    await tester.pumpWidget(branch(active: true));

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final scrolled = offset(tester);

    // A rebuild that is not a branch switch — a provider updating, a push and
    // pop inside the branch. The position is the user's, not the shell's.
    await tester.pumpWidget(branch(active: true));
    await tester.pump();

    expect(offset(tester), scrolled);
  });

  testWidgets('the list attaches to the scope, not to its own controller',
      (tester) async {
    // The reset only works because a bare `ListView` takes the nearest
    // `PrimaryScrollController`. A screen that passes its own controller opts
    // out, silently — this is the assertion that would catch that changing.
    await tester.pumpWidget(branch(active: true));

    final context = tester.element(find.byType(ListView));
    final primary = PrimaryScrollController.of(context);
    expect(primary.hasClients, isTrue);
  });
}
