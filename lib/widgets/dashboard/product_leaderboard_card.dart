import 'package:flutter/material.dart';
import '../../app.dart';

class ProductLeaderboardCard extends StatelessWidget {
  const ProductLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Product Leaderboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kBrandBrown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Top 10 products by revenue across all shops',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Coming in Phase B',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
