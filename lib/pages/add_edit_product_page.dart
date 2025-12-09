// add_edit_product_page.dart
// ignore_for_file: unnecessary_type_check, unnecessary_null_comparison

import 'dart:io';
import 'dart:typed_data';

import 'package:admin_panel/models/variant_models.dart';
import 'package:admin_panel/models/spec_models.dart'; // ⬅️ SpecSection / SpecField
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// ---------------------- Page ----------------------
class AddEditProductPage extends StatefulWidget {
  final int? productId; // if provided → edit mode
  const AddEditProductPage({Key? key, this.productId}) : super(key: key);

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();

  // basic product fields
  String name = '';
  String description = '';
  double price = 0.0;
  double offerPrice = 0.0;
  int stock = 0;
  int quantity = 1;

  int? selectedCategoryId;
  int? selectedSubcategoryId;
  int? selectedBrandId;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final offerPriceController = TextEditingController();
  final quantityController = TextEditingController();
  final parentVideoController = TextEditingController(); // parent video

  // Parent images
  List<File> imageFiles = [];
  List<Uint8List> imageBytes = [];
  List<String> parentImageUrls = [];

  bool isSaving = false;
  bool isLoading = false;

  // data lists
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> filteredSubcategories = [];
  List<Map<String, dynamic>> filteredBrands = [];
  List<Map<String, dynamic>> brands = [];

  // Variant types / values loaded from API
  List<Map<String, dynamic>> variantTypes = []; // [{id, name}]
  Map<int, List<Map<String, dynamic>>> variantValuesByType = {}; // typeId -> [{id, value}]

  // ----- Variant system data -----
  List<Map<String, dynamic>> selectedVariantPes = []; // [{ "typeId": 1, "name": "Color", "values": ["Red","Blue"] }]
  List<VariantCombo> combos = []; // generated child combinations

  // ----- SPECIFICATIONS MODULE -----
  List<SpecSection> specSections = [];
  Map<int, TextEditingController> specControllers = {}; // fieldId -> controller
  bool isLoadingSpecs = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await loadData();
    await _loadSpecTemplateAndValues(); // specs for this productId (parent OR child)
    if (widget.productId != null) {
      await loadExistingProduct(widget.productId!);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    offerPriceController.dispose();
    quantityController.dispose();
    parentVideoController.dispose();

    for (final c in specControllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  /// ---------------------- INITIAL DATA LOAD ----------------------
  Future<void> loadData() async {
    try {
      final cats = await ApiService.getCategories();
      final brs = await ApiService.getBrands();
      final vTypes = await ApiService.getVariantTypes();

      // Normalize variantTypes to {id:int, name:String}
      final normalizedVT = <Map<String, dynamic>>[];
      if (vTypes is List) {
        for (final e in vTypes) {
          if (e is Map) {
            final rawId = e['VariantTypeID'] ??
                e['id'] ??
                e['VariantTypeId'] ??
                e['variantTypeId'];
            final rawName =
                e['VariantType'] ?? e['VariantName'] ?? e['name'] ?? e['variantName'];
            final id = _toIntSafe(rawId);
            final name = rawName?.toString() ?? 'Variant';
            if (id != null) {
              normalizedVT.add({'id': id, 'name': name});
            } else {
              normalizedVT.add({'id': name.hashCode, 'name': name});
            }
          } else {
            normalizedVT.add({'id': e.hashCode, 'name': e.toString()});
          }
        }
      }

      setState(() {
        categories = List<Map<String, dynamic>>.from(cats);
        brands = List<Map<String, dynamic>>.from(brs);
        variantTypes = normalizedVT;
        if (categories.isNotEmpty) {
          selectedCategoryId = categories.first['CategoryID'];
        }
      });

      if (selectedCategoryId != null) {
        final subs = await ApiService.getSubcategories(selectedCategoryId!);
        setState(
          () => filteredSubcategories = List<Map<String, dynamic>>.from(subs),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  int? _toIntSafe(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    try {
      return int.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  /// ---------------------- SPEC TEMPLATE + EXISTING VALUES ----------------------
  Future<void> _loadSpecTemplateAndValues() async {
    setState(() => isLoadingSpecs = true);
    try {
      // 1) Get sections + fields template
      final sections = await ApiService.getSpecSectionsWithFields();
      final Map<int, String> existingValues = {};

      // 2) If editing existing product (PARENT OR CHILD) → load stored values
      if (widget.productId != null) {
        final vals = await ApiService.getProductSpecs(widget.productId!);
        existingValues.addAll(vals);
      }

      // 3) Create controllers for each field
      final Map<int, TextEditingController> ctrls = {};
      for (final sec in sections) {
        for (final field in sec.fields) {
          final existing = existingValues[field.fieldId] ?? '';
          ctrls[field.fieldId] = TextEditingController(text: existing);
        }
      }

      setState(() {
        specSections = sections;
        specControllers = ctrls;
      });
    } catch (e) {
      debugPrint('❌ load specs error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingSpecs = false);
      }
    }
  }

  /// =============================
  /// LOAD EXISTING PRODUCT (OPTION A FINAL)
  /// =============================
  Future<void> loadExistingProduct(int id) async {
    setState(() => isLoading = true);

    try {
      final resp = await ApiService.getProductWithVariants(id);
      if (resp == null) throw Exception("Empty response");

      // IMPORTANT: "parent" here is ALWAYS the product you clicked (parent OR child)
      final Map<String, dynamic> parent =
          Map<String, dynamic>.from(resp["parent"] ?? {});
      final List<dynamic> children = resp["children"] ?? [];

      debugPrint("🟢 Editing productId=$id as main product");
      debugPrint("🟢 Parent row: $parent");

      // 1) Fill parent (main product) fields
      nameController.text = parent["Name"]?.toString() ?? "";
      descriptionController.text = parent["Description"]?.toString() ?? "";
      priceController.text = parent["Price"]?.toString() ?? "0";
      offerPriceController.text = parent["OfferPrice"]?.toString() ?? "0";
      quantityController.text = parent["Quantity"]?.toString() ?? "1";
      stock = _toIntSafe(parent["Stock"]) ?? 0;

      parentVideoController.text =
          parent["VideoUrl"]?.toString() ?? parent["videoUrl"]?.toString() ?? "";

      // 2) Category / Subcategory / Brand
      selectedCategoryId = _toIntSafe(parent['CategoryID']);
      selectedSubcategoryId = _toIntSafe(parent['SubcategoryID']);
      selectedBrandId = _toIntSafe(parent['BrandID']);

      filteredSubcategories = [];
      filteredBrands = [];

      // Load subcategories for this category
      if (selectedCategoryId != null) {
        final subs =
            await ApiService.getSubcategories(selectedCategoryId!);
        filteredSubcategories =
            List<Map<String, dynamic>>.from(subs);
      }

      // Filter brands for selected subcategory
      filteredBrands = brands
          .where((b) => _toIntSafe(b["SubcategoryID"]) == selectedSubcategoryId)
          .toList();

      // Remove duplicate brands just in case
      final seen = <int>{};
      filteredBrands = filteredBrands.where((b) {
        final bid = _toIntSafe(b["BrandID"]);
        if (bid == null) return false;
        if (seen.contains(bid)) return false;
        seen.add(bid);
        return true;
      }).toList();

      // Validate current brand actually exists in filtered list
      final brandValid = selectedBrandId != null &&
          filteredBrands.any(
            (b) => _toIntSafe(b["BrandID"]) == selectedBrandId,
          );
      if (!brandValid) {
        debugPrint("⚠ Brand not found for this subcategory → resetting brand");
        selectedBrandId = null;
      }

      // 3) Parent images (URLs only; new uploads go to imageFiles / imageBytes)
      parentImageUrls = [];
      imageFiles = [];
      imageBytes = [];

      if (parent["images"] != null && parent["images"] is List) {
        for (final imgRow in parent["images"]) {
          try {
            final url = imgRow["ImageURL"]?.toString() ??
                imgRow["ImageUrl"]?.toString();
            if (url != null && url.isNotEmpty) {
              parentImageUrls.add(url);
            }
          } catch (_) {}
        }
      }

      // 4) Parse child variants (if any). If this product has no children,
      //    children will be empty and combos stay empty → fine.
      combos.clear();
      selectedVariantPes.clear();

      final Map<String, Set<String>> typeToValues = {};

      for (final ch in children) {
        if (ch is! Map) continue;
        final Map chMap = ch;

        final List variantSel = chMap["variantSelections"] ?? [];
        final Map<String, String> comboSelections = {};

        if (variantSel.isNotEmpty) {
          for (final sel in variantSel) {
            final typeName = sel["VariantTypeName"] ??
                sel["VariantType"] ??
                sel["variantType"] ??
                "Variant";

            final valueName = sel["VariantName"] ??
                sel["VariantValue"] ??
                sel["variant"] ??
                sel["Variant"] ??
                "";

            if (typeName != null && valueName != null) {
              final t = typeName.toString();
              final v = valueName.toString();
              typeToValues.putIfAbsent(t, () => <String>{});
              typeToValues[t]!.add(v);
              comboSelections[t] = v;
            }
          }
        } else {
          // Fallback: parse from Name, e.g. "Product (Black, XL)"
          final childName = chMap["Name"]?.toString() ?? "";
          final match = RegExp(r"\((.*?)\)").firstMatch(childName);

          if (match != null) {
            final parts =
                match.group(1)!.split(",").map((e) => e.trim()).toList();
            for (var i = 0; i < parts.length; i++) {
              final type = "Variant${i + 1}";
              final val = parts[i];

              typeToValues.putIfAbsent(type, () => <String>{});
              typeToValues[type]!.add(val);
              comboSelections[type] = val;
            }
          }
        }

        final childVideo = chMap["VideoUrl"]?.toString() ??
            chMap["videoUrl"]?.toString() ??
            "";

        combos.add(
          VariantCombo(
            selections: comboSelections,
            price: double.tryParse(chMap["Price"]?.toString() ?? "") ?? 0,
            offerPrice:
                double.tryParse(chMap["OfferPrice"]?.toString() ?? "") ?? 0,
            stock: _toIntSafe(chMap["Stock"]) ?? 0,
            sku: chMap["SKU"]?.toString() ?? "",
            description: chMap["Description"]?.toString() ?? "",
            useParentImages: true, // children use parent images by default here
            videoUrl: childVideo,
          ),
        );
      }

      selectedVariantPes = typeToValues.entries
          .map(
            (e) => {
              "typeId": null, // we don't map back to VariantTypes table here
              "name": e.key,
              "values": e.value.toList(),
            },
          )
          .toList();

      debugPrint("🟣 Final variant types: $selectedVariantPes");

      setState(() {});
    } catch (e, st) {
      debugPrint("❌ loadExistingProduct ERROR: $e\n$st");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ----------------- IMAGE PICK / COMPRESS -----------------
  Future<void> pickParentImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 800);
          final compressedBytes =
              Uint8List.fromList(img.encodeJpg(resized, quality: 75));
          setState(() => imageBytes.add(compressedBytes));
        } else {
          setState(() => imageBytes.add(bytes));
        }
      } else {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          picked.path,
          quality: 75,
          minWidth: 800,
        );
        if (compressedBytes != null) {
          final compressedFile = File('${picked.path}_compressed.jpg')
            ..writeAsBytesSync(compressedBytes);
          setState(() => imageFiles.add(compressedFile));
        } else {
          setState(() => imageFiles.add(File(picked.path)));
        }
      }
    } catch (e) {
      debugPrint('Parent image pick error: $e');
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => imageBytes.add(bytes));
      } else {
        setState(() => imageFiles.add(File(picked.path)));
      }
    }
  }
  

  /// CHILD VARIANT MULTI IMAGE
  Future<void> pickComboImage(VariantCombo combo) async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      combo.extraImages ??= [];

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 800);
          final compressedBytes =
              Uint8List.fromList(img.encodeJpg(resized, quality: 75));
          combo.extraImages!.add(compressedBytes);
        } else {
          combo.extraImages!.add(bytes);
        }
      } else {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          picked.path,
          quality: 75,
          minWidth: 800,
        );
        if (compressedBytes != null) {
          final f = File('${picked.path}_compressed.jpg')
            ..writeAsBytesSync(compressedBytes);
          combo.extraImages!.add(f);
        } else {
          combo.extraImages!.add(File(picked.path));
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('Combo image pick error: $e');

      combo.extraImages ??= [];
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        combo.extraImages!.add(bytes);
      } else {
        combo.extraImages!.add(File(picked.path));
      }

      setState(() {});
    }
  }

  void _removeComboImage(VariantCombo combo, int index) {
    if (combo.extraImages == null) return;
    if (index < 0 || index >= combo.extraImages!.length) return;

    setState(() {
      combo.extraImages!.removeAt(index);
    });
  }

  /// ---------------------- VARIANT VALUES ----------------------
  Future<void> fetchValuesForType(int typeId) async {
    debugPrint("🔵 fetchValuesForType CALLED for typeId = $typeId");

    try {
      debugPrint("📡 Calling ApiService.getVariantValuesByType() ...");
      final all = await ApiService.getVariantValuesByType(typeId);

      debugPrint("📥 FULL variants response (${all.length} items):");
      for (var v in all) {
        debugPrint("   ➡ ${v.toString()}");
      }

      final filtered = all.where((v) {
        final vtId = int.tryParse(v['VariantTypeID'].toString()) ?? 0;
        return vtId == typeId;
      }).toList();

      debugPrint("🔍 Filtered variants for typeId=$typeId → ${filtered.length} items");

      final normalized = filtered.map((item) {
        final id = item['VariantID'];
        final rawVal = item['Variant'];

        debugPrint("   🔧 Normalizing: id=$id  |  value=$rawVal");

        return {
          'id': id,
          'value': rawVal?.toString() ?? '',
        };
      }).toList();

      debugPrint("✅ Final normalized variants list (${normalized.length} items):");
      for (var n in normalized) {
        debugPrint("   ✔ $n");
      }

      setState(() {
        variantValuesByType[typeId] = normalized;
      });

      debugPrint("💾 Saved to variantValuesByType[$typeId]");
    } catch (e, st) {
      debugPrint("❌ ERROR loading variants for typeId $typeId");
      debugPrint("❌ Error: $e");
      debugPrint("❌ Stacktrace: $st");

      setState(() => variantValuesByType[typeId] = []);
    }
  }

  void loadVariantTypes() async {
    debugPrint("🟦 Loading Variant TYPES...");

    try {
      variantTypes = await ApiService.getVariantTypes();
      debugPrint("🟩 Loaded ${variantTypes.length} variant types");
    } catch (e) {
      debugPrint("❌ ERROR loading variant types: $e");
    }

    setState(() {});
  }

  // ----------------- UI: Select Variant Types -----------------
  Future<void> openVariantTypeSelector() async {
    final currentSet = selectedVariantPes.map((p) => p['name'].toString()).toSet();
    final selectedMap = <int, bool>{};
    for (final vt in variantTypes) {
      selectedMap[vt['id'] as int] = currentSet.contains(vt['name']);
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select Variant Types'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: variantTypes.map((vt) {
                final id = vt['id'] as int;
                final name = vt['name']?.toString() ?? 'Variant';
                return CheckboxListTile(
                  title: Text(name),
                  value: selectedMap[id] ?? false,
                  onChanged: (v) => setState(() => selectedMap[id] = v ?? false),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newlySelected = <Map<String, dynamic>>[];
                for (final vt in variantTypes) {
                  final id = vt['id'] as int;
                  final name = vt['name']?.toString() ?? 'Variant';
                  if (selectedMap[id] == true) {
                    final existing = selectedVariantPes.firstWhere(
                      (e) => e['name'] == name || _toIntSafe(e['typeId']) == id,
                      orElse: () => {},
                    );
                    if (existing.isNotEmpty) {
                      newlySelected.add({
                        'typeId': id,
                        'name': name,
                        'values': List<String>.from(existing['values'] ?? []),
                      });
                    } else {
                      newlySelected.add(
                        {
                          'typeId': id,
                          'name': name,
                          'values': <String>[],
                        },
                      );
                    }
                  }
                }

                setState(() => selectedVariantPes = newlySelected);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }

  // ----------------- UI: Select values for a type -----------------
  Future<void> openValuesSelector(int pesIndex) async {
    final pes = selectedVariantPes[pesIndex];
    final typeId = _toIntSafe(pes['typeId']) ?? -1;
    if (typeId == -1) return;

    await fetchValuesForType(typeId);
    final list = variantValuesByType[typeId] ?? [];

    final selectedValuesSet = <String>{};
    final existing = pes['values'] ?? [];
    for (final e in existing) {
      selectedValuesSet.add(e.toString());
    }

    final tempMap = <String, bool>{};
    for (final v in list) {
      final val = v['value'].toString();
      tempMap[val] = selectedValuesSet.contains(val);
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Select values for ${pes['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: list.map((v) {
                final val = v['value'].toString();
                return CheckboxListTile(
                  title: Text(val),
                  value: tempMap[val] ?? false,
                  onChanged: (ch) => setState(() => tempMap[val] = ch ?? false),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final chosen =
                    tempMap.entries.where((e) => e.value).map((e) => e.key).toList();
                setState(() => selectedVariantPes[pesIndex]['values'] = chosen);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }

  // ----------------- Combination generator (cartesian) -----------------
  void generateCombinations() {
    combos.clear();
    if (selectedVariantPes.isEmpty) {
      setState(() {});
      return;
    }

    final lists = <List<String>>[];
    for (final p in selectedVariantPes) {
      final raw = p['values'] ?? [];
      final vals = <String>[];
      if (raw is List) {
        for (final v in raw) {
          vals.add(v?.toString() ?? '');
        }
      }
      lists.add(vals.isEmpty ? [''] : vals);
    }

    final prod = _cartesian(lists);
    for (final p in prod) {
      final sel = <String, String>{};
      for (var i = 0; i < p.length; i++) {
        final key =
            selectedVariantPes[i]['name']?.toString() ?? 'Variant${i + 1}';
        sel[key] = p[i];
      }
      combos.add(VariantCombo(selections: sel));
    }
    setState(() {});
  }

  List<List<T>> _cartesian<T>(List<List<T>> lists) {
    List<List<T>> result = [[]];
    for (var list in lists) {
      List<List<T>> temp = [];
      for (var r in result) {
        for (var item in list) {
          temp.add([...r, item]);
        }
      }
      result = temp;
    }
    return result;
  }

  // ----------------- SPEC HELPERS -----------------
  List<Map<String, dynamic>> _collectSpecsToSave() {
    final List<Map<String, dynamic>> specs = [];

    for (final sec in specSections) {
      for (final field in sec.fields) {
        final ctrl = specControllers[field.fieldId];
        if (ctrl == null) continue;
        final val = ctrl.text.trim();
        if (val.isEmpty) continue; // skip empty fields
        specs.add({
          'fieldId': field.fieldId,
          'value': val,
        });
      }
    }

    return specs;
  }

  Widget _buildSpecificationSection() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isLoadingSpecs)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading specification template...'),
                  ],
                ),
              )
            else if (specSections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No specification template configured yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children: specSections.map((sec) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        sec.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...sec.fields.map((field) {
                        final ctrl = specControllers[field.fieldId] ??
                            TextEditingController();
                        specControllers[field.fieldId] = ctrl;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextFormField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              labelText: field.name,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------- Save product -----------------
  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      name = nameController.text.trim();
      description = descriptionController.text.trim();
      price = double.tryParse(priceController.text) ?? 0.0;
      offerPrice = double.tryParse(offerPriceController.text) ?? 0.0;
      quantity = int.tryParse(quantityController.text) ?? 1;

      final parentJson = {
        'name': name,
        'description': description,
        'categoryId': selectedCategoryId,
        'subcategoryId': selectedSubcategoryId,
        'brandId': selectedBrandId,
        'isSponsored': 0,
        'price': price,
        'offerPrice': offerPrice,
        'quantity': quantity,
        'stock': stock,
        'videoUrl': parentVideoController.text.trim(),
        if (widget.productId != null) 'productId': widget.productId,
      };

      final List<Map<String, dynamic>> variantsPayload = [];
      final Map<String, List<dynamic>> childImageMap = {};

      for (final combo in combos) {
        final selectionsList = combo.selections.entries
            .map((e) => {'VariantType': e.key, 'Variant': e.value})
            .toList();

        final comboKey = combo.comboKey();

        variantsPayload.add({
          'combinationKey': comboKey,
          'label': combo.selections.values.join(', '),
          'selections': selectionsList,
          'price': combo.price,
          'offerPrice': combo.offerPrice,
          'stock': combo.stock,
          'sku': combo.sku,
          'description': combo.description,
          'useParentImages': combo.useParentImages,
          'videoUrl': combo.videoUrl,
        });

        if (combo.useParentImages == false) {
          final fieldKey = "images_$comboKey";
          childImageMap[fieldKey] = [];

          if (combo.imageFile != null) {
            childImageMap[fieldKey]!.add(combo.imageFile!);
          }
          if (combo.imageBytes != null) {
            childImageMap[fieldKey]!.add(combo.imageBytes!);
          }

          if (combo.extraImages != null) {
            for (var img in combo.extraImages!) {
              if (img is File || img is Uint8List) {
                childImageMap[fieldKey]!.add(img);
              }
            }
          }
        }
      }

      late final resp;

      if (widget.productId == null) {
        /// CREATE
        resp = await ApiService.uploadProductWithVariants(
          parentJson: parentJson,
          variantsPayload: variantsPayload,
          parentImageFiles: imageFiles,
          parentImageBytes: imageBytes,
          childVariants: childImageMap.entries
              .map(
                (e) => {
                  'comboKey': e.key.replaceFirst("images_", ""),
                  'images': e.value,
                },
              )
              .toList(),
        );
      } else {
        /// UPDATE (parent OR child)
        resp = await ApiService.updateProductWithVariants(
          productId: widget.productId!,
          parentJson: parentJson,
          variantsPayload: variantsPayload,
          parentImageFiles: imageFiles,
          parentImageBytes: imageBytes,
          childVariants: childImageMap.entries
              .map(
                (e) => {
                  'comboKey': e.key.replaceFirst("images_", ""),
                  'images': e.value,
                },
              )
              .toList(),
        );
      }

      // Save Specs — ALWAYS for the product being edited (parent OR child)
      final specsPayload = _collectSpecsToSave();
      if (specsPayload.isNotEmpty) {
        await ApiService.saveProductSpecs(
          productId: widget.productId ?? resp['parentProductId'],
          specs: specsPayload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product saved successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  /// ---------------------- UI BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Parent image picker
                ElevatedButton.icon(
                  onPressed: pickParentImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Pick Images (Parent)'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // existing network images (optional – you can add preview if you want)
                      // ...parentImageUrls.map(
                      //   (url) => Padding(
                      //     padding: const EdgeInsets.all(4.0),
                      //     child: ClipRRect(
                      //       borderRadius: BorderRadius.circular(8),
                      //       child: Image.network(
                      //         url,
                      //         width: 100,
                      //         height: 100,
                      //         fit: BoxFit.cover,
                      //       ),
                      //     ),
                      //   ),
                      // ),

                      ...imageFiles.map(
                        (f) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              f,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      ...imageBytes.map(
                        (b) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              b,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Basic fields
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    prefixIcon: Icon(Icons.text_fields),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Parent YouTube URL
                TextFormField(
                  controller: parentVideoController,
                  decoration: const InputDecoration(
                    labelText: 'Parent Video URL (YouTube)',
                    prefixIcon: Icon(Icons.video_library),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Parent Price',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: offerPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Parent Offer Price',
                        prefixIcon: Icon(Icons.local_offer),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Stock (parent)',
                    prefixIcon: Icon(Icons.inventory),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => stock = int.tryParse(value) ?? 0,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.production_quantity_limits),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Category / Subcategory / Brand
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  value: selectedCategoryId,
                  items: categories.map((cat) {
                    final v = cat['CategoryID'];
                    final label =
                        (cat['Name'] ?? cat['name'] ?? cat['CategoryName'] ?? '')
                            .toString();
                    final val = _toIntSafe(v);
                    return DropdownMenuItem<int>(value: val, child: Text(label));
                  }).toList(),
                  onChanged: (v) => onCategoryChanged(v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Subcategory',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                    border: OutlineInputBorder(),
                  ),
                  value: selectedSubcategoryId,
                  items: filteredSubcategories.map((s) {
                    final val = _toIntSafe(s['SubcategoryID'] ?? s['id']);
                    final label = (s['Name'] ?? s['name'] ?? '').toString();
                    return DropdownMenuItem<int>(value: val, child: Text(label));
                  }).toList(),
                  onChanged: (v) => onSubcategoryChanged(v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    prefixIcon: Icon(Icons.branding_watermark),
                    border: OutlineInputBorder(),
                  ),
                  value: (selectedBrandId != null &&
                          filteredBrands.any(
                            (b) => _toIntSafe(b["BrandID"]) == selectedBrandId,
                          ))
                      ? selectedBrandId
                      : null,
                  items: filteredBrands.map((b) {
                    final id = _toIntSafe(b["BrandID"]);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(b["Name"].toString()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedBrandId = v),
                ),

                const SizedBox(height: 20),

                // VARIANT HEADER
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Variant Types & Values',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: openVariantTypeSelector,
                      child: const Text('Select Variant Types'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: generateCombinations,
                      child: const Text('Generate Combinations'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selected variant PES
                ...selectedVariantPes.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pes = entry.value;
                  final valuesList = <String>[];
                  if (pes['values'] is List) {
                    for (final v in pes['values']) {
                      valuesList.add(v?.toString() ?? '');
                    }
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pes['name']?.toString() ?? 'Variant',
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: () => openValuesSelector(idx),
                                child: const Text('Select values'),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(() {
                                  selectedVariantPes.removeAt(idx);
                                  combos.clear();
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: valuesList
                                .map((v) => Chip(label: Text(v)))
                                .toList(),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  String newVal = '';
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Add custom value'),
                                      content: TextField(
                                        onChanged: (t) => newVal = t,
                                        decoration:
                                            const InputDecoration(hintText: 'Value'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (newVal.trim().isNotEmpty) {
                                              final list =
                                                  List<String>.from(
                                                      selectedVariantPes[idx]
                                                              ['values'] ??
                                                          []);
                                              list.add(newVal.trim());
                                              setState(() =>
                                                  selectedVariantPes[idx]
                                                      ['values'] = list);
                                            }
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Add'),
                                        )
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('+ Add Custom Value'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),

                if (combos.isNotEmpty)
                  const Text(
                    'Generated Variant Combinations',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),

                // Variant combinations + MULTI IMAGE + VIDEO
                ...combos.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final combo = entry.value;
                  final extraImgs = combo.extraImages ?? [];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            combo.selections.entries
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' | '),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Button + thumbnails row
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => pickComboImage(combo),
                                icon: const Icon(Icons.photo),
                                label: const Text('Add Image'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (extraImgs.isNotEmpty)
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: extraImgs.length,
                                itemBuilder: (context, i) {
                                  final imgObj = extraImgs[i];
                                  Widget imageWidget;

                                  if (imgObj is Uint8List) {
                                    imageWidget = Image.memory(
                                      imgObj,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    );
                                  } else if (imgObj is File) {
                                    imageWidget = Image.file(
                                      imgObj,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    imageWidget =
                                        const Icon(Icons.image_not_supported);
                                  }

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: imageWidget,
                                        ),
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removeComboImage(combo, i),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: combo.price.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Price',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) =>
                                      combo.price = double.tryParse(v) ?? 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      combo.offerPrice.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Offer Price',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => combo.offerPrice =
                                      double.tryParse(v) ?? 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: combo.stock.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Stock',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) =>
                                      combo.stock = int.tryParse(v) ?? 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: combo.sku,
                                  decoration: const InputDecoration(
                                    labelText: 'SKU',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => combo.sku = v,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: combo.description,
                            decoration: const InputDecoration(
                              labelText: 'Variant Description',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            onChanged: (v) => combo.description = v,
                          ),
                          const SizedBox(height: 8),

                          // Variant YouTube URL
                          TextFormField(
                            initialValue: combo.videoUrl ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Variant Video URL (YouTube)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => combo.videoUrl = v.trim(),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Text('Use parent images:'),
                              const SizedBox(width: 8),
                              Switch(
                                value: combo.useParentImages,
                                onChanged: (v) =>
                                    setState(() => combo.useParentImages = v),
                              ),
                              const Spacer(),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    setState(() => combos.removeAt(idx)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),

                // Specifications section
                _buildSpecificationSection(),

                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.save),
                    label: Text(
                      widget.productId == null
                          ? 'Save Product'
                          : 'Update Product',
                      style: const TextStyle(fontSize: 18),
                    ),
                    onPressed: isSaving ? null : saveProduct,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // helpers reused from earlier code for category/subcategory change (unchanged)
  void onCategoryChanged(int? value) async {
    if (value == null) return;
    setState(() {
      selectedCategoryId = value;
      selectedSubcategoryId = null;
      selectedBrandId = null;
      filteredSubcategories = [];
      filteredBrands = [];
    });
    final subs = await ApiService.getSubcategories(value);
    setState(
      () => filteredSubcategories = List<Map<String, dynamic>>.from(subs),
    );
  }

  void onSubcategoryChanged(int? value) async {
    if (value == null) return;

    setState(() {
      selectedSubcategoryId = value;
      selectedBrandId = null;
    });

    filteredBrands = brands
        .where((b) => _toIntSafe(b["SubcategoryID"]) == value)
        .toList();

    // REMOVE DUPLICATE BRANDS
    final seen = <int>{};
    filteredBrands = filteredBrands.where((b) {
      final id = _toIntSafe(b["BrandID"]);
      if (id == null) return false;
      if (seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList();

    setState(() {});
  }
}
