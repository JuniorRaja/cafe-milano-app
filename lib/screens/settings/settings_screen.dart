import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../providers/business_info_provider.dart';
import '../../providers/dashboard_settings_provider.dart';
import '../../providers/price_provider.dart';
import '../../providers/settings_summary_provider.dart';
import '../../services/update_service.dart';
import '../../theme/brand_config.dart';
import '../../widgets/shell/destinations.dart';
import '../../widgets/ui/ui.dart';

/// Configuration, and the way in to everything the drawer also lists.
///
/// Two things changed here in doc 10b, beyond the rename from "Profile" — a
/// tab named after something it did not contain.
///
/// **Every tile reports state instead of prose.** "Manage shop details and
/// status" told the owner nothing they did not already know; "18 active · 2
/// inactive" answers a question. Each summary is one aggregate, never a
/// per-row read.
///
/// **The masters are not listed here.** Shops, Products, Categories and the
/// Price Matrix live in the drawer's Catalogue group and nowhere else. They
/// were briefly in both; two doors to one room is how "Profile" became a
/// filing cabinet in the first place. The search below still reaches them, so
/// nothing got further away.
///
/// **The search field searches the whole app**, not this screen. It reads
/// `destinations.dart` as well as the rows below, which is what makes ~28
/// destinations navigable from one keystroke.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  PackageInfo? _packageInfo;
  bool _checkingForUpdate = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    }).ignore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final searching = _query.trim().isNotEmpty;

    return AppScaffold(
      caption: 'Manage',
      title: 'Settings',
      background: AppColors.bg,
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s3,
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search settings and screens',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: !searching
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      body: searching ? _searchResults() : _sections(brand),
    );
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Widget _searchResults() {
    final destinations =
        visibleDestinations.where((d) => d.matches(_query)).toList();
    final rows = _configRows().where((r) => r.matches(_query)).toList();

    if (destinations.isEmpty && rows.isEmpty) {
      return EmptyState.inert(
        icon: Icons.search_off_rounded,
        title: 'Nothing matches',
        message: 'No screen or setting matches "${_query.trim()}".',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      children: [
        if (destinations.isNotEmpty) ...[
          const SectionHeader(title: 'Screens'),
          AppCard(
            margin: AppSpace.page,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final dest in destinations)
                  _Tile(
                    icon: dest.icon,
                    title: dest.label,
                    subtitle: dest.route,
                    onTap: () => _openDestination(dest),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
        ],
        if (rows.isNotEmpty) ...[
          const SectionHeader(title: 'Settings'),
          _card(rows),
        ],
      ],
    );
  }

  void _openDestination(AppDestination dest) {
    if (bottomBarRoutes.contains(dest.route)) {
      context.go(dest.route);
    } else {
      unawaited(context.push(dest.route));
    }
  }

  // ---------------------------------------------------------------------------
  // The full screen
  // ---------------------------------------------------------------------------

  Widget _sections(BrandConfig brand) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      children: [
        const SectionHeader(title: 'Configuration'),
        _card(_configRows()),
        const SizedBox(height: AppSpace.s5),
        _About(brand: brand, packageInfo: _packageInfo),
      ],
    );
  }

  Widget _card(List<_Row> rows) {
    return AppCard(
      margin: AppSpace.page,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 64),
            _Tile(
              icon: rows[i].icon,
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              tone: rows[i].tone,
              trailing: rows[i].trailing,
              onTap: rows[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rows, each with a live summary
  // ---------------------------------------------------------------------------

  List<_Row> _configRows() {
    final businessInfo = ref.watch(businessInfoProvider);
    final coverage = ref.watch(catalogueCoverageProvider);
    final dashboard = ref.watch(dashboardSettingsProvider);
    final lastExport = ref.watch(lastBackupExportProvider);
    final info = _packageInfo;

    return [
      _Row(
        icon: Icons.storefront_outlined,
        title: 'Business Info',
        subtitle: businessInfo.maybeWhen(
          data: (data) => data?.name.trim().isNotEmpty == true
              ? data!.name
              : 'Not set — used on shared catalogues',
          orElse: () => '…',
        ),
        tone: businessInfo.maybeWhen(
          data: (data) =>
              data?.name.trim().isNotEmpty == true ? null : AppTone.warning,
          orElse: () => null,
        ),
        keywords: const ['name', 'address', 'logo', 'contact'],
        onTap: () => context.push(AppRoutes.businessInfo),
      ),
      _Row(
        icon: Icons.repeat_outlined,
        title: 'Standing Orders',
        subtitle: coverage.maybeWhen(
          data: (c) => c.shopsWithStandingOrders == 0
              ? 'No default quantities set'
              : '${c.shopsWithStandingOrders} '
                  '${c.shopsWithStandingOrders == 1 ? 'shop has' : 'shops have'}'
                  ' default quantities',
          orElse: () => '…',
        ),
        keywords: const ['defaults', 'quantities', 'prefill'],
        onTap: () => context.push(AppRoutes.standingOrders),
      ),
      _Row(
        icon: Icons.dashboard_customize_outlined,
        title: 'Dashboard sections',
        subtitle: '${dashboard.enabledSectionCount} '
            '${dashboard.enabledSectionCount == 1 ? 'section' : 'sections'} '
            'visible',
        keywords: const ['kpi', 'cards', 'customise', 'customize'],
        onTap: () => context.push(AppRoutes.dashboardSettings),
      ),
      _Row(
        icon: Icons.backup_outlined,
        title: 'Backup & Restore',
        subtitle: lastExport.maybeWhen(
          data: (at) => at == null
              ? 'Never exported'
              : 'Last exported ${_relativeDay(at)}',
          orElse: () => '…',
        ),
        tone: lastExport.maybeWhen(
          data: (at) => at == null ? AppTone.warning : null,
          orElse: () => null,
        ),
        keywords: const ['export', 'import', 'restore', 'data', 'json'],
        onTap: () => context.push(AppRoutes.backupRestore),
      ),
      _Row(
        icon: Icons.system_update_outlined,
        title: 'Check for updates',
        subtitle: info == null
            ? 'Installed version unknown'
            : 'Installed v${info.version} (build ${info.buildNumber})',
        trailing: _checkingForUpdate
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        keywords: const ['version', 'upgrade', 'download'],
        onTap: _checkingForUpdate ? null : () => unawaited(_checkForUpdate()),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Update check — moved here whole from the old profile screen
  // ---------------------------------------------------------------------------

  Future<void> _checkForUpdate() async {
    final packageInfo = _packageInfo;
    if (packageInfo == null || _checkingForUpdate) return;

    setState(() => _checkingForUpdate = true);
    try {
      final update = await checkForUpdate(int.parse(packageInfo.buildNumber));
      if (!mounted) return;

      if (update == null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("You're up to date"),
            content: Text(
              'Version ${packageInfo.version} '
              '(build ${packageInfo.buildNumber}) is the latest.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update available'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Version ${update.version} is available.',
                  style: AppType.titleS,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(update.releaseNotes, style: AppType.body),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(launchUrl(
                  Uri.parse(update.downloadUrl),
                  mode: LaunchMode.externalApplication,
                ));
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Check failed'),
          content: Text('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }
}

String _relativeDay(DateTime at) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    < 7 => '$days days ago',
    _ => 'on ${DateFormat('d MMM yyyy').format(at)}',
  };
}

/// One settings row, before it becomes a widget. Held as data so the search
/// field can filter the same list the screen draws.
class _Row {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
    this.trailing,
    this.keywords = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppTone? tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<String> keywords;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        keywords.any((k) => k.contains(q));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppTone? tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Transparent Material, not decoration. AppCard is a DecoratedBox, and a
    // ListTile paints its ink on the nearest Material ancestor — without this
    // the tap ripple is drawn behind the card and never seen.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.rS,
          ),
          child: Icon(icon, color: AppColors.brandDeep, size: 20),
        ),
        title: Text(title, style: AppType.titleS),
        subtitle: Text(
          subtitle,
          style: AppType.bodyS.copyWith(
            color: tone?.fg ?? AppColors.textSecondary,
          ),
        ),
        trailing: trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
        onTap: onTap,
      ),
    );
  }
}

/// Absorbs the branding block and version footer the old profile screen
/// rendered inline.
class _About extends StatelessWidget {
  const _About({required this.brand, required this.packageInfo});

  final BrandConfig brand;
  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(brand.logoAsset, width: 56, height: 56, cacheWidth: 168),
        const SizedBox(height: AppSpace.s2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: brand.shortName,
                style: AppType.titleM.copyWith(color: AppColors.brandDeep),
              ),
              TextSpan(
                text: brand.appNameRest,
                style: AppType.titleM.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          brand.tagline,
          style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          packageInfo == null
              ? ' '
              : 'v${packageInfo!.version} (build ${packageInfo!.buildNumber})',
          style: AppType.label.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
