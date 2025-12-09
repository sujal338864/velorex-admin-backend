// ignore_for_file: avoid_print

import 'dart:convert';

// Compute parser
List<Items> parseItems(String responseBody) {
  final List<dynamic> decoded = json.decode(responseBody);
  return decoded.map((e) => Items.fromMap(Map<String, dynamic>.from(e))).toList();
}

class OnesolutionModel {
  static List<Items> items = [];

  Items? getById(int id) {
    try {
      return items.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  Items getByPosition(int pos) => items[pos];
}

class Items {
  final int id;
  final String name;
  final String description;

  final int price;
  final int offerPrice;

  final String brand;
  final int? brandId;

  final List<String> images;
  final List<String> imageUrls;

  final int? categoryId;
  final String? categoryName;

  final int? subcategoryId;

  final int stock;
  final int quantity;

  final DateTime? createdAt;

  final bool isSponsored;
  final String? sku;

  final int? parentProductId; // For variant

  String get firstImage =>
      images.isNotEmpty ? images.first : "https://via.placeholder.com/150";

  Items({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.offerPrice,
    required this.brand,
    required this.images,
    required this.imageUrls,
    required this.brandId,
    required this.categoryId,
    this.categoryName,
    this.subcategoryId,
    required this.stock,
    required this.quantity,
    this.createdAt,
    required this.isSponsored,
    this.sku,
    this.parentProductId,
  });

  factory Items.fromMap(Map<String, dynamic> map) {
    // -------------------------
    // IMAGE PARSING
    // -------------------------
    List<String> parsedImages = [];

    try {
      final dynamic ip =
          map['images'] ?? map['imageUrls'] ?? map['ImageURLs'] ?? map['ImageURL'];

      if (ip == null) {
        parsedImages = [];
      } else if (ip is List) {
        parsedImages = List<String>.from(ip.map((e) => e.toString()));
      } else if (ip is String) {
        if (ip.trim().startsWith("[")) {
          final decoded = json.decode(ip);
          parsedImages = List<String>.from(decoded.map((e) => e.toString()));
        } else if (ip.contains(",")) {
          parsedImages =
              ip.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else {
          parsedImages = [ip];
        }
      }
    } catch (e) {
      print("⚠️ Image parse error: $e");
      parsedImages = [];
    }

    // Convert relative to full Supabase URL
    parsedImages = parsedImages.map((path) {
      if (path.startsWith("http")) return path;
      return "https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/product/$path";
    }).toList();

    if (parsedImages.isEmpty) {
      parsedImages = ["https://via.placeholder.com/150"];
    }

    // -------------------------
    // PRICE PARSING
    // -------------------------
    int p = int.tryParse(map['price']?.toString() ?? "0") ?? 0;
    int op = int.tryParse(map['offerPrice']?.toString() ??
            map['offer_price']?.toString() ??
            "0") ??
        p;

    // -------------------------
    // RETURN ITEM
    // -------------------------
    return Items(
      id: int.tryParse(map['id']?.toString() ?? "0") ?? 0,
      name: map['name']?.toString() ?? "",
      description: map['description']?.toString() ?? "",
      price: p,
      offerPrice: op,
      brand: map['brandName']?.toString() ?? map['brand']?.toString() ?? "",
      brandId: map['brandId'] is int
          ? map['brandId']
          : int.tryParse(map['brandId']?.toString() ?? ""),
      imageUrls: parsedImages,
      images: parsedImages,
      categoryId: map['categoryId'] is int
          ? map['categoryId']
          : int.tryParse(map['categoryId']?.toString() ?? ""),
      categoryName: map['categoryName']?.toString(),
      subcategoryId: map['subcategoryId'] is int
          ? map['subcategoryId']
          : int.tryParse(map['subcategoryId']?.toString() ?? ""),
      stock: int.tryParse(map['stock']?.toString() ?? "0") ?? 0,
      quantity: int.tryParse(map['quantity']?.toString() ?? "1") ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      isSponsored:
          (map['isSponsored']?.toString() == "1" || map['isSponsored'] == true),
      sku: map['sku']?.toString(),
      parentProductId: map['parentProductId'] is int
          ? map['parentProductId']
          : int.tryParse(map['parentProductId']?.toString() ?? ""),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "price": price,
      "offerPrice": offerPrice,
      "brand": brand,
      "brandId": brandId,
      "images": images,
      "categoryId": categoryId,
      "subcategoryId": subcategoryId,
      "stock": stock,
      "quantity": quantity,
      "createdAt": createdAt?.toIso8601String(),
      "isSponsored": isSponsored,
      "sku": sku,
      "parentProductId": parentProductId,
    };
  }
}
