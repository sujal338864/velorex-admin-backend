import 'dart:io';
import 'dart:typed_data';

class VariantCombo {
  // map VariantPesName -> VariantValue
  Map<String, String> selections;
  double price;
  double offerPrice;
  int stock;
  String sku;
  String description;
  Uint8List? imageBytes;        // single image bytes
  File? imageFile;              // single image file
  List<dynamic>? extraImages;   // multiple images (File or Uint8List)
  String? imageUrl;
  bool useParentImages;
 // from server when editing
  String? videoUrl; // 🔴 NEW: per-variant YouTube URL

  VariantCombo({
    required this.selections,
    this.price = 0,
    this.offerPrice = 0,
    this.stock = 0,
    String? sku,
    this.description = '',
    this.imageBytes,
    this.imageFile,
    this.videoUrl,
    this.extraImages,
    this.imageUrl,
    this.useParentImages = true,
  }) : sku = sku ?? _generateSKUFromSelections(selections);

  // --------------------------- SKU generator ---------------------------
  static String _generateSKUFromSelections(Map<String, String> sel) {
    if (sel.isEmpty) return 'SKU-${DateTime.now().millisecondsSinceEpoch % 10000}';

    final sorted = sel.values.toList();
    final s = sorted.map((v) {
      final cleaned = v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      return cleaned.isEmpty
          ? 'X'
          : (cleaned.length <= 3 ? cleaned.toUpperCase() : cleaned.substring(0, 3).toUpperCase());
    }).join('-');

    return '$s-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  // --------------------------- EXACT BACKEND MATCH ---------------------------
  // Sanitize + SORT KEYS → identical comboKey as backend needs
  String comboKey() {
    // Sorting keys ensures deterministic order:
    final keys = selections.keys.toList()..sort();
    final raw = keys.map((k) => '$k:${selections[k]}').join('|');

    // EXACT backend logic:
    String step1 = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '_');
    String step2 = step1.replaceAll(RegExp(r'_+'), '_');
    String step3 = step2.replaceAll(RegExp(r'^_+|_+$'), '');

    return step3;
  }

  // --------------------------- Map sent to API ---------------------------
  Map<String, dynamic> toUploadMap() {
    final imgs = <dynamic>[];

    if (imageFile != null) imgs.add(imageFile!);
    if (imageBytes != null) imgs.add(imageBytes!);

    if (extraImages != null) {
      for (var img in extraImages!) {
        if (img is File || img is Uint8List) {
          imgs.add(img);
        }
      }
    }

    return {
      'comboKey': comboKey(),       // EXACT field your backend uses
      'images': imgs,               // List<File or Uint8List>
      'useParentImages': useParentImages,
      'price': price,
      'offerPrice': offerPrice,
      'stock': stock,
      'sku': sku,
      'description': description,
    };
  }

  // --------------------------- Add an image ---------------------------
  void addImage(dynamic img) {
    if (img is File) {
      if (imageFile == null) {
        imageFile = img;
      } else {
        extraImages ??= [];
        extraImages!.add(img);
      }
    } else if (img is Uint8List) {
      if (imageBytes == null) {
        imageBytes = img;
      } else {
        extraImages ??= [];
        extraImages!.add(img);
      }
    } else {
      throw ArgumentError('Unsupported image type: ${img.runtimeType}');
    }
  }
}
