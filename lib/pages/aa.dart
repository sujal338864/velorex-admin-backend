// // // add_edit_product_page.dart
// // import 'dart:convert';
// // import 'dart:io';
// // import 'dart:typed_data';
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import '../services/api_service.dart';
// // import 'package:supabase_flutter/supabase_flutter.dart';
// // import 'package:image/image.dart' as img;
// // import 'package:flutter_image_compress/flutter_image_compress.dart';
// // import 'package:path/path.dart' as path;

// // /// ---------------------- Models ----------------------
// // class VariantCombo {
// //   Map<String, String> selections;
// //   double price;
// //   double offerPrice;
// //   int stock;
// //   String sku;
// //   String description;
// //   Uint8List? imageBytes;
// //   File? imageFile;
// //   String? imageUrl;
// //   bool useParentImages;

// //   VariantCombo({
// //     required this.selections,
// //     this.price = 0,
// //     this.offerPrice = 0,
// //     this.stock = 0,
// //     String? sku,
// //     this.description = '',
// //     this.imageBytes,
// //     this.imageFile,
// //     this.imageUrl,
// //     this.useParentImages = true,
// //   }) : sku = sku ?? _generateSKUFromSelections(selections);

// //   static String _generateSKUFromSelections(Map<String, String> sel) {
// //     final s = sel.values.map((v) {
// //       final cleaned = v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
// //       return cleaned.length <= 3 ? cleaned.toUpperCase() : cleaned.substring(0, 3).toUpperCase();
// //     }).join('-');
// //     return '${s}-${DateTime.now().millisecondsSinceEpoch % 10000}';
// //   }

// //   String combinationKey() {
// //     final key = selections.entries.map((e) => '${e.key}:${e.value}').join('|');
// //     return key.replaceAll(RegExp(r'[:|\/\\\s]+'), '_');
// //   }
// // }

// // /// ---------------------- Page ----------------------
// // class AddEditProductPage extends StatefulWidget {
// //   final int? productId;
// //   const AddEditProductPage({Key? key, this.productId}) : super(key: key);

// //   @override
// //   State<AddEditProductPage> createState() => _AddEditProductPageState();
// // }

// // class _AddEditProductPageState extends State<AddEditProductPage> {
// //   final _formKey = GlobalKey<FormState>();

// //   // product fields
// //   final nameController = TextEditingController();
// //   final descriptionController = TextEditingController();
// //   final priceController = TextEditingController();
// //   final offerPriceController = TextEditingController();
// //   final quantityController = TextEditingController();

// //   String name = '';
// //   String description = '';
// //   double price = 0.0;
// //   double offerPrice = 0.0;
// //   int stock = 0;
// //   int quantity = 1;

// //   int? selectedCategoryId;
// //   int? selectedSubcategoryId;
// //   int? selectedBrandId;

// //   // images
// //   List<File> imageFiles = [];
// //   List<Uint8List> imageBytes = [];

// //   bool isSaving = false;
// //   bool isLoading = false;

// //   // lists from API
// //   List<Map<String, dynamic>> categories = [];
// //   List<Map<String, dynamic>> filteredSubcategories = [];
// //   List<Map<String, dynamic>> brands = [];

// //   // variant types & all variant values (flat)
// //   List<Map<String, dynamic>> variantTypes = []; // { VariantTypeID, VariantName }
// //   List<Map<String, dynamic>> allVariants = []; // { VariantID, Variant, VariantTypeID, VariantType }

// //   // selected types & their selected values (Option 2)
// //   // selectedVariantPes -> [{ typeId: 1, name: 'Color', values: ['Red','Blue'] }, ...]
// //   List<Map<String, dynamic>> selectedVariantPes = [];

// //   // map typeId -> loaded values (normalized [{id, value}])
// //   Map<int, List<Map<String, dynamic>>> variantValuesByType = {};

// //   // generated combos
// //   List<VariantCombo> combos = [];

// //   @override
// //   void initState() {
// //     super.initState();
// //     loadData();
// //     if (widget.productId != null) {
// //       loadExistingProduct(widget.productId!);
// //     }
// //   }

// //   // ----------------- helpers -----------------
// //   int? _toIntSafe(dynamic v) {
// //     if (v == null) return null;
// //     if (v is int) return v;
// //     if (v is double) return v.toInt();
// //     try {
// //       return int.parse(v.toString());
// //     } catch (_) {
// //       return null;
// //     }
// //   }

// //   // Load initial lists: categories, brands, variantTypes, allVariants
// //   Future<void> loadData() async {
// //     try {
// //       final cats = await ApiService.getCategories();
// //       final brs = await ApiService.getBrands();
// //       final vTypes = await ApiService.getVariantTypes();
// //       final vars = await ApiService.getVariants();

// //       // Normalize variantTypes -> { id, name } (support several key shapes)
// //       final normalizedTypes = <Map<String, dynamic>>[];
// //       if (vTypes is List) {
// //         for (final t in vTypes) {
// //           if (t is Map) {
// //             final id = _toIntSafe(t['VariantTypeID'] ?? t['VariantTypeId'] ?? t['id']);
// //             final name = (t['VariantType'] ?? t['VariantName'] ?? t['variantName'] ?? t['name'])?.toString() ?? 'Variant';
// //             normalizedTypes.add({'id': id ?? name.hashCode, 'name': name, 'raw': t});
// //           }
// //         }
// //       }

// //       // Normalize allVariants to safe map list
// //       final normalizedVars = <Map<String, dynamic>>[];
// //       if (vars is List) {
// //         for (final v in vars) {
// //           if (v is Map) {
// //             normalizedVars.add({
// //               'id': _toIntSafe(v['VariantID'] ?? v['id']) ?? v.hashCode,
// //               'value': (v['Variant'] ?? v['ValueName'] ?? v['VariantName'] ?? v['variant'])?.toString() ?? '',
// //               'typeId': _toIntSafe(v['VariantTypeID'] ?? v['variantTypeId'] ?? v['VariantTypeId']),
// //               'typeName': (v['VariantType'] ?? v['VariantTypeName'] ?? v['variantType'])?.toString() ?? '',
// //               'raw': v,
// //             });
// //           } else {
// //             normalizedVars.add({'id': v.hashCode, 'value': v.toString(), 'typeId': null, 'typeName': '', 'raw': v});
// //           }
// //         }
// //       }

// //       setState(() {
// //         categories = List<Map<String, dynamic>>.from(cats ?? []);
// //         brands = List<Map<String, dynamic>>.from(brs ?? []);
// //         variantTypes = normalizedTypes;
// //         allVariants = normalizedVars;
// //         if (categories.isNotEmpty) selectedCategoryId = categories.first['CategoryID'];
// //       });

// //       if (selectedCategoryId != null) {
// //         final subs = await ApiService.getSubcategories(selectedCategoryId!);
// //         setState(() => filteredSubcategories = List<Map<String, dynamic>>.from(subs ?? []));
// //       }
// //     } catch (e) {
// //       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
// //     }
// //   }

// //   // ----------------- load existing product (edit) -----------------
// //   Future<void> loadExistingProduct(int id) async {
// //     setState(() => isLoading = true);
// //     try {
// //       final resp = await ApiService.getProductWithVariants(id);
// //       if (resp == null) throw Exception('Empty response');

// //       final parent = (resp['parent'] as Map<String, dynamic>?) ?? {};
// //       final children = (resp['children'] as List<dynamic>?) ?? [];

// //       // parent fields
// //       nameController.text = (parent['Name'] ?? parent['name'] ?? '').toString();
// //       descriptionController.text = (parent['Description'] ?? parent['description'] ?? '').toString();
// //       priceController.text = (parent['Price']?.toString() ?? '0');
// //       offerPriceController.text = (parent['OfferPrice']?.toString() ?? '0');
// //       quantityController.text = (parent['Quantity']?.toString() ?? '1');
// //       selectedCategoryId = parent['CategoryID'] ?? parent['categoryId'];
// //       selectedSubcategoryId = parent['SubcategoryID'] ?? parent['subcategoryId'];
// //       selectedBrandId = parent['BrandID'] ?? parent['brandId'];
// //       stock = parent['Stock'] ?? 0;

// //       // build selectedVariantPes from children (best effort)
// //       final Map<String, Set<String>> typeToVals = {};
// //       combos.clear();

// //       for (final ch in children) {
// //         if (ch is! Map) continue;
// //         // variantSelections may contain numeric ids; prefer names if available
// //         final sels = (ch['variantSelections'] as List<dynamic>?) ?? [];
// //         if (sels.isNotEmpty) {
// //           for (final s in sels) {
// //             if (s is! Map) continue;
// //             final typeName = (s['VariantTypeName'] ?? s['VariantType'] ?? s['variantType'] ?? '').toString();
// //             final valName = (s['VariantName'] ?? s['VariantValue'] ?? s['Variant'] ?? s['variant'] ?? '').toString();
// //             if (typeName.isEmpty || valName.isEmpty) continue;
// //             typeToVals.putIfAbsent(typeName, () => <String>{});
// //             typeToVals[typeName]!.add(valName);
// //           }
// //         } else {
// //           // fallback parse child name "Parent (Red, 64GB)"
// //           final childName = (ch['Name'] ?? ch['name'] ?? '').toString();
// //           final m = RegExp(r'\((.*)\)').firstMatch(childName);
// //           if (m != null) {
// //             final vals = m.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
// //             for (final v in vals) {
// //               typeToVals.putIfAbsent('Variant', () => <String>{});
// //               typeToVals['Variant']!.add(v);
// //             }
// //           }
// //         }

// //         // construct combo selections map from selections or name
// //         final comboSel = <String, String>{};
// //         if (sels.isNotEmpty) {
// //           for (final s in sels) {
// //             if (s is Map) {
// //               final tName = (s['VariantTypeName'] ?? s['VariantType'] ?? s['variantType'] ?? '').toString();
// //               final vName = (s['VariantName'] ?? s['VariantValue'] ?? s['Variant'] ?? s['variant'] ?? '').toString();
// //               if (tName.isNotEmpty && vName.isNotEmpty) comboSel[tName] = vName;
// //             }
// //           }
// //         } else {
// //           final childName = (ch['Name'] ?? ch['name'] ?? '').toString();
// //           final m = RegExp(r'\((.*)\)').firstMatch(childName);
// //           if (m != null) {
// //             final vals = m.group(1)!.split(',').map((s) => s.trim()).toList();
// //             for (var i = 0; i < vals.length; i++) {
// //               comboSel['Variant${i + 1}'] = vals[i];
// //             }
// //           } else {
// //             comboSel['Variant'] = (ch['SKU'] ?? ch['sku'] ?? 'V').toString();
// //           }
// //         }

// //         combos.add(VariantCombo(
// //           selections: comboSel,
// //           price: (ch['Price'] != null) ? double.tryParse(ch['Price'].toString()) ?? 0 : 0,
// //           offerPrice: (ch['OfferPrice'] != null) ? double.tryParse(ch['OfferPrice'].toString()) ?? 0 : 0,
// //           stock: ch['Stock'] ?? 0,
// //           sku: ch['SKU']?.toString() ?? ch['sku']?.toString(),
// //           description: ch['Description']?.toString() ?? ch['description']?.toString() ?? '',
// //           imageUrl: null,
// //         ));
// //       }

// //       selectedVariantPes = typeToVals.entries.map((e) {
// //         return {'typeId': null, 'name': e.key, 'values': e.value.toList()};
// //       }).toList();

// //       setState(() {});
// //     } catch (e) {
// //       debugPrint('loadExistingProduct error: $e');
// //     } finally {
// //       setState(() => isLoading = false);
// //     }
// //   }

// //   // ----------------- IMAGE PICK / COMPRESS -----------------
// //   Future<void> pickParentImage() async {
// //     final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
// //     if (picked == null) return;

// //     try {
// //       if (kIsWeb) {
// //         final bytes = await picked.readAsBytes();
// //         final decoded = img.decodeImage(bytes);
// //         if (decoded != null) {
// //           final resized = img.copyResize(decoded, width: 800);
// //           final compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
// //           setState(() => imageBytes.add(compressedBytes));
// //         } else {
// //           setState(() => imageBytes.add(bytes));
// //         }
// //       } else {
// //         final compressedBytes = await FlutterImageCompress.compressWithFile(picked.path, quality: 75, minWidth: 800);
// //         if (compressedBytes != null) {
// //           final compressedFile = File('${picked.path}_compressed.jpg')..writeAsBytesSync(compressedBytes);
// //           setState(() => imageFiles.add(compressedFile));
// //         } else {
// //           setState(() => imageFiles.add(File(picked.path)));
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint('Parent image pick error: $e');
// //       if (kIsWeb) {
// //         final bytes = await picked.readAsBytes();
// //         setState(() => imageBytes.add(bytes));
// //       } else {
// //         setState(() => imageFiles.add(File(picked.path)));
// //       }
// //     }
// //   }

// //   Future<void> pickComboImage(VariantCombo combo) async {
// //     final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
// //     if (picked == null) return;

// //     try {
// //       if (kIsWeb) {
// //         final bytes = await picked.readAsBytes();
// //         final decoded = img.decodeImage(bytes);
// //         if (decoded != null) {
// //           final resized = img.copyResize(decoded, width: 800);
// //           combo.imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
// //         } else {
// //           combo.imageBytes = await picked.readAsBytes();
// //         }
// //         combo.imageFile = null;
// //       } else {
// //         final compressedBytes = await FlutterImageCompress.compressWithFile(picked.path, quality: 75, minWidth: 800);
// //         if (compressedBytes != null) {
// //           final f = File('${picked.path}_compressed.jpg')..writeAsBytesSync(compressedBytes);
// //           combo.imageFile = f;
// //           combo.imageBytes = null;
// //         } else {
// //           combo.imageFile = File(picked.path);
// //           combo.imageBytes = null;
// //         }
// //       }
// //       setState(() {});
// //     } catch (e) {
// //       debugPrint('Combo image pick error: $e');
// //       if (kIsWeb) {
// //         combo.imageBytes = await picked.readAsBytes();
// //         combo.imageFile = null;
// //       } else {
// //         combo.imageFile = File(picked.path);
// //         combo.imageBytes = null;
// //       }
// //       setState(() {});
// //     }
// //   }

// //   // ----------------- VARIANT VALUES FETCHING -----------------
// //   // Option 2: we already fetched allVariants; here we filter them by typeId.
// // /// ---------------------- VARIANT VALUES (variens) ----------------------
// // /// ---------------------- VARIANT VALUES (variens) WITH DEBUG ----------------------
// // Future<void> fetchValuesForType(int typeId) async {
// //   debugPrint("🔵 fetchValuesForType CALLED for typeId = $typeId");

// //   try {
// //     // Load ALL variants (both types + values)
// //     debugPrint("📡 Calling ApiService.getVariants() ...");
// //    final all = await ApiService.getVariantValuesByType(typeId);


// //     debugPrint("📥 FULL variants response (${all.length} items):");
// //     for (var v in all) {
// //       debugPrint("   ➡ ${v.toString()}");
// //     }

// //     // Filter only values matching this typeId (VariantTypeID)
// //     final filtered = all.where((v) {
// //       final vtId = int.tryParse(v['VariantTypeID'].toString()) ?? 0;
// //       return vtId == typeId;
// //     }).toList();

// //     debugPrint("🔍 Filtered variens for typeId=$typeId → ${filtered.length} items");

// //     // Normalize
// //     final normalized = filtered.map((item) {
// //       final id = item['VariantID'];
// //       final rawVal = item['Variant'];

// //       debugPrint("   🔧 Normalizing: id=$id  |  value=$rawVal");

// //       return {
// //         'id': id,
// //         'value': rawVal?.toString() ?? '',
// //       };
// //     }).toList();

// //     debugPrint("✅ Final normalized variens list (${normalized.length} items):");
// //     for (var n in normalized) {
// //       debugPrint("   ✔ $n");
// //     }

// //     // Save to map
// //     setState(() {
// //       variantValuesByType[typeId] = normalized;
// //     });

// //     debugPrint("💾 Saved to variantValuesByType[$typeId]");
// //   } catch (e, st) {
// //     debugPrint("❌ ERROR loading variens for typeId $typeId");
// //     debugPrint("❌ Error: $e");
// //     debugPrint("❌ Stacktrace: $st");

// //     setState(() => variantValuesByType[typeId] = []);
// //   }
// // }

// // void loadVariantTypes() async {
// //   print("🟦 Loading Variant TYPES...");

// //   try {
// //     variantTypes = await ApiService.getVariantTypes();
// //     print("🟩 Loaded ${variantTypes.length} variant types");
// //   } catch (e) {
// //     print("❌ ERROR loading variant types: $e");
// //   }

// //   setState(() {});
// // }

// //   // ----------------- UI: Select Variant Types (multi-select) -----------------
// //   Future<void> openVariantTypeSelector() async {
// //     final currentSet = selectedVariantPes.map((p) => p['name'].toString()).toSet();
// //     final selectedMap = <int, bool>{};
// //     for (final vt in variantTypes) {
// //       selectedMap[vt['id'] as int] = currentSet.contains(vt['name']);
// //     }

// //     await showDialog(
// //       context: context,
// //       builder: (_) {
// //         return AlertDialog(
// //           title: const Text('Select Variant Types'),
// //           content: SizedBox(
// //             width: double.maxFinite,
// //             child: ListView(
// //               shrinkWrap: true,
// //               children: variantTypes.map((vt) {
// //                 final id = vt['id'] as int;
// //                 final name = vt['name']?.toString() ?? 'Variant';
// //                 return CheckboxListTile(
// //                   title: Text(name),
// //                   value: selectedMap[id] ?? false,
// //                   onChanged: (v) => setState(() => selectedMap[id] = v ?? false),
// //                 );
// //               }).toList(),
// //             ),
// //           ),
// //           actions: [
// //             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
// //             ElevatedButton(
// //               onPressed: () {
// //                 // apply selection
// //                 final newlySelected = <Map<String, dynamic>>[];
// //                 for (final vt in variantTypes) {
// //                   final id = vt['id'] as int;
// //                   final name = vt['name']?.toString() ?? 'Variant';
// //                   if (selectedMap[id] == true) {
// //                     // find existing entry to preserve values
// //                     final existing = selectedVariantPes.firstWhere(
// //                       (e) => e['name'] == name || _toIntSafe(e['typeId']) == id,
// //                       orElse: () => {},
// //                     );
// //                     if (existing.isNotEmpty) {
// //                       newlySelected.add({'typeId': id, 'name': name, 'values': List<String>.from(existing['values'] ?? [])});
// //                     } else {
// //                       newlySelected.add({'typeId': id, 'name': name, 'values': <String>[]});
// //                     }
// //                   }
// //                 }

// //                 setState(() => selectedVariantPes = newlySelected);
// //                 Navigator.pop(context);
// //               },
// //               child: const Text('OK'),
// //             )
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   // ----------------- UI: Select values for a type (multi-select) -----------------
// //   Future<void> openValuesSelector(int pesIndex) async {
// //     final pes = selectedVariantPes[pesIndex];
// //     final typeId = _toIntSafe(pes['typeId']) ?? -1;
// //     if (typeId == -1) return;

// //     // ensure values loaded
// //     await fetchValuesForType(typeId);
// //     final list = variantValuesByType[typeId] ?? [];

// //     final selectedValuesSet = <String>{};
// //     final existing = pes['values'] ?? [];
// //     for (final e in existing) {
// //       selectedValuesSet.add(e.toString());
// //     }

// //     final tempMap = <String, bool>{};
// //     for (final v in list) {
// //       final val = v['value'].toString();
// //       tempMap[val] = selectedValuesSet.contains(val);
// //     }

// //     await showDialog(
// //       context: context,
// //       builder: (_) {
// //         return AlertDialog(
// //           title: Text('Select values for ${pes['name']}'),
// //           content: SizedBox(
// //             width: double.maxFinite,
// //             child: ListView(
// //               shrinkWrap: true,
// //               children: list.map((v) {
// //                 final val = v['value'].toString();
// //                 return CheckboxListTile(
// //                   title: Text(val),
// //                   value: tempMap[val] ?? false,
// //                   onChanged: (ch) => setState(() => tempMap[val] = ch ?? false),
// //                 );
// //               }).toList(),
// //             ),
// //           ),
// //           actions: [
// //             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
// //             ElevatedButton(
// //               onPressed: () {
// //                 final chosen = tempMap.entries.where((e) => e.value).map((e) => e.key).toList();
// //                 setState(() => selectedVariantPes[pesIndex]['values'] = chosen);
// //                 Navigator.pop(context);
// //               },
// //               child: const Text('OK'),
// //             )
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   // ----------------- Combination generator (cartesian) -----------------
// //   void generateCombinations() {
// //     combos.clear();
// //     if (selectedVariantPes.isEmpty) {
// //       setState(() {});
// //       return;
// //     }

// //     final lists = <List<String>>[];
// //     for (final p in selectedVariantPes) {
// //       final raw = p['values'] ?? [];
// //       final vals = <String>[];
// //       if (raw is List) {
// //         for (final v in raw) {
// //           vals.add(v?.toString() ?? '');
// //         }
// //       }
// //       lists.add(vals.isEmpty ? [''] : vals);
// //     }

// //     final prod = _cartesian(lists);
// //     for (final p in prod) {
// //       final sel = <String, String>{};
// //       for (var i = 0; i < p.length; i++) {
// //         final key = selectedVariantPes[i]['name']?.toString() ?? 'Variant${i + 1}';
// //         sel[key] = p[i] ?? '';
// //       }
// //       combos.add(VariantCombo(selections: sel));
// //     }
// //     setState(() {});
// //   }

// //   List<List<T>> _cartesian<T>(List<List<T>> lists) {
// //     List<List<T>> result = [[]];
// //     for (var list in lists) {
// //       List<List<T>> temp = [];
// //       for (var r in result) {
// //         for (var item in list) {
// //           temp.add([...r, item]);
// //         }
// //       }
// //       result = temp;
// //     }
// //     return result;
// //   }

// //   // ----------------- Save product (same shape as earlier) -----------------
// //   Future<void> saveProduct() async {
// //     if (!_formKey.currentState!.validate()) return;
// //     setState(() => isSaving = true);

// //     try {
// //       name = nameController.text.trim();
// //       description = descriptionController.text.trim();
// //       price = double.tryParse(priceController.text) ?? 0.0;
// //       offerPrice = double.tryParse(offerPriceController.text) ?? 0.0;
// //       quantity = int.tryParse(quantityController.text) ?? 1;

// //       final parentJson = {
// //         'name': name,
// //         'description': description,
// //         'categoryId': selectedCategoryId,
// //         'subcategoryId': selectedSubcategoryId,
// //         'brandId': selectedBrandId,
// //         'isSponsored': 0,
// //         'price': price,
// //         'offerPrice': offerPrice,
// //         'quantity': quantity,
// //         'stock': stock,
// //         if (widget.productId != null) 'productId': widget.productId,
// //       };

// //       final List<Map<String, dynamic>> variantsPayload = [];

// //       for (final c in combos) {
// //         final selections = <Map<String, dynamic>>[];
// //         c.selections.forEach((typeName, valueName) {
// //           selections.add({'VariantType': typeName, 'Variant': valueName});
// //         });

// //         final combinationKey = selections.map((s) => '${s['VariantType']}:${s['Variant']}').join('|');
// //         final label = selections.map((s) => '${s['Variant']}').join(', ');

// //         variantsPayload.add({
// //           'combinationKey': combinationKey,
// //           'label': label,
// //           'selections': selections,
// //           'price': c.price,
// //           'offerPrice': c.offerPrice,
// //           'stock': c.stock,
// //           'sku': c.sku,
// //           'description': c.description,
// //           'useParentImages': c.useParentImages,
// //         });
// //       }

// //       // Build childVariants for images (as before)
// //       final childVariants = combos.map((c) {
// //         return {
// //           'combo': c.selections.values.toList(),
// //           'price': c.price,
// //           'offerPrice': c.offerPrice,
// //           'stock': c.stock,
// //           'sku': c.sku,
// //           'description': c.description,
// //           'imageFile': c.imageFile,
// //           'imageBytes': c.imageBytes,
// //           'useParentImages': c.useParentImages,
// //         };
// //       }).toList();

// //       final resp = await ApiService.uploadProductWithVariants(
// //         parentJson: parentJson,
// //         variantsPayload: variantsPayload,
// //         parentImageFiles: imageFiles,
// //         parentImageBytes: imageBytes,
// //         childVariants: childVariants,
// //       );

// //       setState(() => isSaving = false);

// //       if (resp['success'] == true) {
// //         if (mounted) {
// //           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product & variants saved')));
// //           Navigator.pop(context);
// //         }
// //       } else {
// //         final err = resp['error'] ?? 'Unknown error';
// //         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $err')));
// //       }
// //     } catch (e) {
// //       setState(() => isSaving = false);
// //       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
// //     }
// //   }

// //   // ----------------- Category / Subcategory helpers -----------------
// //   void onCategoryChanged(int? value) async {
// //     if (value == null) return;
// //     setState(() {
// //       selectedCategoryId = value;
// //       selectedSubcategoryId = null;
// //       selectedBrandId = null;
// //       filteredSubcategories = [];
// //       brands.clear();
// //     });
// //     final subs = await ApiService.getSubcategories(value);
// //     setState(() => filteredSubcategories = subs);
// //   }

// //   void onSubcategoryChanged(int? value) async {
// //     if (value == null) return;
// //     setState(() {
// //       selectedSubcategoryId = value;
// //       selectedBrandId = null;
// //     });
// //     // in your app brands might be filtered by subcategory; keep existing behavior
// //     setState(() => brands = brands);
// //   }

// //   // ----------------- UI -----------------
// //   @override
// //   Widget build(BuildContext context) {
// //     if (isLoading) {
// //       return Scaffold(
// //         appBar: AppBar(title: Text(widget.productId == null ? 'Add Product' : 'Edit Product')),
// //         body: const Center(child: CircularProgressIndicator()),
// //       );
// //     }

// //     return Scaffold(
// //       appBar: AppBar(title: Text(widget.productId == null ? 'Add Product' : 'Edit Product')),
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(16),
// //         child: Card(
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //           elevation: 5,
// //           child: Padding(
// //             padding: const EdgeInsets.all(16.0),
// //             child: Form(
// //               key: _formKey,
// //               child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
// //                 ElevatedButton.icon(
// //                   onPressed: pickParentImage,
// //                   icon: const Icon(Icons.add_photo_alternate_outlined),
// //                   label: const Text('Pick Images (Parent)'),
// //                 ),
// //                 const SizedBox(height: 10),
// //                 SizedBox(
// //                   height: 100,
// //                   child: ListView(
// //                     scrollDirection: Axis.horizontal,
// //                     children: [
// //                       ...imageFiles.map((f) => Padding(
// //                             padding: const EdgeInsets.all(4.0),
// //                             child: ClipRRect(
// //                               borderRadius: BorderRadius.circular(8),
// //                               child: Image.file(f, width: 100, height: 100, fit: BoxFit.cover),
// //                             ),
// //                           )),
// //                       ...imageBytes.map((b) => Padding(
// //                             padding: const EdgeInsets.all(4.0),
// //                             child: ClipRRect(
// //                               borderRadius: BorderRadius.circular(8),
// //                               child: Image.memory(b, width: 100, height: 100, fit: BoxFit.cover),
// //                             ),
// //                           )),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(height: 16),
// //                 TextFormField(
// //                   controller: nameController,
// //                   decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.text_fields), border: OutlineInputBorder()),
// //                   validator: (v) => v == null || v.isEmpty ? 'Required' : null,
// //                 ),
// //                 const SizedBox(height: 12),
// //                 TextFormField(
// //                   controller: descriptionController,
// //                   decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
// //                   maxLines: 3,
// //                 ),
// //                 const SizedBox(height: 12),
// //                 Row(children: [
// //                   Expanded(
// //                     child: TextFormField(
// //                       controller: priceController,
// //                       decoration: const InputDecoration(labelText: 'Parent Price', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
// //                       keyboardType: TextInputType.number,
// //                     ),
// //                   ),
// //                   const SizedBox(width: 12),
// //                   Expanded(
// //                     child: TextFormField(
// //                       controller: offerPriceController,
// //                       decoration: const InputDecoration(labelText: 'Parent Offer Price', prefixIcon: Icon(Icons.local_offer), border: OutlineInputBorder()),
// //                       keyboardType: TextInputType.number,
// //                     ),
// //                   ),
// //                 ]),
// //                 const SizedBox(height: 12),
// //                 TextFormField(
// //                   decoration: const InputDecoration(labelText: 'Stock (parent)', prefixIcon: Icon(Icons.inventory), border: OutlineInputBorder()),
// //                   keyboardType: TextInputType.number,
// //                   onChanged: (value) => stock = int.tryParse(value) ?? 0,
// //                 ),
// //                 const SizedBox(height: 12),
// //                 TextFormField(
// //                   controller: quantityController,
// //                   decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.production_quantity_limits), border: OutlineInputBorder()),
// //                   keyboardType: TextInputType.number,
// //                 ),
// //                 const SizedBox(height: 16),
// //                 DropdownButtonFormField<int>(
// //                   decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category), border: OutlineInputBorder()),
// //                   value: selectedCategoryId,
// //                   items: categories.map((cat) {
// //                     final v = cat['CategoryID'];
// //                     final label = (cat['Name'] ?? cat['name'] ?? cat['CategoryName'] ?? '').toString();
// //                     final val = _toIntSafe(v);
// //                     return DropdownMenuItem<int>(value: val, child: Text(label));
// //                   }).toList(),
// //                   onChanged: (v) => onCategoryChanged(v),
// //                 ),
// //                 const SizedBox(height: 12),
// //                 DropdownButtonFormField<int>(
// //                   decoration: const InputDecoration(labelText: 'Subcategory', prefixIcon: Icon(Icons.subdirectory_arrow_right), border: OutlineInputBorder()),
// //                   value: selectedSubcategoryId,
// //                   items: filteredSubcategories.map((s) {
// //                     final val = _toIntSafe(s['SubcategoryID'] ?? s['id']);
// //                     final label = (s['Name'] ?? s['name'] ?? '').toString();
// //                     return DropdownMenuItem<int>(value: val, child: Text(label));
// //                   }).toList(),
// //                   onChanged: (v) => onSubcategoryChanged(v),
// //                 ),
// //                 const SizedBox(height: 12),
// //                 DropdownButtonFormField<int>(
// //                   decoration: const InputDecoration(labelText: 'Brand', prefixIcon: Icon(Icons.branding_watermark), border: OutlineInputBorder()),
// //                   value: selectedBrandId,
// //                   items: brands.map((b) {
// //                     final val = _toIntSafe(b['BrandID'] ?? b['id']);
// //                     final label = (b['Name'] ?? b['name'] ?? '').toString();
// //                     return DropdownMenuItem<int>(value: val, child: Text(label));
// //                   }).toList(),
// //                   onChanged: (v) => setState(() => selectedBrandId = v),
// //                 ),

// //                 const SizedBox(height: 20),

// //                 // Variant selector header
// //                 Row(
// //                   children: [
// //                     const Expanded(child: Text('Variant Types & Values', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
// //                     ElevatedButton(onPressed: openVariantTypeSelector, child: const Text('Select Variant Types')),
// //                     const SizedBox(width: 8),
// //                     ElevatedButton(onPressed: generateCombinations, child: const Text('Generate Combinations')),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 12),

// //                 // show selected types and their "select values" buttons + chips
// //                 ...selectedVariantPes.asMap().entries.map((entry) {
// //                   final idx = entry.key;
// //                   final pes = entry.value;
// //                   final valuesList = <String>[];
// //                   if (pes['values'] is List) {
// //                     for (final v in pes['values']) {
// //                       valuesList.add(v?.toString() ?? '');
// //                     }
// //                   }
// //                   return Card(
// //                     margin: const EdgeInsets.symmetric(vertical: 6),
// //                     child: Padding(
// //                       padding: const EdgeInsets.all(12),
// //                       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// //                         Row(
// //                           children: [
// //                             Expanded(child: Text(pes['name']?.toString() ?? 'Variant', style: const TextStyle(fontWeight: FontWeight.bold))),
// //                             TextButton(onPressed: () => openValuesSelector(idx), child: const Text('Select values')),
// //                             IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { selectedVariantPes.removeAt(idx); combos.clear(); })),
// //                           ],
// //                         ),
// //                         const SizedBox(height: 8),
// //                         Wrap(
// //                           spacing: 8,
// //                           children: valuesList.map((v) => Chip(label: Text(v))).toList(),
// //                         ),
// //                         const SizedBox(height: 6),
// //                         Row(
// //                           children: [
// //                             TextButton(
// //                               onPressed: () {
// //                                 // quick add custom
// //                                 String newVal = '';
// //                                 showDialog(context: context, builder: (_) => AlertDialog(
// //                                   title: const Text('Add custom value'),
// //                                   content: TextField(onChanged: (t) => newVal = t, decoration: const InputDecoration(hintText: 'Value')),
// //                                   actions: [
// //                                     TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
// //                                     ElevatedButton(onPressed: () {
// //                                       if (newVal.trim().isNotEmpty) {
// //                                         final list = List<String>.from(selectedVariantPes[idx]['values'] ?? []);
// //                                         list.add(newVal.trim());
// //                                         setState(() => selectedVariantPes[idx]['values'] = list);
// //                                       }
// //                                       Navigator.pop(context);
// //                                     }, child: const Text('Add'))
// //                                   ],
// //                                 ));
// //                               },
// //                               child: const Text('+ Add Custom Value'),
// //                             ),
// //                           ],
// //                         )
// //                       ]),
// //                     ),
// //                   );
// //                 }).toList(),

// //                 const SizedBox(height: 16),

// //                 if (combos.isNotEmpty) const Text('Generated Variant Combinations', style: TextStyle(fontWeight: FontWeight.bold)),
// //                 const SizedBox(height: 8),

// //                 ...combos.asMap().entries.map((entry) {
// //                   final idx = entry.key;
// //                   final combo = entry.value;
// //                   return Card(
// //                     margin: const EdgeInsets.symmetric(vertical: 8),
// //                     child: Padding(
// //                       padding: const EdgeInsets.all(12),
// //                       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// //                         Text(combo.selections.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(fontWeight: FontWeight.bold)),
// //                         const SizedBox(height: 8),
// //                         Row(children: [
// //                           ElevatedButton.icon(onPressed: () => pickComboImage(combo), icon: const Icon(Icons.photo), label: const Text('Pick Image')),
// //                           const SizedBox(width: 12),
// //                           if (combo.imageBytes != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(combo.imageBytes!, width: 80, height: 80, fit: BoxFit.cover)),
// //                           if (combo.imageFile != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(combo.imageFile!, width: 80, height: 80, fit: BoxFit.cover)),
// //                         ]),
// //                         const SizedBox(height: 8),
// //                         Row(children: [
// //                           Expanded(child: TextFormField(initialValue: combo.price.toString(), decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => combo.price = double.tryParse(v) ?? 0)),
// //                           const SizedBox(width: 8),
// //                           Expanded(child: TextFormField(initialValue: combo.offerPrice.toString(), decoration: const InputDecoration(labelText: 'Offer Price', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => combo.offerPrice = double.tryParse(v) ?? 0)),
// //                         ]),
// //                         const SizedBox(height: 8),
// //                         Row(children: [
// //                           Expanded(child: TextFormField(initialValue: combo.stock.toString(), decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => combo.stock = int.tryParse(v) ?? 0)),
// //                           const SizedBox(width: 8),
// //                           Expanded(child: TextFormField(initialValue: combo.sku, decoration: const InputDecoration(labelText: 'SKU', border: OutlineInputBorder()), onChanged: (v) => combo.sku = v)),
// //                         ]),
// //                         const SizedBox(height: 8),
// //                         TextFormField(initialValue: combo.description, decoration: const InputDecoration(labelText: 'Variant Description', border: OutlineInputBorder()), maxLines: 2, onChanged: (v) => combo.description = v),
// //                         const SizedBox(height: 8),
// //                         Row(children: [
// //                           const Text('Use parent images:'),
// //                           const SizedBox(width: 8),
// //                           Switch(value: combo.useParentImages, onChanged: (v) => setState(() => combo.useParentImages = v)),
// //                           const Spacer(),
// //                           IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => combos.removeAt(idx))),
// //                         ])
// //                       ]),
// //                     ),
// //                   );
// //                 }).toList(),

// //                 const SizedBox(height: 20),
// //                 SizedBox(
// //                   height: 50,
// //                   child: ElevatedButton.icon(
// //                     icon: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
// //                     label: Text(widget.productId == null ? 'Save Product' : 'Update Product', style: const TextStyle(fontSize: 18)),
// //                     onPressed: isSaving ? null : saveProduct,
// //                     style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
// //                   ),
// //                 ),
// //               ]),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }



// // add_edit_product_page.dart
// // ignore_for_file: unnecessary_type_check, unnecessary_null_comparison

// import 'dart:io';
// import 'dart:typed_data';
// import 'package:admin_panel/models/variant_models.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/api_service.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter_image_compress/flutter_image_compress.dart';

// /// ---------------------- Page ----------------------
// class AddEditProductPage extends StatefulWidget {
//   final int? productId; // if provided → edit mode
//   const AddEditProductPage({Key? key, this.productId}) : super(key: key);

//   @override
//   State<AddEditProductPage> createState() => _AddEditProductPageState();
// }

// class _AddEditProductPageState extends State<AddEditProductPage> {
//   final _formKey = GlobalKey<FormState>();

//   // basic product fields
//   String name = '';
//   String description = '';
//   double price = 0.0;
//   double offerPrice = 0.0;
//   int stock = 0;
//   int quantity = 1;

//   int? selectedCategoryId;
//   int? selectedSubcategoryId;
//   int? selectedBrandId;

//   final nameController = TextEditingController();
//   final descriptionController = TextEditingController();
//   final priceController = TextEditingController();
//   final offerPriceController = TextEditingController();
//   final quantityController = TextEditingController();

//   // Parent images
//   List<File> imageFiles = [];
//   List<Uint8List> imageBytes = [];

//   bool isSaving = false;
//   bool isLoading = false;

//   // data lists
//   List<Map<String, dynamic>> categories = [];
//   List<Map<String, dynamic>> filteredSubcategories = [];
//   List<Map<String, dynamic>> filteredBrands = [];
//   List<Map<String, dynamic>> brands = [];

//   // Variant types / values loaded from API
//   List<Map<String, dynamic>> variantTypes = []; // [{id, name}]
//   Map<int, List<Map<String, dynamic>>> variantValuesByType = {}; // typeId -> [{id, value}]

//   // ----- Variant system data -----
//   // We'll use Option B style: store name + values (strings)
//   List<Map<String, dynamic>> selectedVariantPes = []; // [{ "typeId": 1, "name": "Color", "values": ["Red","Blue"] }]
//   List<VariantCombo> combos = []; // generated child combinations

//   @override
//   void initState() {
//     super.initState();
//     loadData();
//     if (widget.productId != null) {
//       // Load existing product (safe call)
//       loadExistingProduct(widget.productId!);
//     }
//   }

//   /// ---------------------- INITIAL DATA LOAD ----------------------
//   Future<void> loadData() async {
//     try {
//       final cats = await ApiService.getCategories();
//       final brs = await ApiService.getBrands();
//       final vTypes = await ApiService.getVariantTypes();

//       // Normalize variantTypes to {id:int, name:String}
//       final normalizedVT = <Map<String, dynamic>>[];
//       if (vTypes is List) {
//         for (final e in vTypes) {
//           if (e is Map) {
//             final rawId = e['VariantTypeID'] ??
//                 e['id'] ??
//                 e['VariantTypeId'] ??
//                 e['variantTypeId'];
//             final rawName = e['VariantType'] ??
//                 e['VariantName'] ??
//                 e['name'] ??
//                 e['variantName'];
//             final id = _toIntSafe(rawId);
//             final name = rawName?.toString() ?? 'Variant';
//             if (id != null) {
//               normalizedVT.add({'id': id, 'name': name});
//             } else {
//               // fallback - keep string id as hashCode
//               normalizedVT.add({'id': name.hashCode, 'name': name});
//             }
//           } else {
//             // Unexpected shape - convert to string
//             normalizedVT.add({'id': e.hashCode, 'name': e.toString()});
//           }
//         }
//       }

//       setState(() {
//         categories = List<Map<String, dynamic>>.from(cats);
//         brands = List<Map<String, dynamic>>.from(brs);
//         variantTypes = normalizedVT;
//         if (categories.isNotEmpty) {
//           selectedCategoryId = categories.first['CategoryID'];
//         }
//       });

//       if (selectedCategoryId != null) {
//         final subs = await ApiService.getSubcategories(selectedCategoryId!);
//         setState(
//           () => filteredSubcategories =
//               List<Map<String, dynamic>>.from(subs),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to load data: $e')),
//         );
//       }
//     }
//   }

//   int? _toIntSafe(dynamic v) {
//     if (v == null) return null;
//     if (v is int) return v;
//     if (v is double) return v.toInt();
//     try {
//       return int.parse(v.toString());
//     } catch (_) {
//       return null;
//     }
//   }

//   /// ---------------------- LOAD EXISTING PRODUCT (SAFE) ----------------------
//   Future<void> loadExistingProduct(int id) async {
//     setState(() => isLoading = true);
//     try {
//       // ApiService.getProductWithVariants may or may not exist in your service.
//       // We call it and if it fails we catch and continue.
//       final resp = await ApiService.getProductWithVariants(id);
//       if (resp == null) throw Exception('Empty response');

//       final parent = (resp['parent'] as Map<String, dynamic>?) ?? {};
//       final children = (resp['children'] as List<dynamic>?) ?? [];

//       // fill parent fields
//       nameController.text = parent['Name'] ?? '';
//       descriptionController.text = parent['Description'] ?? '';
//       priceController.text =
//           (parent['Price'] != null) ? parent['Price'].toString() : '0';
//       offerPriceController.text = (parent['OfferPrice'] != null)
//           ? parent['OfferPrice'].toString()
//           : '0';
//       quantityController.text = (parent['Quantity'] != null)
//           ? parent['Quantity'].toString()
//           : '1';
//       selectedCategoryId = parent['CategoryID'];
//       selectedSubcategoryId = parent['SubcategoryID'];
//       selectedBrandId = parent['BrandID'];
//       stock = parent['Stock'] ?? 0;

//       // images: keep empty files/bytes (we'll keep server-linked images untouched)
//       imageFiles = [];
//       imageBytes = [];

//       // Build selectedVariantPes and combos from children:
//       selectedVariantPes.clear();
//       combos.clear();

//       final Map<String, Set<String>> typeToValues = {};

//       for (final ch in children) {
//         if (ch is! Map) continue;
//         final selections = (ch['variantSelections'] as List<dynamic>?) ?? [];

//         // if API included names in selections, prefer them
//         if (selections.isNotEmpty) {
//           for (final selRaw in selections) {
//             if (selRaw is! Map) continue;
//             final typeName = selRaw['VariantTypeName'] ??
//                 selRaw['VariantType'] ??
//                 selRaw['variantType'] ??
//                 '';
//             final valName = selRaw['VariantName'] ??
//                 selRaw['VariantValue'] ??
//                 selRaw['Variant'] ??
//                 selRaw['variant'] ??
//                 '';
//             final tn = typeName.toString();
//             final vn = valName.toString();
//             if (tn.isEmpty) continue;
//             typeToValues.putIfAbsent(tn, () => <String>{});
//             if (vn.isNotEmpty) typeToValues[tn]!.add(vn);
//           }
//         } else {
//           // fallback parse child name like "Parent (Red, 64GB)"
//           final childName = (ch['Name'] ?? '').toString();
//           final inParen = RegExp(r'\((.*)\)').firstMatch(childName);
//           final valuesFromName = inParen != null
//               ? inParen.group(1)!.split(',').map((s) => s.trim()).toList()
//               : <String>[];
//           for (final v in valuesFromName) {
//             typeToValues.putIfAbsent('Variant', () => <String>{});
//             typeToValues['Variant']!.add(v);
//           }
//         }

//         // Build a combo object from child
//         final comboSelections = <String, String>{};
//         final sels = (ch['variantSelections'] as List<dynamic>?) ?? [];
//         if (sels.isNotEmpty) {
//           for (final sRaw in sels) {
//             if (sRaw is! Map) continue;
//             final tName = sRaw['VariantTypeName'] ??
//                 sRaw['VariantType'] ??
//                 sRaw['variantType'] ??
//                 '';
//             final vName = sRaw['VariantName'] ??
//                 sRaw['VariantValue'] ??
//                 sRaw['Variant'] ??
//                 sRaw['variant'] ??
//                 '';
//             if (tName.toString().isNotEmpty &&
//                 vName.toString().isNotEmpty) {
//               comboSelections[tName.toString()] = vName.toString();
//             }
//           }
//         } else {
//           final childName = (ch['Name'] ?? '').toString();
//           final inParen = RegExp(r'\((.*)\)').firstMatch(childName);
//           final valuesFromName = inParen != null
//               ? inParen.group(1)!.split(',').map((s) => s.trim()).toList()
//               : <String>[];
//           if (valuesFromName.isNotEmpty) {
//             for (var i = 0; i < valuesFromName.length; i++) {
//               comboSelections['Variant${i + 1}'] = valuesFromName[i];
//             }
//           } else {
//             comboSelections['Variant'] = (ch['SKU'] ?? 'V').toString();
//           }
//         }

//         combos.add(
//           VariantCombo(
//             selections: comboSelections,
//             price: (ch['Price'] != null)
//                 ? double.tryParse(ch['Price'].toString()) ?? 0
//                 : 0,
//             offerPrice: (ch['OfferPrice'] != null)
//                 ? double.tryParse(ch['OfferPrice'].toString()) ?? 0
//                 : 0,
//             stock: ch['Stock'] ?? 0,
//             sku: ch['SKU']?.toString(),
//             description: ch['Description']?.toString() ?? '',
//             imageUrl: null,
//             useParentImages: true,
//           ),
//         );
//       }

//       selectedVariantPes = typeToValues.entries.map((e) {
//         return {
//           'typeId': null,
//           'name': e.key,
//           'values': e.value.toList(),
//         };
//       }).toList();

//       setState(() {});
//     } catch (e) {
//       // If ApiService.getProductWithVariants doesn't exist or fails, just log and continue.
//       debugPrint('loadExistingProduct error (safe): $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // ----------------- IMAGE PICK / COMPRESS -----------------
//   Future<void> pickParentImage() async {
//     final picked =
//         await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (picked == null) return;

//     try {
//       if (kIsWeb) {
//         final bytes = await picked.readAsBytes();
//         final decoded = img.decodeImage(bytes);
//         if (decoded != null) {
//           final resized = img.copyResize(decoded, width: 800);
//           final compressedBytes = Uint8List.fromList(
//             img.encodeJpg(resized, quality: 75),
//           );
//           setState(() => imageBytes.add(compressedBytes));
//         } else {
//           setState(() => imageBytes.add(bytes));
//         }
//       } else {
//         final compressedBytes = await FlutterImageCompress.compressWithFile(
//           picked.path,
//           quality: 75,
//           minWidth: 800,
//         );
//         if (compressedBytes != null) {
//           final compressedFile = File('${picked.path}_compressed.jpg')
//             ..writeAsBytesSync(compressedBytes);
//           setState(() => imageFiles.add(compressedFile));
//         } else {
//           setState(() => imageFiles.add(File(picked.path)));
//         }
//       }
//     } catch (e) {
//       debugPrint('Parent image pick error: $e');
//       if (kIsWeb) {
//         final bytes = await picked.readAsBytes();
//         setState(() => imageBytes.add(bytes));
//       } else {
//         setState(() => imageFiles.add(File(picked.path)));
//       }
//     }
//   }

//   /// ----------------- CHILD VARIANT IMAGES (MULTIPLE) -----------------
//   Future<void> pickComboImage(VariantCombo combo) async {
//     final picked =
//         await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (picked == null) return;

//     try {
//       combo.extraImages ??= [];

//       if (kIsWeb) {
//         final bytes = await picked.readAsBytes();
//         final decoded = img.decodeImage(bytes);
//         if (decoded != null) {
//           final resized = img.copyResize(decoded, width: 800);
//           final compressedBytes = Uint8List.fromList(
//             img.encodeJpg(resized, quality: 75),
//           );
//           combo.extraImages!.add(compressedBytes);
//         } else {
//           combo.extraImages!.add(bytes);
//         }
//       } else {
//         final compressedBytes = await FlutterImageCompress.compressWithFile(
//           picked.path,
//           quality: 75,
//           minWidth: 800,
//         );
//         if (compressedBytes != null) {
//           final f = File('${picked.path}_compressed.jpg')
//             ..writeAsBytesSync(compressedBytes);
//           combo.extraImages!.add(f);
//         } else {
//           combo.extraImages!.add(File(picked.path));
//         }
//       }

//       setState(() {});
//     } catch (e) {
//       debugPrint('Combo image pick error: $e');

//       combo.extraImages ??= [];
//       if (kIsWeb) {
//         final bytes = await picked.readAsBytes();
//         combo.extraImages!.add(bytes);
//       } else {
//         combo.extraImages!.add(File(picked.path));
//       }

//       setState(() {});
//     }
//   }

//   void _removeComboImage(VariantCombo combo, int index) {
//     if (combo.extraImages == null) return;
//     if (index < 0 || index >= combo.extraImages!.length) return;

//     setState(() {
//       combo.extraImages!.removeAt(index);
//     });
//   }

//   // ----------------- VARIANT VALUES FETCHING -----------------
//   /// ---------------------- VARIANT VALUES (variens) WITH DEBUG ----------------------
//   Future<void> fetchValuesForType(int typeId) async {
//     debugPrint("🔵 fetchValuesForType CALLED for typeId = $typeId");

//     try {
//       debugPrint("📡 Calling ApiService.getVariantValuesByType() ...");
//       final all = await ApiService.getVariantValuesByType(typeId);

//       debugPrint("📥 FULL variants response (${all.length} items):");
//       for (var v in all) {
//         debugPrint("   ➡ ${v.toString()}");
//       }

//       // Filter only values matching this typeId (VariantTypeID)
//       final filtered = all.where((v) {
//         final vtId =
//             int.tryParse(v['VariantTypeID'].toString()) ?? 0;
//         return vtId == typeId;
//       }).toList();

//       debugPrint(
//           "🔍 Filtered variens for typeId=$typeId → ${filtered.length} items");

//       // Normalize
//       final normalized = filtered.map((item) {
//         final id = item['VariantID'];
//         final rawVal = item['Variant'];

//         debugPrint("   🔧 Normalizing: id=$id  |  value=$rawVal");

//         return {
//           'id': id,
//           'value': rawVal?.toString() ?? '',
//         };
//       }).toList();

//       debugPrint(
//           "✅ Final normalized variens list (${normalized.length} items):");
//       for (var n in normalized) {
//         debugPrint("   ✔ $n");
//       }

//       // Save to map
//       setState(() {
//         variantValuesByType[typeId] = normalized;
//       });

//       debugPrint("💾 Saved to variantValuesByType[$typeId]");
//     } catch (e, st) {
//       debugPrint(
//           "❌ ERROR loading variens for typeId $typeId");
//       debugPrint("❌ Error: $e");
//       debugPrint("❌ Stacktrace: $st");

//       setState(() => variantValuesByType[typeId] = []);
//     }
//   }

//   void loadVariantTypes() async {
//     print("🟦 Loading Variant TYPES...");

//     try {
//       variantTypes = await ApiService.getVariantTypes();
//       print("🟩 Loaded ${variantTypes.length} variant types");
//     } catch (e) {
//       print("❌ ERROR loading variant types: $e");
//     }

//     setState(() {});
//   }

//   // ----------------- UI: Select Variant Types (multi-select) -----------------
//   Future<void> openVariantTypeSelector() async {
//     final currentSet =
//         selectedVariantPes.map((p) => p['name'].toString()).toSet();
//     final selectedMap = <int, bool>{};
//     for (final vt in variantTypes) {
//       selectedMap[vt['id'] as int] = currentSet.contains(vt['name']);
//     }

//     await showDialog(
//       context: context,
//       builder: (_) {
//         return AlertDialog(
//           title: const Text('Select Variant Types'),
//           content: SizedBox(
//             width: double.maxFinite,
//             child: ListView(
//               shrinkWrap: true,
//               children: variantTypes.map((vt) {
//                 final id = vt['id'] as int;
//                 final name = vt['name']?.toString() ?? 'Variant';
//                 return CheckboxListTile(
//                   title: Text(name),
//                   value: selectedMap[id] ?? false,
//                   onChanged: (v) =>
//                       setState(() => selectedMap[id] = v ?? false),
//                 );
//               }).toList(),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 // apply selection
//                 final newlySelected = <Map<String, dynamic>>[];
//                 for (final vt in variantTypes) {
//                   final id = vt['id'] as int;
//                   final name = vt['name']?.toString() ?? 'Variant';
//                   if (selectedMap[id] == true) {
//                     // find existing entry to preserve values
//                     final existing = selectedVariantPes.firstWhere(
//                       (e) =>
//                           e['name'] == name ||
//                           _toIntSafe(e['typeId']) == id,
//                       orElse: () => {},
//                     );
//                     if (existing.isNotEmpty) {
//                       newlySelected.add({
//                         'typeId': id,
//                         'name': name,
//                         'values': List<String>.from(
//                             existing['values'] ?? []),
//                       });
//                     } else {
//                       newlySelected.add({
//                         'typeId': id,
//                         'name': name,
//                         'values': <String>[]
//                       });
//                     }
//                   }
//                 }

//                 setState(() => selectedVariantPes = newlySelected);
//                 Navigator.pop(context);
//               },
//               child: const Text('OK'),
//             )
//           ],
//         );
//       },
//     );
//   }

//   // ----------------- UI: Select values for a type (multi-select) -----------------
//   Future<void> openValuesSelector(int pesIndex) async {
//     final pes = selectedVariantPes[pesIndex];
//     final typeId = _toIntSafe(pes['typeId']) ?? -1;
//     if (typeId == -1) return;

//     // ensure values loaded
//     await fetchValuesForType(typeId);
//     final list = variantValuesByType[typeId] ?? [];

//     final selectedValuesSet = <String>{};
//     final existing = pes['values'] ?? [];
//     for (final e in existing) {
//       selectedValuesSet.add(e.toString());
//     }

//     final tempMap = <String, bool>{};
//     for (final v in list) {
//       final val = v['value'].toString();
//       tempMap[val] = selectedValuesSet.contains(val);
//     }

//     await showDialog(
//       context: context,
//       builder: (_) {
//         return AlertDialog(
//           title: Text('Select values for ${pes['name']}'),
//           content: SizedBox(
//             width: double.maxFinite,
//             child: ListView(
//               shrinkWrap: true,
//               children: list.map((v) {
//                 final val = v['value'].toString();
//                 return CheckboxListTile(
//                   title: Text(val),
//                   value: tempMap[val] ?? false,
//                   onChanged: (ch) =>
//                       setState(() => tempMap[val] = ch ?? false),
//                 );
//               }).toList(),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final chosen = tempMap.entries
//                     .where((e) => e.value)
//                     .map((e) => e.key)
//                     .toList();
//                 setState(
//                   () => selectedVariantPes[pesIndex]['values'] = chosen,
//                 );
//                 Navigator.pop(context);
//               },
//               child: const Text('OK'),
//             )
//           ],
//         );
//       },
//     );
//   }

//   // ----------------- Combination generator (cartesian) -----------------
//   void generateCombinations() {
//     combos.clear();
//     if (selectedVariantPes.isEmpty) {
//       setState(() {});
//       return;
//     }

//     final lists = <List<String>>[];
//     for (final p in selectedVariantPes) {
//       final raw = p['values'] ?? [];
//       final vals = <String>[];
//       if (raw is List) {
//         for (final v in raw) {
//           vals.add(v?.toString() ?? '');
//         }
//       }
//       lists.add(vals.isEmpty ? [''] : vals);
//     }

//     final prod = _cartesian(lists);
//     for (final p in prod) {
//       final sel = <String, String>{};
//       for (var i = 0; i < p.length; i++) {
//         final key = selectedVariantPes[i]['name']?.toString() ??
//             'Variant${i + 1}';
//         sel[key] = p[i];
//       }
//       combos.add(VariantCombo(selections: sel));
//     }
//     setState(() {});
//   }

//   List<List<T>> _cartesian<T>(List<List<T>> lists) {
//     List<List<T>> result = [[]];
//     for (var list in lists) {
//       List<List<T>> temp = [];
//       for (var r in result) {
//         for (var item in list) {
//           temp.add([...r, item]);
//         }
//       }
//       result = temp;
//     }
//     return result;
//   }

//   // ----------------- Save product (same shape as earlier) -----------------
//   Future<void> saveProduct() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() => isSaving = true);

//     try {
//       // ------------------------ BASIC PARENT DATA ------------------------
//       name = nameController.text.trim();
//       description = descriptionController.text.trim();
//       price = double.tryParse(priceController.text) ?? 0.0;
//       offerPrice = double.tryParse(offerPriceController.text) ?? 0.0;
//       quantity = int.tryParse(quantityController.text) ?? 1;

//       final parentJson = {
//         'name': name,
//         'description': description,
//         'categoryId': selectedCategoryId,
//         'subcategoryId': selectedSubcategoryId,
//         'brandId': selectedBrandId,
//         'isSponsored': 0,
//         'price': price,
//         'offerPrice': offerPrice,
//         'quantity': quantity,
//         'stock': stock,
//         if (widget.productId != null) 'productId': widget.productId,
//       };

//       // ------------------------ VARIANTS PAYLOAD ------------------------
//       final List<Map<String, dynamic>> variantsPayload = [];
//       final Map<String, List<dynamic>> childImageMap = {};

//       for (final combo in combos) {
//         // ---- Deterministic selections list (backend-compatible) ----
//         final selectionsList = <Map<String, dynamic>>[];
//         combo.selections.forEach((typeName, valueName) {
//           selectionsList.add(
//             {'VariantType': typeName, 'Variant': valueName},
//           );
//         });

//         // ---- Generate exact comboKey (using VariantCombo's sanitizer) ----
//         final comboKey = combo.comboKey();

//         variantsPayload.add({
//           'combinationKey': comboKey,
//           'label': combo.selections.values.join(', '),
//           'selections': selectionsList,
//           'price': combo.price,
//           'offerPrice': combo.offerPrice,
//           'stock': combo.stock,
//           'sku': combo.sku,
//           'description': combo.description,
//           'useParentImages': combo.useParentImages,
//         });

//         // --------------------- SKIP IF USING PARENT IMAGES ---------------------
//         if (combo.useParentImages == true) continue;

//         // --------------------- COLLECT ALL CHILD IMAGES ------------------------
//         final fieldKey = "images_$comboKey";

//         childImageMap.putIfAbsent(fieldKey, () => []);

//         // 1) Single image (old fields, still supported)
//         if (combo.imageFile != null) {
//           childImageMap[fieldKey]!.add(combo.imageFile!);
//         }
//         if (combo.imageBytes != null) {
//           childImageMap[fieldKey]!.add(combo.imageBytes!);
//         }

//         // 2) Multiple images in extraImages list
//         if (combo.extraImages != null) {
//           for (final imgItem in combo.extraImages!) {
//             if (imgItem is File || imgItem is Uint8List) {
//               childImageMap[fieldKey]!.add(imgItem);
//             } else {
//               debugPrint(
//                   "❌ Unsupported image type in extraImages: ${imgItem.runtimeType}");
//             }
//           }
//         }
//       }

//       // ------------------------ UPLOAD TO API ------------------------
//       final resp = await ApiService.uploadProductWithVariants(
//         parentJson: parentJson,
//         variantsPayload: variantsPayload,
//         parentImageFiles: imageFiles,
//         parentImageBytes: imageBytes,
//         childVariants: childImageMap.entries
//             .map(
//               (e) => {
//                 'comboKey': e.key.replaceFirst('images_', ''),
//                 'images': e.value,
//                 'useParentImages': false,
//               },
//             )
//             .toList(),
//       );

//       setState(() => isSaving = false);

//       // ------------------------ RESULT ------------------------
//       if (resp['success'] == true) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Product & variants saved')),
//           );
//           Navigator.pop(context);
//         }
//       } else {
//         final err = resp['error'] ?? 'Unknown error';
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Save failed: $err')),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() => isSaving = false);
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Save failed: $e')),
//         );
//       }
//     }
//   }

//   /// ---------------------- UI BUILD ----------------------
//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Loading...')),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           widget.productId == null ? 'Add Product' : 'Edit Product',
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Card(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           elevation: 5,
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // Parent image picker
//                   ElevatedButton.icon(
//                     onPressed: pickParentImage,
//                     icon:
//                         const Icon(Icons.add_photo_alternate_outlined),
//                     label: const Text('Pick Images (Parent)'),
//                   ),
//                   const SizedBox(height: 10),
//                   SizedBox(
//                     height: 100,
//                     child: ListView(
//                       scrollDirection: Axis.horizontal,
//                       children: [
//                         ...imageFiles.map(
//                           (f) => Padding(
//                             padding: const EdgeInsets.all(4.0),
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.file(
//                                 f,
//                                 width: 100,
//                                 height: 100,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                           ),
//                         ),
//                         ...imageBytes.map(
//                           (b) => Padding(
//                             padding: const EdgeInsets.all(4.0),
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.memory(
//                                 b,
//                                 width: 100,
//                                 height: 100,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),

//                   // Basic fields
//                   TextFormField(
//                     controller: nameController,
//                     decoration: const InputDecoration(
//                       labelText: 'Product Name',
//                       prefixIcon: Icon(Icons.text_fields),
//                       border: OutlineInputBorder(),
//                     ),
//                     validator: (v) =>
//                         v == null || v.isEmpty ? 'Required' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: descriptionController,
//                     decoration: const InputDecoration(
//                       labelText: 'Description',
//                       prefixIcon: Icon(Icons.description),
//                       border: OutlineInputBorder(),
//                     ),
//                     maxLines: 3,
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextFormField(
//                           controller: priceController,
//                           decoration: const InputDecoration(
//                             labelText: 'Parent Price',
//                             prefixIcon: Icon(Icons.attach_money),
//                             border: OutlineInputBorder(),
//                           ),
//                           keyboardType: TextInputType.number,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: TextFormField(
//                           controller: offerPriceController,
//                           decoration: const InputDecoration(
//                             labelText: 'Parent Offer Price',
//                             prefixIcon: Icon(Icons.local_offer),
//                             border: OutlineInputBorder(),
//                           ),
//                           keyboardType: TextInputType.number,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: 'Stock (parent)',
//                       prefixIcon: Icon(Icons.inventory),
//                       border: OutlineInputBorder(),
//                     ),
//                     keyboardType: TextInputType.number,
//                     onChanged: (value) =>
//                         stock = int.tryParse(value) ?? 0,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: quantityController,
//                     decoration: const InputDecoration(
//                       labelText: 'Quantity',
//                       prefixIcon:
//                           Icon(Icons.production_quantity_limits),
//                       border: OutlineInputBorder(),
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
//                   const SizedBox(height: 16),

//                   // Category / Subcategory / Brand
//                   DropdownButtonFormField<int>(
//                     decoration: const InputDecoration(
//                       labelText: 'Category',
//                       prefixIcon: Icon(Icons.category),
//                       border: OutlineInputBorder(),
//                     ),
//                     value: selectedCategoryId,
//                     items: categories.map((cat) {
//                       final v = cat['CategoryID'];
//                       final label = (cat['Name'] ??
//                               cat['name'] ??
//                               cat['CategoryName'] ??
//                               '')
//                           .toString();
//                       final val = _toIntSafe(v);
//                       return DropdownMenuItem<int>(
//                         value: val,
//                         child: Text(label),
//                       );
//                     }).toList(),
//                     onChanged: (v) => onCategoryChanged(v),
//                   ),
//                   const SizedBox(height: 12),
//                   DropdownButtonFormField<int>(
//                     decoration: const InputDecoration(
//                       labelText: 'Subcategory',
//                       prefixIcon:
//                           Icon(Icons.subdirectory_arrow_right),
//                       border: OutlineInputBorder(),
//                     ),
//                     value: selectedSubcategoryId,
//                     items: filteredSubcategories.map((s) {
//                       final val =
//                           _toIntSafe(s['SubcategoryID'] ?? s['id']);
//                       final label =
//                           (s['Name'] ?? s['name'] ?? '').toString();
//                       return DropdownMenuItem<int>(
//                         value: val,
//                         child: Text(label),
//                       );
//                     }).toList(),
//                     onChanged: (v) => onSubcategoryChanged(v),
//                   ),
//                   const SizedBox(height: 12),
//                   DropdownButtonFormField<int>(
//                     decoration: const InputDecoration(
//                       labelText: 'Brand',
//                       prefixIcon:
//                           Icon(Icons.branding_watermark),
//                       border: OutlineInputBorder(),
//                     ),
//                     value: selectedBrandId,
//                     items: brands.map((b) {
//                       final val = _toIntSafe(b['BrandID'] ?? b['id']);
//                       final label =
//                           (b['Name'] ?? b['name'] ?? '').toString();
//                       return DropdownMenuItem<int>(
//                         value: val,
//                         child: Text(label),
//                       );
//                     }).toList(),
//                     onChanged: (v) =>
//                         setState(() => selectedBrandId = v),
//                   ),

//                   const SizedBox(height: 20),

//                   // ---------------------- VARIANT PES HEADER ---------------------- //
//                   Row(
//                     children: [
//                       const Expanded(
//                         child: Text(
//                           'Variant Types & Values',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       ElevatedButton(
//                         onPressed: openVariantTypeSelector,
//                         child: const Text('Select Variant Types'),
//                       ),
//                       const SizedBox(width: 8),
//                       ElevatedButton(
//                         onPressed: generateCombinations,
//                         child: const Text('Generate Combinations'),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),

//                   // Selected variant types + values
//                   ...selectedVariantPes.asMap().entries.map((entry) {
//                     final idx = entry.key;
//                     final pes = entry.value;
//                     final valuesList = <String>[];
//                     if (pes['values'] is List) {
//                       for (final v in pes['values']) {
//                         valuesList.add(v?.toString() ?? '');
//                       }
//                     }
//                     return Card(
//                       margin:
//                           const EdgeInsets.symmetric(vertical: 6),
//                       child: Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Column(
//                           crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     pes['name']?.toString() ??
//                                         'Variant',
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                                 TextButton(
//                                   onPressed: () =>
//                                       openValuesSelector(idx),
//                                   child:
//                                       const Text('Select values'),
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete,
//                                     color: Colors.red,
//                                   ),
//                                   onPressed: () => setState(() {
//                                     selectedVariantPes
//                                         .removeAt(idx);
//                                     combos.clear();
//                                   }),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             Wrap(
//                               spacing: 8,
//                               children: valuesList
//                                   .map((v) => Chip(label: Text(v)))
//                                   .toList(),
//                             ),
//                             const SizedBox(height: 6),
//                             Row(
//                               children: [
//                                 TextButton(
//                                   onPressed: () {
//                                     String newVal = '';
//                                     showDialog(
//                                       context: context,
//                                       builder: (_) => AlertDialog(
//                                         title: const Text(
//                                             'Add custom value'),
//                                         content: TextField(
//                                           onChanged: (t) =>
//                                               newVal = t,
//                                           decoration:
//                                               const InputDecoration(
//                                             hintText: 'Value',
//                                           ),
//                                         ),
//                                         actions: [
//                                           TextButton(
//                                             onPressed: () =>
//                                                 Navigator.pop(
//                                                     context),
//                                             child:
//                                                 const Text('Cancel'),
//                                           ),
//                                           ElevatedButton(
//                                             onPressed: () {
//                                               if (newVal
//                                                   .trim()
//                                                   .isNotEmpty) {
//                                                 final list =
//                                                     List<String>.from(
//                                                   selectedVariantPes[idx]
//                                                           ['values'] ??
//                                                       [],
//                                                 );
//                                                 list.add(
//                                                     newVal.trim());
//                                                 setState(
//                                                   () =>
//                                                       selectedVariantPes[idx]
//                                                               ['values'] =
//                                                           list,
//                                                 );
//                                               }
//                                               Navigator.pop(
//                                                   context);
//                                             },
//                                             child:
//                                                 const Text('Add'),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   },
//                                   child: const Text(
//                                       '+ Add Custom Value'),
//                                 ),
//                               ],
//                             )
//                           ],
//                         ),
//                       ),
//                     );
//                   }).toList(),

//                   const SizedBox(height: 16),

//                   if (combos.isNotEmpty)
//                     const Text(
//                       'Generated Variant Combinations',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                   const SizedBox(height: 8),

//                   // ---------- Variant combinations + MULTI IMAGE UI ----------
//                   ...combos.asMap().entries.map((entry) {
//                     final idx = entry.key;
//                     final combo = entry.value;
//                     final extraImgs = combo.extraImages ?? [];

//                     return Card(
//                       margin:
//                           const EdgeInsets.symmetric(vertical: 8),
//                       child: Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Column(
//                           crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               combo.selections.entries
//                                   .map((e) =>
//                                       '${e.key}: ${e.value}')
//                                   .join(' | '),
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),

//                             // Button + thumbnails row
//                             Row(
//                               children: [
//                                 ElevatedButton.icon(
//                                   onPressed: () =>
//                                       pickComboImage(combo),
//                                   icon: const Icon(Icons.photo),
//                                   label: const Text('Add Image'),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             if (extraImgs.isNotEmpty)
//                               SizedBox(
//                                 height: 90,
//                                 child: ListView.builder(
//                                   scrollDirection:
//                                       Axis.horizontal,
//                                   itemCount: extraImgs.length,
//                                   itemBuilder: (context, i) {
//                                     final imgObj =
//                                         extraImgs[i];
//                                     Widget imageWidget;

//                                     if (imgObj is Uint8List) {
//                                       imageWidget = Image.memory(
//                                         imgObj,
//                                         width: 80,
//                                         height: 80,
//                                         fit: BoxFit.cover,
//                                       );
//                                     } else if (imgObj is File) {
//                                       imageWidget = Image.file(
//                                         imgObj,
//                                         width: 80,
//                                         height: 80,
//                                         fit: BoxFit.cover,
//                                       );
//                                     } else {
//                                       imageWidget =
//                                           const Icon(Icons
//                                               .image_not_supported);
//                                     }

//                                     return Padding(
//                                       padding:
//                                           const EdgeInsets
//                                               .only(right: 8.0),
//                                       child: Stack(
//                                         children: [
//                                           ClipRRect(
//                                             borderRadius:
//                                                 BorderRadius
//                                                     .circular(
//                                                         8),
//                                             child:
//                                                 imageWidget,
//                                           ),
//                                           Positioned(
//                                             top: -8,
//                                             right: -8,
//                                             child:
//                                                 IconButton(
//                                               icon:
//                                                   const Icon(
//                                                 Icons.close,
//                                                 size: 18,
//                                                 color: Colors
//                                                     .red,
//                                               ),
//                                               onPressed: () =>
//                                                   _removeComboImage(
//                                                       combo,
//                                                       i),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),

//                             const SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: TextFormField(
//                                     initialValue:
//                                         combo.price.toString(),
//                                     decoration:
//                                         const InputDecoration(
//                                       labelText: 'Price',
//                                       border:
//                                           OutlineInputBorder(),
//                                     ),
//                                     keyboardType:
//                                         TextInputType.number,
//                                     onChanged: (v) =>
//                                         combo.price =
//                                             double.tryParse(
//                                                     v) ??
//                                                 0,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: TextFormField(
//                                     initialValue: combo
//                                         .offerPrice
//                                         .toString(),
//                                     decoration:
//                                         const InputDecoration(
//                                       labelText: 'Offer Price',
//                                       border:
//                                           OutlineInputBorder(),
//                                     ),
//                                     keyboardType:
//                                         TextInputType.number,
//                                     onChanged: (v) => combo
//                                             .offerPrice =
//                                         double.tryParse(v) ??
//                                             0,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: TextFormField(
//                                     initialValue:
//                                         combo.stock.toString(),
//                                     decoration:
//                                         const InputDecoration(
//                                       labelText: 'Stock',
//                                       border:
//                                           OutlineInputBorder(),
//                                     ),
//                                     keyboardType:
//                                         TextInputType.number,
//                                     onChanged: (v) =>
//                                         combo.stock =
//                                             int.tryParse(
//                                                     v) ??
//                                                 0,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: TextFormField(
//                                     initialValue:
//                                         combo.sku,
//                                     decoration:
//                                         const InputDecoration(
//                                       labelText: 'SKU',
//                                       border:
//                                           OutlineInputBorder(),
//                                     ),
//                                     onChanged: (v) =>
//                                         combo.sku = v,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               initialValue: combo.description,
//                               decoration:
//                                   const InputDecoration(
//                                 labelText:
//                                     'Variant Description',
//                                 border: OutlineInputBorder(),
//                               ),
//                               maxLines: 2,
//                               onChanged: (v) =>
//                                   combo.description = v,
//                             ),
//                             const SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 const Text('Use parent images:'),
//                                 const SizedBox(width: 8),
//                                 Switch(
//                                   value:
//                                       combo.useParentImages,
//                                   onChanged: (v) =>
//                                       setState(() {
//                                     combo.useParentImages =
//                                         v;
//                                   }),
//                                 ),
//                                 const Spacer(),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete,
//                                     color: Colors.red,
//                                   ),
//                                   onPressed: () => setState(
//                                     () =>
//                                         combos.removeAt(idx),
//                                   ),
//                                 ),
//                               ],
//                             )
//                           ],
//                         ),
//                       ),
//                     );
//                   }).toList(),

//                   const SizedBox(height: 20),
//                   SizedBox(
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       icon: isSaving
//                           ? const CircularProgressIndicator(
//                               color: Colors.white,
//                             )
//                           : const Icon(Icons.save),
//                       label: Text(
//                         widget.productId == null
//                             ? 'Save Product'
//                             : 'Update Product',
//                         style: const TextStyle(fontSize: 18),
//                       ),
//                       onPressed: isSaving ? null : saveProduct,
//                       style: ElevatedButton.styleFrom(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // helpers reused from earlier code for category/subcategory change (unchanged)
//   void onCategoryChanged(int? value) async {
//     if (value == null) return;
//     setState(() {
//       selectedCategoryId = value;
//       selectedSubcategoryId = null;
//       selectedBrandId = null;
//       filteredSubcategories = [];
//       filteredBrands = [];
//     });
//     final subs = await ApiService.getSubcategories(value);
//     setState(
//       () => filteredSubcategories =
//           List<Map<String, dynamic>>.from(subs),
//     );
//   }

//   void onSubcategoryChanged(int? value) async {
//     if (value == null) return;
//     setState(() {
//       selectedSubcategoryId = value;
//       selectedBrandId = null;
//       filteredBrands = [];
//     });
//     setState(() => filteredBrands = brands);
//   }
// }
