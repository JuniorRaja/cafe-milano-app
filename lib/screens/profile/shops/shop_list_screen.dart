import 'package:flutter/material.dart';

class ShopListScreen extends StatelessWidget {
  const ShopListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shops')),
      body: const Center(child: Text('Shops')),
    );
  }
}
