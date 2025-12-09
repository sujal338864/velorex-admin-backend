// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'package:admin_panel/pages/order_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:admin_panel/services/order_service.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  List<dynamic> orders = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final data = await AdminOrderService.getAllOrders();
      orders = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      orders = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error fetching orders: $e")),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteOrder(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Order?"),
        content: const Text("Are you sure you want to delete this order?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminOrderService.deleteOrder(orderId);
      if (success) {
        fetchOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Order deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to delete order")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Admin Orders'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchOrders,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
                ? const Center(child: Text('No orders found'))
               : SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStatePropertyAll(Colors.deepPurple.shade100),
        border: TableBorder.all(color: Colors.grey.shade300),
        columns: const [
          DataColumn(label: Text('Order ID')),
          DataColumn(label: Text('Customer Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Total ₹')),
          DataColumn(label: Text('Payment')),
          DataColumn(label: Text('Order Status')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Edit')),
          DataColumn(label: Text('Delete')),
        ],
        rows: orders.map((order) {
          final createdAt = order['createdAt']?.toString().split('T').first ?? '';

          return DataRow(cells: [
            DataCell(Text('#${order['orderId']}')),
            DataCell(Text(order['userName'] ?? 'N/A')),
            DataCell(Text(order['userEmail'] ?? 'N/A')),
            DataCell(Text('₹${order['totalAmount']}')),
            DataCell(Text(order['paymentMethod'] ?? 'N/A')),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(order['orderStatus']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order['orderStatus'] ?? 'Pending',
                style: TextStyle(
                  color: _statusColor(order['orderStatus']),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
            DataCell(Text(createdAt)),
            DataCell(IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(order: order),
                  ),
                );
                fetchOrders();
              },
            )),
            DataCell(IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteOrder(order['orderId']),
            )),
          ]);
        }).toList(),
      ),
    ),
  ),

      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "Delivered":
        return Colors.green;
      case "Processing":
        return Colors.orange;
      case "Shipped":
        return Colors.blue;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
