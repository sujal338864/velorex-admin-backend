// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:admin_panel/services/order_service.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? orderDetail;
  bool isLoading = true;

  final statusOptions = [
    'Pending',
    'Packed',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];

  final Map<int, TextEditingController> trackingControllers = {};
  String? overallStatus;

  @override
  void initState() {
    super.initState();
    loadOrderDetails();
  }

  // ✅ Load order details
  Future<void> loadOrderDetails() async {
    final data =
        await AdminOrderService.getOrderDetails(widget.order['orderId']);
    if (!mounted) return;
    setState(() {
      orderDetail = data;
      isLoading = false;
      if (data != null) {
        overallStatus = data['orderStatus'] ?? 'Pending';
        for (var item in data['items'] ?? []) {
          final id = item['orderItemId'];
          trackingControllers[id] =
              TextEditingController(text: item['itemTrackingUrl'] ?? '');
        }
      }
    });
  }

  // ✅ Update overall order status
  Future<void> updateOrderStatus(String newStatus) async {
    final success = await AdminOrderService.updateOrderStatus(
      widget.order['orderId'],
      newStatus,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? '✅ Order status updated to $newStatus'
          : '❌ Failed to update order'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));

    if (success) await loadOrderDetails();
  }

  // ✅ Update tracking URL for a specific item
  Future<void> updateItemTracking(int orderItemId, String trackingUrl) async {
    final success = await AdminOrderService.updateOrderItemTracking(
      orderItemId,
      trackingUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? '✅ Tracking URL updated!'
          : '❌ Failed to update tracking'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));

    if (success) await loadOrderDetails();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (orderDetail == null) {
      return const Scaffold(
        body: Center(child: Text('No order details found')),
      );
    }

    final order = orderDetail!;
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text('📦 Order #${order['orderId']}'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadOrderDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🟢 BASIC ORDER INFO + STATUS
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👤 Customer: ${order['userName'] ?? 'N/A'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    Text('📧 Email: ${order['userEmail'] ?? 'N/A'}'),
                    Text('📅 Date: ${order['createdAt'] ?? 'Unknown'}'),
                    const SizedBox(height: 12),
                    const Text('📋 Order Status:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    DropdownButton<String>(
                      value: overallStatus ?? 'Pending',
                      items: statusOptions
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => overallStatus = val);
                          await updateOrderStatus(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🛍️ ORDER ITEMS
            const Text('🛍️ Order Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (items.isEmpty)
              const Text('No items found')
            else
              ...items.map((item) {
                final id = item['orderItemId'];
                final trackingController = trackingControllers[id];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: (item['imageUrls'] != null &&
                                  item['imageUrls'].isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item['imageUrls'][0],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.image, size: 50),
                          title: Text(
                            item['productName'] ?? 'Unnamed Product',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: Text(
                              'Qty: ${item['quantity']} × ₹${item['price']}'),
                          trailing: Text(
                            '₹${(item['quantity'] ?? 0) * (item['price'] ?? 0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: trackingController,
                          decoration: InputDecoration(
                            labelText: 'Tracking URL',
                            hintText: 'Enter tracking link...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Save Tracking'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                            ),
                            onPressed: () {
                              updateItemTracking(
                                  id, trackingController?.text ?? '');
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }),

            const Divider(thickness: 1.2, height: 32),

            // 💳 PAYMENT INFO
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💳 Payment Info',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Method: ${order['paymentMethod'] ?? 'N/A'}'),
                    Text('Total: ₹${order['totalAmount'] ?? 0}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🚚 SHIPPING
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🚚 Shipping Address',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(order['shippingAddress'] ?? 'No address available'),
                  ],
                ),
              ),
            ),
            
          ],
        ),
      ),
    );
  }
}
