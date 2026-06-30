import 'package:flutter/material.dart';

class OrderEntryScreen extends StatelessWidget {
  const OrderEntryScreen({super.key, required this.shopId, this.date});

  final int shopId;
  final String? date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Entry')),
      body: Center(child: Text('Order Entry — Shop $shopId')),
    );
  }
}
