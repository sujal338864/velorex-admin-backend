// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminOrderService {
static const String baseUrl = "http://10.248.214.36:3001/api/admin/orders";


  // 🟢 Get all orders
  static Future<List<dynamic>> getAllOrders() async {
    final res = await http.get(Uri.parse(baseUrl));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['data'] ?? [];
    }
    return [];
  }
  // 🟣 Update tracking URL only
  static Future<bool> updateOrderItemTracking(
      int orderItemId, String trackingUrl) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/item/$orderItemId/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'trackingUrl': trackingUrl}),
      );
      final data = jsonDecode(res.body);
      return res.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print("❌ Error updating tracking URL: $e");
      return false;
    }
  }
  // 🟢 Get single order details
  static Future<Map<String, dynamic>?> getOrderDetails(int orderId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$orderId'));
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      }
    } catch (e) {
      print("❌ Error fetching order detail: $e");
    }
    return null;
  }

  // 🟡 Update order status
  static Future<bool> updateOrderStatus(int orderId, String status) async {
    final res = await http.put(
      Uri.parse("$baseUrl/$orderId/status"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );
    return res.statusCode == 200;
  }

static Future<bool> updateOrderItem(
    int orderItemId, String status, String trackingUrl) async {
  try {
    final res = await http.put(
      Uri.parse('$baseUrl/item/$orderItemId/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'trackingUrl': trackingUrl}),
    );
    final data = jsonDecode(res.body);
    return res.statusCode == 200 && data['success'] == true;
  } catch (e) {
    print("❌ Error updating order item: $e");
    return false;
  }
}


  // 🔴 Delete order
  static Future<bool> deleteOrder(int orderId) async {
    final response = await http.delete(Uri.parse("$baseUrl/$orderId"));
    return response.statusCode == 200;
  }
}

// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class AdminOrderService {
//   static const String baseUrl = "http://10.147.77.36:3001/api/admin/orders";

// static Future<List<dynamic>> getAllOrders() async {
//   final res = await http.get(Uri.parse(baseUrl));
//   if (res.statusCode == 200) {
//     final body = jsonDecode(res.body);
//     return body['data'] ?? [];
//   } else {
//   }
//   return [];
// }

// static Future<bool> updateOrderStatus(int orderId, String status) async {
//   final res = await http.put(
//     Uri.parse("$baseUrl/$orderId/status"),
//     headers: {"Content-Type": "application/json"},
//     body: jsonEncode({"status": status}),
//   );
//   return res.statusCode == 200;
// }


//     // 🗑️ NEW: Delete Order
//   static Future<bool> deleteOrder(int orderId) async {
//     final response = await http.delete(Uri.parse("$baseUrl/$orderId"));
//     return response.statusCode == 200;
//   }
//     // 🟢 Get order details
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
