// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:admin_panel/models/spec_models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static const String baseUrl = "http://10.248.214.36:3001/api";
  static List<Map<String, dynamic>>? _cachedCategories;


  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final url = Uri.parse("$baseUrl/dashboard/summary");
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw Exception("Summary failed");
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getOrdersByDay({int days = 7}) async {
    final url = Uri.parse("$baseUrl/dashboard/orders-by-day?days=$days");
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw Exception("Orders-by-day failed");
    return json.decode(resp.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getStockDistribution() async {
    final url = Uri.parse("$baseUrl/dashboard/stock-distribution");
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw Exception("Stock distribution failed");
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getTopProducts({int limit = 5}) async {
    final url = Uri.parse("$baseUrl/dashboard/top-products?limit=$limit");
    final resp = await http.get(url);
    if (resp.statusCode != 200) throw Exception("Top products failed");
    return json.decode(resp.body) as List<dynamic>;
  }


  /// ------------------- 🔧 HELPER -------------------

  /// Must match backend sanitizeComboKey
  static String sanitizeComboKey(String key) {
    return key
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// ------------------- 📦bulk producs----------------

  /// For MOBILE / DESKTOP (File)
  static Future<bool> uploadBulkProductsFile(File file) async {
    final uri = Uri.parse('$baseUrl/products/bulk-upload');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'bulk_products.xlsx',
        contentType: MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      print("✅ Bulk upload success: ${response.body}");
      return true;
    } else {
      print("❌ Bulk upload failed: ${response.statusCode} ${response.body}");
      return false;
    }
  }

  /// For WEB (Uint8List from file_picker)
  static Future<bool> uploadBulkProductsBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$baseUrl/products/bulk-upload');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      print("✅ Bulk upload success: ${response.body}");
      return true;
    } else {
      print("❌ Bulk upload failed: ${response.statusCode} ${response.body}");
      return false;
    }
  }

  /// ---------------------------------------------------
  /// GET ALL PRODUCTS
  /// ---------------------------------------------------
  static Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await http.get(Uri.parse('$baseUrl/products'));
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception("Failed to load products");
  }

  /// ---------------------------------------------------
  /// GET PRODUCTS BY GROUP ID (for variants)
  /// /products/by-group/:groupId
  /// ---------------------------------------------------
  static Future<List<Map<String, dynamic>>> getProductsByGroup(
      int groupId) async {
    final res =
        await http.get(Uri.parse('$baseUrl/products/by-group/$groupId'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['products']);
    }
    throw Exception("Failed to load variant group");
  }

  /// ---------------------------------------------------
  /// CREATE NORMAL PRODUCT (non-variant)
  /// multipart/form-data
  /// ---------------------------------------------------
  static Future<bool> createProduct({
    required String name,
    required String description,
    required double price,
    required double offerPrice,
    required int quantity,
    required int stock,
    required int categoryId,
    required int subcategoryId,
    required int brandId,
    List<File> images = const [],
    bool isSponsored = false,
    String? sku,
  }) async {
    final uri = Uri.parse('$baseUrl/products');
    final req = http.MultipartRequest("POST", uri);

    // fields
    req.fields["name"] = name;
    req.fields["description"] = description;
    req.fields["price"] = price.toString();
    req.fields["offerPrice"] = offerPrice.toString();
    req.fields["quantity"] = quantity.toString();
    req.fields["stock"] = stock.toString();
    req.fields["categoryId"] = categoryId.toString();
    req.fields["subcategoryId"] = subcategoryId.toString();
    req.fields["brandId"] = brandId.toString();
    req.fields["isSponsored"] = isSponsored ? "1" : "0";
    if (sku != null && sku.isNotEmpty) {
      req.fields["sku"] = sku;
    }

    // images
    for (final img in images) {
      req.files.add(
        await http.MultipartFile.fromPath("images", img.path),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    print("CREATE PRODUCT STATUS: ${res.statusCode}");
    print("BODY: ${res.body}");
    return res.statusCode == 201 || res.statusCode == 200;
  }

  /// ---------------------------------------------------
  /// CREATE / UPLOAD PRODUCT WITH VARIANTS (PARENT + CHILDREN)
  /// /products/with-variants
  /// ---------------------------------------------------
  static Future<Map<String, dynamic>> createProductWithVariants({
    required Map<String, dynamic> parentJson,
    required List<Map<String, dynamic>> variantsPayload,
    List<File>? parentImageFiles,
    List<Uint8List>? parentImageBytes,
    List<Map<String, dynamic>>? childVariants,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/products/with-variants');
      final req = http.MultipartRequest('POST', uri);

      // ------------------ PARENT JSON ------------------
      req.fields['parent'] = jsonEncode(parentJson);
      req.fields['variantsPayload'] = jsonEncode(variantsPayload);

      // ------------------ PARENT IMAGES ------------------
      parentImageFiles ??= [];
      for (final f in parentImageFiles) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'parentImages', // Backend accepts parentImages*
            f.path,
            filename: f.path.split('/').last,
          ),
        );
      }

      parentImageBytes ??= [];
      for (int i = 0; i < parentImageBytes.length; i++) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'parentImages', // Can appear as parentImages, parentImages[0], etc.
            parentImageBytes[i],
            filename: 'parent_$i.jpg',
          ),
        );
      }

      // ------------------ CHILD VARIANT IMAGES ------------------
      //
      // childVariants item example:
      // {
      //   "comboKey": "Red-M",      // MUST match what you use in variantsPayload.combinationKey / comboKey
      //   "useParentImages": false,
      //   "images": [ File or Uint8List, ... ]
      // }
      //
      childVariants ??= [];

      for (final combo in childVariants) {
        String comboKeyRaw =
            combo['comboKey'] ??
            combo['combinationKey'] ??
            combo['key'] ??
            combo['label'] ??
            "";

        if (comboKeyRaw.isEmpty) continue;
        if (combo['useParentImages'] == true) continue;

        final sanitized = sanitizeComboKey(comboKeyRaw);
        final fieldName = "images_$sanitized";

        final imgs = combo['images'] ?? [];

        for (int i = 0; i < imgs.length; i++) {
          final img = imgs[i];

          if (img is File) {
            req.files.add(
              await http.MultipartFile.fromPath(
                fieldName,
                img.path,
                filename: '${fieldName}_$i.jpg',
              ),
            );
          } else if (img is Uint8List) {
            req.files.add(
              http.MultipartFile.fromBytes(
                fieldName,
                img,
                filename: '${fieldName}_$i.jpg',
              ),
            );
          }
        }
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      print("🔵 createProductWithVariants STATUS: ${resp.statusCode}");
      print("BODY: ${resp.body}");

      return jsonDecode(resp.body);
    } catch (e, st) {
      print("❌ ERROR in createProductWithVariants: $e");
      print(st);
      return {"success": false, "error": e.toString()};
    }
  }

  /// Legacy alias, if you call this name anywhere else
  static Future<Map<String, dynamic>> uploadProductWithVariants({
    required Map<String, dynamic> parentJson,
    required List<Map<String, dynamic>> variantsPayload,
    List<File>? parentImageFiles,
    List<Uint8List>? parentImageBytes,
    List<Map<String, dynamic>>? childVariants,
  }) {
    return createProductWithVariants(
      parentJson: parentJson,
      variantsPayload: variantsPayload,
      parentImageFiles: parentImageFiles,
      parentImageBytes: parentImageBytes,
      childVariants: childVariants,
    );
  }

static Future<Map<String, dynamic>> updateProductWithVariants({
  required int productId,
  required Map<String, dynamic> parentJson,
  required List<Map<String, dynamic>> variantsPayload,
  List<File>? parentImageFiles,
  List<Uint8List>? parentImageBytes,
  required List<Map<String, dynamic>> childVariants, // comboKey + images
}) async {
  try {
    final uri = Uri.parse("$baseUrl/products/with-variants/$productId");
    final req = http.MultipartRequest("PUT", uri);

    req.fields["parent"] = jsonEncode(parentJson);
    req.fields["variantsPayload"] = jsonEncode(variantsPayload);

    // Parent images
    if (parentImageFiles != null) {
      for (final f in parentImageFiles) {
        req.files.add(await http.MultipartFile.fromPath(
          "parentImages",
          f.path,
        ));
      }
    }

    if (parentImageBytes != null) {
      for (final bytes in parentImageBytes) {
        req.files.add(
          http.MultipartFile.fromBytes(
            "parentImages",
            bytes,
            filename: "parent_${DateTime.now().millisecondsSinceEpoch}.png",
          ),
        );
      }
    }

    // Child images (variants)
    for (final combo in childVariants) {
      final comboKey = combo["comboKey"];
      final images = combo["images"] as List;

      for (final img in images) {
        if (img is File) {
          req.files.add(await http.MultipartFile.fromPath(
            "images_$comboKey",
            img.path,
          ));
        } else if (img is Uint8List) {
          req.files.add(
            http.MultipartFile.fromBytes(
              "images_$comboKey",
              img,
              filename: "variant_${comboKey}_${DateTime.now().microsecondsSinceEpoch}.png",
            ),
          );
        }
      }
    }

    final response = await req.send();
    final responseBytes = await response.stream.bytesToString();

    return jsonDecode(responseBytes);
  } catch (e) {
    debugPrint("updateProductWithVariants error: $e");
    return {"success": false, "error": e.toString()};
  }
}

  /// ---------------------------------------------------
  /// GET PRODUCT + VARIANTS (PARENT + CHILDREN)
  /// /products/:id/with-variants
  /// ---------------------------------------------------
  static Future<Map<String, dynamic>> getProductWithVariants(
      int productId) async {
    try {
      final uri = Uri.parse("$baseUrl/products/$productId/with-variants");
      final response = await http.get(uri);

      print("GET $uri -> ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        if (parsed is Map<String, dynamic>) {
          return parsed; // { parent: {...}, children: [...] }
        } else {
          return {"success": true, "data": parsed};
        }
      } else {
        throw Exception("Failed with status ${response.statusCode}");
      }
    } catch (e) {
      print("❌ getProductWithVariants ERROR: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  /// ---------------------------------------------------
  /// UPDATE PRODUCT (no images; simple JSON body)
  /// ---------------------------------------------------
  static Future<bool> updateProduct({
    required int id,
    required Map<String, dynamic> data,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    print("UPDATE PRODUCT $id -> ${res.statusCode}");
    return res.statusCode == 200;
  }

  /// ---------------------------------------------------
  /// DELETE PRODUCT (single)
  /// ---------------------------------------------------
  static Future<bool> deleteProduct(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/products/$id'));
    print("DELETE PRODUCT $id -> ${res.statusCode}");
    return res.statusCode == 200;
  }

  /// ---------------------------------------------------
  /// STOCK OPERATIONS (optional, if backend has routes)
  /// ---------------------------------------------------
  static Future<bool> reduceStock(int id, int qty) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/reduce-stock/$id/$qty'),
    );
    return res.statusCode == 200;
  }

  static Future<bool> increaseStock(int id, int qty) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/increase-stock/$id/$qty'),
    );
    return res.statusCode == 200;
  }
  /// 
  /// specificaion
  /// 
  /// 1) Get sections + fields template
  static Future<List<SpecSection>> getSpecSectionsWithFields() async {
    final uri = Uri.parse("$baseUrl/products/spec/sections-with-fields");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load spec sections');
    }

    final decoded = jsonDecode(res.body);

    // backend might send { sections: [...] } or just [...]
    final list = decoded is Map<String, dynamic> && decoded['sections'] != null
        ? decoded['sections'] as List
        : decoded as List;

    return list
        .map((e) => SpecSection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 2) Get existing values for a product
  static Future<Map<int, String>> getProductSpecs(int productId) async {
    final uri = Uri.parse("$baseUrl/products/spec/product/$productId");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load product specs');
    }

    final List<dynamic> decoded = jsonDecode(res.body);
    final Map<int, String> result = {};

    for (final row in decoded) {
      final map = row as Map<String, dynamic>;
      final fid = map['FieldID'] ?? map['fieldId'];
      if (fid == null) continue;
      final intFieldId = int.tryParse(fid.toString());
      if (intFieldId == null) continue;
      result[intFieldId] = (map['Value'] ?? '').toString();
    }

    return result;
  }

  /// 3) Save product specs
  static Future<bool> saveProductSpecs({
    required int productId,
    required List<Map<String, dynamic>> specs,
  }) async {
    final uri = Uri.parse("$baseUrl/products/spec/product/save");
    final body = jsonEncode({
      'productId': productId,
      'specs': specs,
    });

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode != 200) return false;

    final decoded = jsonDecode(res.body);
    return decoded['success'] == true;
  }

/// ================= SPECIFICATION BUILDER CRUD =================

/// 1) Create Section
static Future<bool> createSpecSection({
  required String name,
  int sortOrder = 0,
}) async {
  final uri = Uri.parse("$baseUrl/products/spec/section");
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name,
      'sortOrder': sortOrder,
    }),
  );
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

/// 2) Update Section
static Future<bool> updateSpecSection({
  required int sectionId,
  required String name,
  int sortOrder = 0,
}) async {
  final uri = Uri.parse("$baseUrl/products/spec/section/$sectionId");
  final res = await http.put(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name,
      'sortOrder': sortOrder,
    }),
  );
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

/// 3) Delete Section
static Future<bool> deleteSpecSection(int sectionId) async {
  final uri = Uri.parse("$baseUrl/products/spec/section/$sectionId");
  final res = await http.delete(uri);
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

/// 4) Create Field
static Future<bool> createSpecField({
  required int sectionId,
  required String name,
  String inputType = 'text',
  int sortOrder = 0,
}) async {
  final uri = Uri.parse("$baseUrl/products/spec/field");
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'sectionId': sectionId,
      'name': name,
      'inputType': inputType,
      'sortOrder': sortOrder,
    }),
  );
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

/// 5) Update Field
static Future<bool> updateSpecField({
  required int fieldId,
  required int sectionId,
  required String name,
  String inputType = 'text',
  int sortOrder = 0,
}) async {
  final uri = Uri.parse("$baseUrl/products/spec/field/$fieldId");
  final res = await http.put(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'sectionId': sectionId,
      'name': name,
      'inputType': inputType,
      'sortOrder': sortOrder,
    }),
  );
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

/// 6) Delete Field
static Future<bool> deleteSpecField(int fieldId) async {
  final uri = Uri.parse("$baseUrl/products/spec/field/$fieldId");
  final res = await http.delete(uri);
  if (res.statusCode != 200) return false;
  final decoded = jsonDecode(res.body);
  return decoded['success'] == true;
}

   /// 
   /// caegor
   /// ✅ Upload image to Supabase and return public URL
  static Future<String?> uploadCategoryImage(File imageFile) async {
    try {
      final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final supabase = Supabase.instance.client;

      await supabase.storage.from('categories').upload(fileName, imageFile);
      final publicUrl = supabase.storage.from('categories').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('❌ Image upload failed: $e');
      return null;
    }
  }

  /// ✅ Get categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;
    final res = await http.get(Uri.parse('$baseUrl/categories'));
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _cachedCategories = data.map((e) => Map<String, dynamic>.from(e)).toList();
      return _cachedCategories!;
    }
    throw Exception('Failed to load categories');
  }

  /// ✅ Add category with image URL
  static Future<bool> addCategory(String name, String? imageUrl) async {
    final res = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'imageUrl': imageUrl}),
    );
    _cachedCategories = null;
    return res.statusCode == 201;
  }

  /// ✅ Update category
  static Future<bool> updateCategory(int id, String name, String? imageUrl) async {
    final res = await http.put(
      Uri.parse('$baseUrl/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'imageUrl': imageUrl}),
    );
    _cachedCategories = null;
    return res.statusCode == 200;
  }

  static Future<bool> deleteCategory(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/categories/$id'));
    _cachedCategories = null;
    return res.statusCode == 200;
  }

  // /// ------------------- 📂 SUBCATEGORIES -------------------
  // static Future<List<Subcategory>> fetchSubcategories(int categoryId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/subcategories?categoryId=$categoryId'),
  //     );

  //     if (response.statusCode == 200) {
  //       final List data = json.decode(response.body);
  //       return data.map((e) => Subcategory.fromMap(e)).toList();
  //     } else {
  //       throw Exception('Failed to load subcategories: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('❌ Error fetching subcategories: $e');
  //     return [];
  //   }
  // }
  // =============================
// 🟣 GET SUBCATEGORIES BY CATEGORY ID
// =============================
static Future<List<Map<String, dynamic>>> getSubcategories(int categoryId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/subcategories?categoryId=$categoryId'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Failed to load subcategories: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching subcategories: $e');
    return [];
  }
}

  static Future<bool> addSubcategory(int categoryId, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subcategories'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'categoryId': categoryId, 'name': name}),
    );
    return res.statusCode == 201;
  }

  static Future<bool> updateSubcategory(int id, int categoryId, String name) async {
    final res = await http.put(
      Uri.parse('$baseUrl/subcategories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'categoryId': categoryId, 'name': name}),
    );
    return res.statusCode == 200;
  }

  static Future<bool> deleteSubcategory(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/subcategories/$id'));
    return res.statusCode == 200;
  }

 // =============== BRANDS ===============

static Future<List<Map<String, dynamic>>> getBrands() async {
  print("🔵 Fetching Brands from: $baseUrl/brands");

  final res = await http.get(Uri.parse('$baseUrl/brands'));
  print("🟢 Response Code: ${res.statusCode}");
  print("🟢 Raw Response: ${res.body}");

  if (res.statusCode == 200) {
    final List data = json.decode(res.body);
    print("🟡 Total Brands Received: ${data.length}");

    final mapped = data.map<Map<String, dynamic>>((e) {
      print("➡️ Mapping Brand Row: $e");
      return {
        'BrandID': e['BrandID'] ?? e['id'],
        'Name': e['Name'] ?? e['name'],
        'CategoryID': e['CategoryID'] ?? e['categoryId'],
        'CategoryName': e['CategoryName'] ?? e['categoryName'],
        'SubcategoryID': e['SubcategoryID'] ?? e['subcategoryId'],
        'SubcategoryName': e['SubcategoryName'] ?? e['subcategoryName'],
        'CreatedAt': e['CreatedAt']?.toString(),
      };
    }).toList();

    print("🟣 Final Mapped Brands: $mapped");
    return mapped;
  }

  throw Exception("Failed to load brands");
}

static Future<bool> addBrand({
  required String name,
  required int categoryId,
  required int subcategoryId,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/brands'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
    }),
  );
  return res.statusCode == 201;
}

static Future<bool> updateBrand({
  required int id,
  required String name,
  required int categoryId,
  required int subcategoryId,
}) async {
  final res = await http.put(
    Uri.parse('$baseUrl/brands/$id'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
    }),
  );
  return res.statusCode == 200;
}

static Future<bool> deleteBrand(int id) async {
  final res = await http.delete(Uri.parse('$baseUrl/brands/$id'));
  return res.statusCode == 200;
}

 /// ------------------- 📂  VARIANT TYPES-------------------
// For variant types
static const String variantTypesUrl = '$baseUrl/variantTypes';

// GET all variant types
static Future<List<Map<String, dynamic>>> getVariantTypes() async {
  final response = await http.get(Uri.parse(variantTypesUrl));
  if (response.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load variant types');
  }
}

// Add variant type
static Future<void> addVariantType(String variantName, String variantType) async {
  final response = await http.post(
    Uri.parse(variantTypesUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'variantName': variantName,
      'variantType': variantType,
    }),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to add variant type');
  }
}

// Edit variant type
static Future<void> editVariantType(int id, String variantName, String variantType) async {
  final response = await http.put(
    Uri.parse('$variantTypesUrl/$id'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'variantName': variantName,
      'variantType': variantType,
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to edit variant type');
  }
}

// Delete variant type
static Future<void> deleteVariantType(int id) async {
  final response = await http.delete(Uri.parse('$variantTypesUrl/$id'));
  if (response.statusCode != 200) {
    throw Exception('Failed to delete variant type');
  }
}

 /// ------------------- 📂 variants-------------------

static Future<List<Map<String, dynamic>>> getVariants() async {
  final url = "$baseUrl/variants";
  print("🔗 Calling GET: $url");

  final response = await http.get(Uri.parse(url));

  print("🔵 Response Code: ${response.statusCode}");
  print("🔵 Raw Body: ${response.body}");

  if (response.statusCode == 200) {
    final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    print("🟩 Parsed Variants Count: ${list.length}");
    print("🟩 First Variant: ${list.isNotEmpty ? list[0] : 'NONE'}");
    return list;
  } else {
    print("❌ ERROR loading variants");
    throw Exception("Failed to load variants");
  }
}

static Future<List<Map<String, dynamic>>> getVariantValuesByType(int typeId) async {
  print("🔗 Calling GET: $baseUrl/variants/by-type/$typeId");

  final response = await http.get(Uri.parse('$baseUrl/variants/by-type/$typeId'));

  print("🔵 Response Code: ${response.statusCode}");
  print("🔵 Raw Body: ${response.body}");

  if (response.statusCode == 200) {
    final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));

    print("🟩 Loaded ${list.length} values for typeId: $typeId");
    print("🟩 Values: $list");

    return list;
  } else {
    print("❌ Failed to load values for typeId: $typeId");
    throw Exception('Failed to load variant values');
  }
}


  // ADD variant
static Future<void> addVariant(String variantName, int variantTypeId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/variants'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'Variant': variantName,
      'VariantTypeID': variantTypeId, // ✅ send ID not name
    }),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to add variant');
  }
}

  // EDIT variant
 static Future<void> editVariant(int id, String variantName, int variantTypeId) async {
  final response = await http.put(
    Uri.parse('$baseUrl/variants/$id'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'Variant': variantName,
      'VariantTypeID': variantTypeId, // ✅ send ID
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to edit variant');
  }
}

  // DELETE variant
  static Future<void> deleteVariant(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/variants/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete variant');
    }
  }
  /// ------------------- 📦 CREATE PRODUCT WITH VARIANTS -------------------
// static Future<Map<String, dynamic>> createProductWithVariants({
//   required Map<String, dynamic> parentJson,
//   required List<Map<String, dynamic>> variantsPayload,
//   List<File>? parentImageFiles,
//   List<Uint8List>? parentImageBytes,
//   List<Map<String, dynamic>>? childVariants,
// }) async {
//   try {
//     final uri = Uri.parse('$baseUrl/products/with-variants');
//     final req = http.MultipartRequest('POST', uri);

//     /// ---------------- PARENT JSON ----------------
//     req.fields['parent'] = jsonEncode(parentJson);
//     req.fields['variantsPayload'] = jsonEncode(variantsPayload);

//     /// ---------------- PARENT IMAGES ----------------
//     parentImageFiles ??= [];
//     for (var f in parentImageFiles) {
//       req.files.add(await http.MultipartFile.fromPath(
//         'parentImages',
//         f.path,
//         filename: path.basename(f.path),
//       ));
//     }

//     parentImageBytes ??= [];
//     for (int i = 0; i < parentImageBytes.length; i++) {
//       req.files.add(http.MultipartFile.fromBytes(
//         'parentImages',
//         parentImageBytes[i],
//         filename: 'parent_$i.jpg',
//       ));
//     }

//     /// ---------------- CHILD / VARIANT IMAGES ----------------
//     childVariants ??= [];

//     for (final combo in childVariants) {
//       String comboKeyRaw =
//           combo['comboKey'] ??
//           combo['combinationKey'] ??
//           combo['key'] ??
//           combo['label'] ??
//           "";

//       if (comboKeyRaw.isEmpty) continue;
//       if (combo['useParentImages'] == true) continue;

//       // SAME SANITIZE RULE AS BACKEND
//       String sanitized = comboKeyRaw
//           .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_')
//           .replaceAll(RegExp(r'_+'), '_')
//           .replaceAll(RegExp(r'^_+|_+$'), '');

//       final fieldName = "images_$sanitized";

//       final imgs = combo["images"] ?? [];

//       for (int i = 0; i < imgs.length; i++) {
//         final img = imgs[i];

//         if (img is File) {
//           req.files.add(await http.MultipartFile.fromPath(
//             fieldName,
//             img.path,
//             filename: "${fieldName}_$i.jpg",
//           ));
//         } else if (img is Uint8List) {
//           req.files.add(http.MultipartFile.fromBytes(
//             fieldName,
//             img,
//             filename: "${fieldName}_$i.jpg",
//           ));
//         }
//       }
//     }

//     /// ---------------- SEND REQUEST ----------------
//     final streamed = await req.send();
//     final resp = await http.Response.fromStream(streamed);

//     print("🔵 Upload result: ${resp.statusCode}");
//     print("📦 Body: ${resp.body}");

//     return jsonDecode(resp.body);

//   } catch (e, st) {
//     print("❌ createProductWithVariants ERROR: $e\n$st");
//     return {"success": false, "error": e.toString()};
//   }
// }

/// ------------------- 📂 COUPONS -------------------
  static Future<List<Map<String, dynamic>>> getCoupons() async {
    final res = await http.get(Uri.parse('$baseUrl/coupons'));
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception('Failed to load coupons');
  }
static Future<bool> updateCoupon({
  required int id,
  required String code,
  required String discountType,
  required double discountAmount,
  required double minimumPurchase,
  required String startDate,
  required String endDate,
  required String status,
  required int? categoryId,
  required int? subcategoryId,
  required int? productId,
}) async {
  try {
    final response = await http.put(
      Uri.parse("$baseUrl/coupons/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "Code": code,
        "DiscountType": discountType,
        "DiscountAmount": discountAmount,
        "MinimumPurchase": minimumPurchase,
        "StartDate": startDate,
        "EndDate": endDate,
        "Status": status,
        "CategoryID": categoryId,
        "SubcategoryID": subcategoryId,
        "ProductID": productId,   // FIXED ✔
      }),
    );

    return response.statusCode == 200;
  } catch (e) {
    print("❌ updateCoupon error: $e");
    return false;
  }
}

static Future<bool> addCoupon({
  required String code,
  required String discountType,
  required double discountAmount,
  required double minimumPurchase,
  required String startDate,
  required String endDate,
  required String status,
  int? categoryId,
  int? subcategoryId,
  int? productId,
}) async {
  final body = {
    "code": code,
    "discountType": discountType,
    "discountAmount": discountAmount,
    "minimumPurchase": minimumPurchase,
    "startDate": startDate,
    "endDate": endDate,
    "status": status,
    "categoryId": categoryId,
    "subcategoryId": subcategoryId,
    "productId": productId,
  };

  final res = await http.post(
    Uri.parse("$baseUrl/coupons"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(body),
  );

  return res.statusCode == 201;
}


  static Future<bool> deleteCoupon(int couponId) async {
    final res = await http.delete(Uri.parse('$baseUrl/coupons/$couponId'));
    return res.statusCode == 200;
  }  
// ------------------- 🖼️ POSTERS -------------------
/// ------------------- 🖼️ POSTERS -------------------
/// ------------------- 🖼️ POSTERS -------------------

static Future<List<Map<String, dynamic>>> getPosters() async {
  final res = await http.get(Uri.parse('$baseUrl/posters'));
  if (res.statusCode == 200) {
    final List data = json.decode(res.body);
    return data
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  throw Exception('Failed to load posters');
}

/// ✅ Upload poster image to Supabase and return public URL
static Future<String> uploadPosterImage(File imageFile) async {
  final supabase = Supabase.instance.client;
  final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.png';
  final filePath = 'posters/$fileName';

  await supabase.storage.from('posters').upload(filePath, imageFile);
  final imageUrl = supabase.storage.from('posters').getPublicUrl(filePath);
  return imageUrl;
}

/// ✅ Add new poster
static Future<bool> addPoster({
  required String title,
  required String imageUrl,
}) async {
  final body = jsonEncode({
    'title': title,
    'imageUrls': [imageUrl], // ✅ backend expects "imageUrls"
  });

  final res = await http.post(
    Uri.parse('$baseUrl/posters'),
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  debugPrint('Add poster response: ${res.body}');
  return res.statusCode == 201 || res.statusCode == 200;
}


/// ✅ Update poster (title + optional new image)
static Future<bool> updatePoster({
  required int id,
  required String title,
  required List<String> imageUrls,
  File? imageFile,
}) async {
  String? uploadedImageUrl;

  // If a new image file is provided, upload it first
  if (imageFile != null) {
    uploadedImageUrl = await uploadPosterImage(imageFile);
  }

  // Build JSON payload
  final body = jsonEncode({
    'title': title,
    // If new uploaded image, replace list; else use existing
    'imageUrls': uploadedImageUrl != null ? [uploadedImageUrl] : imageUrls,
  });

  final res = await http.put(
    Uri.parse('$baseUrl/posters/$id'),
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  debugPrint('Update poster response: ${res.body}');
  return res.statusCode == 200;
}

/// ✅ Delete poster
static Future<bool> deletePoster(int id) async {
  final res = await http.delete(Uri.parse('$baseUrl/posters/$id'));
  return res.statusCode == 200;
}



// ------------------- 🔔 NOTIFICATIONS -------------------
  // 🔹 Get notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await http.get(Uri.parse('$baseUrl/notifications'));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load notifications");
    }
  }

 static Future<bool> addNotification(String title, String message, String? imageUrl) async {
  try {
    final url = Uri.parse('$baseUrl/notifications');

    final Map<String, dynamic> body = {
      'title': title,
      'message': message,
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['imageUrl'] = imageUrl;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      print("✅ Notification added successfully");
      return true;
    } else {
      print("❌ Failed to add notification: ${response.body}");
      return false;
    }
  } catch (e) {
    print("⚠️ Error adding notification: $e");
    return false;
  }
}

  // 🔹 Delete / deactivate notification
  static Future<bool> deleteNotification(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/notifications/$id'));
    print("Delete Notification → ${response.statusCode}: ${response.body}");
    return response.statusCode == 200;
  }
}

