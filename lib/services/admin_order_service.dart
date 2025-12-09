// // ignore_for_file: avoid_print
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class AdminOrderDetailService {
//   final String baseUrl = "http://10.147.77.36:3001/api/admin/ordersback";

//   // 🟢 Get order details
//   Future<Map<String, dynamic>?> getOrderDetails(int orderId) async {
//     try {
//       final response = await http.get(Uri.parse('$baseUrl/$orderId'));
//       print('🔵 GET Order Detail: ${response.statusCode}');
//       print('Body: ${response.body}');

//       final data = json.decode(response.body);
//       if (response.statusCode == 200 && data['success'] == true) {
//         return data['data'];
//       }
//     } catch (e) {
//       print("❌ Error fetching order detail: $e");
//     }
//     return null;
//   }

//   // 🟡 Update single order item
//   Future<bool> updateOrderItem(int orderItemId, String status, String trackingUrl) async {
//     try {
//       final response = await http.put(
//         Uri.parse('$baseUrl/item/$orderItemId/update'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'status': status,
//           'trackingUrl': trackingUrl,
//         }),
//       );

//       final data = json.decode(response.body);
//       print('🟣 Update Response: ${response.body}');
//       return data['success'] ?? false;
//     } catch (e) {
//       print("❌ Error updating order item: $e");
//       return false;
//     }
//   }
// }

