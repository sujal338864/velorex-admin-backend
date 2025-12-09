import 'package:flutter/material.dart';

class FullAnalyticsPage extends StatelessWidget {
  final int totalProducts;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  final int totalOrders;
  final int pending;
  final int processing;
  final int shipped;
  final int cancelled;
  final double totalRevenue;

  const FullAnalyticsPage({
    super.key,
    required this.totalProducts,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.totalOrders,
    required this.pending,
    required this.processing,
    required this.shipped,
    required this.cancelled,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Product Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Total Products: $totalProducts'),
            Text('In Stock: $inStock'),
            Text('Low Stock: $lowStock'),
            Text('Out of Stock: $outOfStock'),
            const SizedBox(height: 24),
            const Text(
              'Order Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Total Orders: $totalOrders'),
            Text('Pending: $pending'),
            Text('Processing: $processing'),
            Text('Shipped: $shipped'),
            Text('Cancelled: $cancelled'),
            Text('Total Revenue: ₹${totalRevenue.toStringAsFixed(2)}'),
            const SizedBox(height: 24),
            const Text(
              'More charts can be added here later (time-series, category-wise, etc.)',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
