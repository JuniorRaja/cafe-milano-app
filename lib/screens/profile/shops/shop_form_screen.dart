import 'package:flutter/material.dart';

class ShopFormScreen extends StatelessWidget {
  const ShopFormScreen({super.key, this.shopId});

  final int? shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(shopId == null ? 'New Shop' : 'Edit Shop')),
      body: const Center(child: Text('Shop Form')),
    );
  }
}
