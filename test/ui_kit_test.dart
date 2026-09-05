import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/utils/money.dart';
import 'package:milano_orders/widgets/ui/ui.dart';

/// Deliberately light. The kit is presentational and carries no money or
/// counts, so these assert only that each component builds under the real
/// theme and renders its text — enough to catch a null token or a bad
/// `TextTheme` key.
///
/// **No test asserts a colour value.** Tokens are meant to change — that is the
/// point of the brand seam — and a test that pins `#FFC000` makes the seam
/// useless.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAppTheme(BrandConfig.milano),
    home: Scaffold(body: child),
  );

  group('theme wiring', () {
    // Regression: a colourless TextStyle in a theme slot *displaces* the
    // Material default that would have carried a colour, and the engine's
    // fallback for an unset colour is white — invisible on every surface in
    // this app. It shipped three times (AppBar titles, dialog titles, every
    // ListTile on Profile) before the colour moved onto the AppType steps.
    //
    // Asserts only "not invisible", never a specific value, so the brand seam
    // stays swappable.
    testWidgets('no themed text resolves to a null or invisible colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(BrandConfig.milano),
          home: DefaultTabController(
            length: 1,
            child: Scaffold(
              appBar: AppBar(title: const Text('AppBar title')),
              body: const Column(
                children: [
                  Text('Bare heading'),
                  ListTile(
                    title: Text('Tile title'),
                    subtitle: Text('Tile subtitle'),
                  ),
                  Chip(label: Text('Chip label')),
                  TabBar(tabs: [Tab(text: 'Tab label')]),
                ],
              ),
            ),
          ),
        ),
      );

      const ground = <Color>[Color(0xFFFFFFFF), AppColors.bg];
      for (final label in [
        'AppBar title',
        'Bare heading',
        'Tile title',
        'Tile subtitle',
        'Chip label',
        'Tab label',
      ]) {
        final ctx = tester.element(find.text(label));
        final style = DefaultTextStyle.of(
          ctx,
        ).style.merge(tester.widget<Text>(find.text(label)).style);
        expect(
          style.color,
          isNotNull,
          reason: '"$label" has no colour, so it renders white',
        );
        expect(
          ground,
          isNot(contains(style.color)),
          reason: '"$label" is drawn in a background colour',
        );
      }
    });

    testWidgets('textTheme resolves all eight type steps', (tester) async {
      late TextTheme t;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              t = Theme.of(context).textTheme;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(t.displaySmall?.fontSize, AppType.displayL.fontSize);
      expect(t.titleLarge?.fontSize, AppType.titleL.fontSize);
      expect(t.titleMedium?.fontSize, AppType.titleM.fontSize);
      expect(t.titleSmall?.fontSize, AppType.titleS.fontSize);
      expect(t.bodyMedium?.fontSize, AppType.body.fontSize);
      expect(t.bodySmall?.fontSize, AppType.bodyS.fontSize);
      expect(t.labelMedium?.fontSize, AppType.label.fontSize);
      expect(t.labelSmall?.fontSize, AppType.caption.fontSize);

      // No slot may fall back to a Material default size.
      for (final style in [
        t.displayLarge,
        t.displayMedium,
        t.headlineLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.bodyLarge,
        t.labelLarge,
      ]) {
        expect(style?.fontFamily, 'Raleway');
      }
    });

    // Structural, not a brand colour: the decorative background is painted
    // once for the whole app in `app.dart`'s builder, and anything opaque
    // between it and the user hides it. That is what happened before the
    // device pass — the art reached only the five shell branches, and two
    // screens covered it even there. See docs/features/10b-device-pass.md, A4.
    test('nothing between the art and the user is opaque', () {
      expect(buildAppTheme(BrandConfig.milano).scaffoldBackgroundColor,
          Colors.transparent);
      expect(
        const AppScaffold(title: 't', body: SizedBox()).background,
        Colors.transparent,
        reason: 'AppScaffold must not default to an opaque ground',
      );
    });

    testWidgets('the brand seam reaches the whole theme', (tester) async {
      // Changing the brand must restyle the app with no other edit. Asserting
      // the scheme follows the config, not that it equals any particular value.
      const other = BrandConfig(
        appName: 'Other Orders',
        shortName: 'Other',
        tagline: 'Tagline',
        logoAsset: 'mobile-app-logo-trasnsp.png',
        primary: Color(0xFF00A0FF),
        onPrimary: Color(0xFF001020),
        deep: Color(0xFF003355),
        deepest: Color(0xFF001A2B),
        mark: Color(0xFF00507F),
        currencySymbol: r'$',
        locale: 'en_US',
      );

      final milano = buildAppTheme(BrandConfig.milano);
      final swapped = buildAppTheme(other);

      expect(swapped.colorScheme.primary, other.deep);
      expect(swapped.floatingActionButtonTheme.backgroundColor, other.primary);
      expect(swapped.tabBarTheme.labelColor, other.deep);
      expect(swapped.colorScheme.primary, isNot(milano.colorScheme.primary));
    });
  });

  group('money', () {
    test('groups the Indian way and carries the brand symbol', () {
      const b = BrandConfig.milano;
      expect(b.money(116717), '₹1,16,717');
      expect(b.count(116717), '1,16,717');
      expect(b.moneyDecimal(1234.5), '₹1,234.50');
      expect(b.moneyTrim(12.50), '₹12.5');
      expect(b.moneyTrim(12), '₹12');
    });

    test('follows the brand locale, not just the symbol', () {
      const us = BrandConfig(
        appName: 'x',
        shortName: 'x',
        tagline: 'x',
        logoAsset: 'x',
        primary: Color(0xFF000000),
        onPrimary: Color(0xFF000000),
        deep: Color(0xFF000000),
        deepest: Color(0xFF000000),
        mark: Color(0xFF000000),
        currencySymbol: r'$',
        locale: 'en_US',
      );
      expect(us.money(116717), r'$116,717');
    });
  });

  group('components build and render their text', () {
    testWidgets('AppScaffold shows caption, title and body', (tester) async {
      await tester.pumpWidget(
        host(
          const AppScaffold(
            caption: 'welcome back',
            title: 'Shops',
            body: Text('body'),
          ),
        ),
      );

      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('Shops'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('AppCard renders its child and taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(AppCard(onTap: () => tapped = true, child: const Text('card'))),
      );

      await tester.tap(find.text('card'));
      expect(tapped, isTrue);
    });

    testWidgets('StatBand renders every item', (tester) async {
      await tester.pumpWidget(
        host(
          const StatBand(
            items: [
              StatBandItem('16/18', label: 'shops'),
              StatBandItem('₹24,680'),
            ],
          ),
        ),
      );

      expect(find.text('16/18'), findsOneWidget);
      expect(find.text('shops'), findsOneWidget);
      expect(find.text('₹24,680'), findsOneWidget);
    });

    testWidgets('HeroStatCard renders caption, value and subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const HeroStatCard(
            caption: 'total outstanding',
            value: '₹1,16,717',
            subtitle: 'across 7 shops',
          ),
        ),
      );

      expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
      expect(find.text('₹1,16,717'), findsOneWidget);
      expect(find.text('across 7 shops'), findsOneWidget);
    });

    testWidgets('FilterChipRow reports the tapped index', (tester) async {
      int? selected;
      await tester.pumpWidget(
        host(
          FilterChipRow(
            chips: const [
              FilterChipData('All Shops', count: 18),
              FilterChipData('Needs Review', count: 2, tone: AppTone.warning),
            ],
            selectedIndex: 0,
            onSelected: (i) => selected = i,
          ),
        ),
      );

      expect(find.text('All Shops'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      await tester.tap(find.text('Needs Review'));
      expect(selected, 1);
    });

    // Regression, device pass 2026-09-05: the category chips on Products were
    // cut in half. The whole of `padding` went to the horizontal `ListView`,
    // and in a horizontal list the vertical half comes off the cross axis —
    // 40 − 8 − 8 left the chip 24px, its own 8+8 left 8px for the text, and a
    // 12px label needs 14.4. See docs/features/10b-device-pass.md, A3.
    testWidgets('FilterChipRow leaves its label room to be drawn', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const FilterChipRow(
            chips: [FilterChipData('🥐 Puffs')],
            selectedIndex: 0,
            onSelected: _ignore,
          ),
        ),
      );

      final label = find.text('🥐 Puffs');
      final chip = find
          .ancestor(of: label, matching: find.byType(InkWell))
          .first;

      // The chip must fit its own label plus its own vertical padding. This is
      // the defect stated as an assertion, and it holds whatever the row height
      // and the type step happen to be.
      expect(
        tester.getSize(chip).height,
        greaterThanOrEqualTo(
          tester.getSize(label).height + AppSpace.s2 * 2,
        ),
        reason: 'the chip is shorter than the text it contains',
      );

      // And the strip is the chip's box, not the chip's box minus the gutter.
      expect(tester.getSize(find.byType(FilterChipRow)).height,
          FilterChipRow.rowHeight + AppSpace.s2 * 2);
    });

    testWidgets('SectionHeader renders its action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: 'At Risk Shops',
            actionLabel: 'View all',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('At Risk Shops'), findsOneWidget);
      await tester.tap(find.text('View all'));
      expect(tapped, isTrue);
    });

    testWidgets('ListRow renders both columns and repaint-isolates itself', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ListRow(
            title: 'Hotel Raj',
            subtitle: 'Anna Nagar',
            subtitleIcon: Icons.location_on_outlined,
            trailing: '₹2,450',
            trailingSubtitle: '12 items',
            badge: StatusBadge(label: 'Pending', tone: AppTone.warning),
          ),
        ),
      );

      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Anna Nagar'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('12 items'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      // The reason the component exists at all — see doc 10a's perf section.
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('StatusBadge renders its label', (tester) async {
      await tester.pumpWidget(
        host(const StatusBadge(label: 'Overdue', tone: AppTone.negative)),
      );
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('DeltaPill takes its tone from the sign, not the call site', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              DeltaPill(value: 8, label: '8%'),
              DeltaPill(value: -120, label: '₹120'),
              DeltaPill(value: 240, label: '₹240', inverted: true),
              DeltaPill(value: 0, label: '0%'),
            ],
          ),
        ),
      );

      expect(find.text('8%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    });

    testWidgets('MiniTable renders headers and cells', (tester) async {
      await tester.pumpWidget(
        host(
          const MiniTable(
            headers: ['Item', 'Usual', 'Suggested', 'Change'],
            rows: [
              [
                Text('Bun'),
                Text('30'),
                Text('34'),
                DeltaPill(value: 4, label: '4'),
              ],
            ],
          ),
        ),
      );

      expect(find.text('ITEM'), findsOneWidget);
      expect(find.text('SUGGESTED'), findsOneWidget);
      expect(find.text('Bun'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
    });

    testWidgets('NoteBanner renders label and text', (tester) async {
      await tester.pumpWidget(
        host(const NoteBanner(label: 'Reason:', text: 'Shop closed Monday')),
      );

      expect(find.textContaining('Reason:'), findsOneWidget);
      expect(find.textContaining('Shop closed Monday'), findsOneWidget);
    });

    testWidgets('AppButton fires, and does not while busy', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              AppButton(label: 'Save Shop', onPressed: () => taps++),
              AppButton(label: 'Saving', onPressed: () => taps++, busy: true),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Save Shop'));
      await tester.tap(find.text('Saving'));
      expect(taps, 1);
    });

    testWidgets('every AppButton variant builds', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              for (final v in AppButtonVariant.values)
                AppButton(label: v.name, onPressed: () {}, variant: v),
            ],
          ),
        ),
      );

      for (final v in AppButtonVariant.values) {
        expect(find.text(v.name), findsOneWidget);
      }
    });

    testWidgets('EmptyState offers an action rather than sympathy', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No shops yet',
            message: 'Shops are who you deliver to.',
            actionLabel: 'Add your first shop',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('No shops yet'), findsOneWidget);
      await tester.tap(find.text('Add your first shop'));
      expect(tapped, isTrue);
    });

    testWidgets('EmptyState.inert builds without an action', (tester) async {
      await tester.pumpWidget(
        host(
          const EmptyState.inert(
            icon: Icons.event_busy_outlined,
            title: 'No orders',
            message: 'Nothing was ordered on this date.',
          ),
        ),
      );

      expect(find.text('No orders'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('AppErrorView shows message, cause and a way out', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        host(
          AppErrorView(
            message: "Could not load today's orders.",
            cause: 'DatabaseException: no such table: orders',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text("Could not load today's orders."), findsOneWidget);
      expect(
        find.text('DatabaseException: no such table: orders'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('AppErrorView without a cause or a retry builds', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AppErrorView(message: 'That shop is gone.')),
      );

      expect(find.text('That shop is gone.'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('AppSkeleton builds alone and as a list', (tester) async {
      await tester.pumpWidget(host(const AppSkeleton()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSkeleton), findsOneWidget);

      await tester.pumpWidget(host(AppSkeleton.list(count: 3)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSkeleton), findsNWidgets(3));
    });
  });
}

/// A const-able no-op, so a `FilterChipRow` under test can stay `const`.
void _ignore(int _) {}
