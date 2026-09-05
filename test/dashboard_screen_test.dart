// The Dashboard header: the title, the period control, and when the Pulse
// shows.
//
// Every card below the header is switched off here. They each read their own
// provider off the database, and none of them is what these assertions are
// about. See docs/features/10b-device-pass.md, K1 to K3.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/models/dashboard_models.dart';
import 'package:milano_orders/providers/business_info_provider.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/providers/dashboard_provider.dart';
import 'package:milano_orders/providers/dashboard_settings_provider.dart';
import 'package:milano_orders/screens/dashboard/dashboard_screen.dart';
import 'package:milano_orders/widgets/dashboard/pulse_card.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';

void main() {
  // The Pulse reads the database for today's figures. It is not what these
  // assertions are about, but left on the real provider it opens a second
  // AppDatabase per test and drift says so, loudly.
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Only the Pulse. The other cards would each want the database.
  const onlyPulse = DashboardSettings(
    showOutstanding: false,
    showCategoryCards: false,
    showRevenueAnatomy: false,
    showOperationalPatterns: false,
    showAttentionFlags: false,
  );

  Widget buildDashboard({
    String? businessName,
    DashboardPreset preset = DashboardPreset.today,
    DashboardSettings settings = onlyPulse,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dashboardSettingsProvider.overrideWith(
          (ref) => _FixedSettings(settings),
        ),
        dashboardRangeProvider.overrideWith((ref) => _FixedRange(preset)),
        businessInfoProvider.overrideWith(
          (ref) => Stream.value(
            businessName == null
                ? null
                : BusinessInfoData(
                    id: 1,
                    name: businessName,
                    phone: null,
                    address: null,
                    logoPath: null,
                  ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(BrandConfig.milano),
        home: const DashboardScreen(),
      ),
    );
  }

  group('the header', () {
    testWidgets('carries the business name once one is set', (tester) async {
      await tester.pumpWidget(buildDashboard(businessName: 'Cafe Milano'));
      await tester.pump();

      expect(find.text('Cafe Milano'), findsOneWidget);
      expect(find.text('Business Overview'), findsNothing);
    });

    testWidgets('falls back rather than showing a blank title',
        (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump();

      expect(find.text('Business Overview'), findsOneWidget);
    });

    testWidgets('a name of only spaces is not a name', (tester) async {
      await tester.pumpWidget(buildDashboard(businessName: '   '));
      await tester.pump();

      expect(find.text('Business Overview'), findsOneWidget);
    });

    testWidgets('the period is a dropdown, not a row of pills',
        (tester) async {
      await tester.pumpWidget(buildDashboard(preset: DashboardPreset.lastWeek));
      await tester.pump();

      expect(find.text('Last week'), findsOneWidget);

      await tester.tap(find.text('Last week'));
      await tester.pumpAndSettle();

      // Every preset is reachable from the one control.
      for (final label in const [
        'Today',
        'This week',
        'This month',
        'Last month',
        'Last 90 days',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing');
      }
    });
  });

  group('the Pulse', () {
    testWidgets('shows on the daily view', (tester) async {
      await tester.pumpWidget(buildDashboard(preset: DashboardPreset.today));
      await tester.pump();

      expect(find.byType(PulseCard), findsOneWidget);
    });

    testWidgets('is gone on any longer period', (tester) async {
      // It answers "how is today going". Against a quarter that is a different
      // question, and one the cards below already answer.
      for (final preset in const [
        DashboardPreset.thisWeek,
        DashboardPreset.thisMonth,
        DashboardPreset.last90,
      ]) {
        await tester.pumpWidget(buildDashboard(preset: preset));
        await tester.pump();
        expect(find.byType(PulseCard), findsNothing, reason: '$preset');
      }
    });

    testWidgets('stays off when the setting is off, even on daily',
        (tester) async {
      await tester.pumpWidget(buildDashboard(
        preset: DashboardPreset.today,
        settings: const DashboardSettings(
          showPulse: false,
          showOutstanding: false,
          showCategoryCards: false,
          showRevenueAnatomy: false,
          showOperationalPatterns: false,
          showAttentionFlags: false,
        ),
      ));
      await tester.pump();

      expect(find.byType(PulseCard), findsNothing);
    });
  });
}

class _FixedSettings extends DashboardSettingsNotifier {
  _FixedSettings(DashboardSettings value) {
    state = value;
  }
}

class _FixedRange extends DashboardRangeNotifier {
  _FixedRange(DashboardPreset preset) {
    state = DashboardRange.fromPreset(preset);
  }
}
