import 'package:flutter/material.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen')),
      body: const Center(child: Text('Kitchen')),
    );
  }
}
