import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app.dart';
import '../../theme/brand_config.dart';
import '../../services/update_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  PackageInfo? _packageInfo;
  bool _checkingForUpdate = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  Future<void> _checkForUpdate() async {
    final packageInfo = _packageInfo;
    if (packageInfo == null || _checkingForUpdate) return;

    setState(() => _checkingForUpdate = true);
    try {
      final update =
          await checkForUpdate(int.parse(packageInfo.buildNumber));
      if (!mounted) return;

      if (update == null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("You're up to date"),
            content: Text(
                'Version ${packageInfo.version} (build ${packageInfo.buildNumber}) is the latest.'),
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
                Text('Version ${update.version} is available.',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(update.releaseNotes),
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
                launchUrl(Uri.parse(update.downloadUrl),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
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
      }
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      color: kBrandGold, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PROFILE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kBrandBrown,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App branding header — gold background matching logo
          Card(
            color: kBrandGold,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.bakery_dining,
                        color: kBrandBrown, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: brand.shortName,
                              style: const TextStyle(
                                color: kBrandBrown,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            TextSpan(
                              text: brand.appNameRest,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        brand.tagline,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'MANAGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.store_outlined,
                  title: 'Shops',
                  subtitle: 'Manage shop details and status',
                  onTap: () => context.push(AppRoutes.shops),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Group products by category',
                  onTap: () => context.push(AppRoutes.categories),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.bakery_dining_outlined,
                  title: 'Products',
                  subtitle: 'Manage product catalog',
                  onTap: () => context.push(AppRoutes.products),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.price_change_outlined,
                  title: 'Price Matrix',
                  subtitle: 'Set product prices per shop',
                  onTap: () => context.push(AppRoutes.prices),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.repeat_outlined,
                  title: 'Standing Orders',
                  subtitle: 'Default order quantities per shop',
                  onTap: () => context.push(AppRoutes.standingOrders),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.storefront_outlined,
                  title: 'Business Info',
                  subtitle: 'Name, contact & logo for shared catalogs',
                  onTap: () => context.push(AppRoutes.businessInfo),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Dashboard',
                  subtitle: 'Customize visible sections & KPI help',
                  onTap: () => context.push(AppRoutes.dashboardSettings),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.backup_outlined,
                  title: 'Backup & Restore',
                  subtitle: 'Export or import all your data',
                  onTap: () => context.push(AppRoutes.backupRestore),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsTile(
                  icon: Icons.system_update_outlined,
                  title: 'Check for updates',
                  subtitle: _packageInfo != null
                      ? 'Installed: v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
                      : 'Installed version unknown',
                  trailing: _checkingForUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _checkingForUpdate ? null : _checkForUpdate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  brand.appName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _packageInfo != null
                      ? 'v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
                      : ' ',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: kBrandGold.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: kBrandBrown, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
    );
  }
}
