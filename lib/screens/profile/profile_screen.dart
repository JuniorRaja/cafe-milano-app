import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Settings & Configuration',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
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
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Bake',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            TextSpan(
                              text: 'Order',
                              style: TextStyle(
                                color: kBrandBrown,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Daily Bakery Order Manager',
                        style: TextStyle(
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
                  icon: Icons.bakery_dining_outlined,
                  title: 'Products',
                  subtitle: 'Manage bakery product catalog',
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
              ],
            ),
          ),
        ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
      trailing:
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
    );
  }
}
