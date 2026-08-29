import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../ui/ui.dart';
import 'destinations.dart';

/// The side menu. **Mobile only, and never desktop** — no rail, no breakpoint
/// layouts, no wide-screen work now or later. That is the owner's decision of
/// 2026-08-26 and it is not a gap to be filled in.
///
/// Every row comes from `destinations.dart`. Nothing is listed here by hand,
/// which is what makes adding a destination in doc 12, 15 or 16 a one-line
/// change rather than three.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final active = destinationForLocation(location);

    return Drawer(
      backgroundColor: AppColors.brandDeepest,
      width: 296,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _DrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpace.s3),
                children: [
                  for (final dest in destinationsIn(DestGroup.primary))
                    _DrawerRow(destination: dest, active: dest == active),
                  for (final group in const [
                    DestGroup.daily,
                    DestGroup.money,
                    DestGroup.catalogue,
                  ])
                    ..._group(group, active),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            for (final dest in destinationsIn(DestGroup.system))
              _DrawerRow(destination: dest, active: dest == active),
            const _OutstandingCard(),
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(DestGroup group, AppDestination? active) {
    final items = destinationsIn(group);
    if (items.isEmpty) return const [];
    return [
      if (group.showHeader)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s1,
          ),
          child: Text(
            group.label.toUpperCase(),
            style: AppType.caption.copyWith(color: Colors.white38),
          ),
        ),
      for (final dest in items)
        _DrawerRow(destination: dest, active: dest == active),
    ];
  }
}

class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s5,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.rS,
            child: Image.asset(
              brand.logoAsset,
              width: 40,
              height: 40,
              cacheWidth: 120,
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  brand.appName,
                  style: AppType.titleM.copyWith(color: AppColors.textOnDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  brand.tagline,
                  style: AppType.bodyS.copyWith(color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({required this.destination, required this.active});

  final AppDestination destination;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: 2,
      ),
      child: Material(
        color: active ? AppColors.bg : Colors.transparent,
        borderRadius: AppRadius.rFull,
        child: InkWell(
          borderRadius: AppRadius.rFull,
          onTap: () => _go(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s3,
            ),
            child: Row(
              children: [
                Icon(
                  active ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: active ? AppColors.brandDeep : AppColors.textOnDark,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    destination.label,
                    style: AppType.titleS.copyWith(
                      color:
                          active ? AppColors.brandDeep : AppColors.textOnDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context) {
    Navigator.of(context).pop(); // close the drawer first

    // A bottom-bar destination switches branch; everything else is pushed over
    // the shell so back returns to the tab it was opened from rather than to
    // the drawer or to Home.
    if (bottomBarRoutes.contains(destination.route)) {
      context.go(destination.route);
    } else {
      unawaited(context.push(destination.route));
    }
  }
}

/// Reference image 4's best idea: a module's headline number living
/// permanently in the navigation.
///
/// It fixes the audit's finding that all-shops outstanding was not reachable
/// anywhere in the app — not buried, *absent*. It is now readable without
/// opening a screen at all.
class _OutstandingCard extends ConsumerWidget {
  const _OutstandingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final summaryAsync = ref.watch(outstandingSummaryProvider);
    final today = ref.watch(todayProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s3,
        AppSpace.s3,
        AppSpace.s3,
        AppSpace.s2,
      ),
      child: Material(
        color: Colors.white10,
        borderRadius: AppRadius.rM,
        child: InkWell(
          borderRadius: AppRadius.rM,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push(AppRoutes.outstanding));
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: summaryAsync.when(
              loading: () => _body(brand, null, today),
              error: (e, _) => Text(
                'Outstanding unavailable',
                style: AppType.bodyS.copyWith(color: Colors.white54),
              ),
              data: (summary) => _body(brand, summary, today),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BrandConfig brand, OutstandingSummary? summary, DateTime today) {
    final age = summary?.ageInDays(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'OUTSTANDING',
                style: AppType.caption.copyWith(color: Colors.white38),
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white38,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          summary == null ? '—' : brand.money(summary.total),
          style: AppType.displayL.copyWith(color: AppColors.textOnDark),
        ),
        const SizedBox(height: 2),
        Text(
          switch (summary) {
            null => 'Loading',
            final s when s.shopCount == 0 => 'Everyone is settled up',
            final s => 'Owed by ${s.shopCount} '
                '${s.shopCount == 1 ? 'shop' : 'shops'}'
                '${age == null ? '' : ' · oldest $age d'}',
          },
          style: AppType.bodyS.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSpace.s3 + MediaQuery.of(context).padding.bottom,
      ),
      child: Text(
        info == null ? ' ' : 'v${info.version} (build ${info.buildNumber})',
        style: AppType.label.copyWith(color: Colors.white24),
      ),
    );
  }
}
