import 'package:flutter/material.dart';

class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(productId == null ? 'New Product' : 'Edit Product')),
      body: const Center(child: Text('Product Form')),
    );
  }
}
