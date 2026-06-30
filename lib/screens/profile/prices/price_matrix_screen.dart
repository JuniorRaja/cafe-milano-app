import 'package:flutter/material.dart';

class PriceMatrixScreen extends StatelessWidget {
  const PriceMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prices')),
      body: const Center(child: Text('Price Matrix')),
    );
  }
}
