import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Shops'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.shops),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bakery_dining_outlined),
            title: const Text('Products'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.products),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Prices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.prices),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: const Text('Standing Orders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.standingOrders),
          ),
        ],
      ),
    );
  }
}
