// lib/pages/brands_page.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  List<Map<String, dynamic>> brands = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchBrands();
  }

  Future<void> fetchBrands() async {
    setState(() => isLoading = true);
    try {
      brands = await ApiService.getBrands();
    } catch (e) {
      brands = [];
      print('❌ Error fetching brands: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteBrand(int id) async {
    final ok = await ApiService.deleteBrand(id);
    if (ok) {
      await fetchBrands();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete brand')),
      );
    }
  }

  void _openAddEdit([Map<String, dynamic>? brand]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditBrandDialog(brand: brand),
    );
    await fetchBrands();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brands Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Brands',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: fetchBrands,
                        tooltip: 'Refresh Brands',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('New Brand'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: brands.isEmpty
                        ? const Center(child: Text('No brands found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Brand Name')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Subcategory')),
                                  DataColumn(label: Text('Added Date')),
                                  DataColumn(label: Text('Edit')),
                                  DataColumn(label: Text('Delete')),
                                ],
                                rows: brands.map((brand) {
                                  final name = brand['Name'] ?? 'Unnamed';
                                  final category =
                                      brand['CategoryName'] ?? 'N/A';
                                  final subcategory =
                                      brand['SubcategoryName'] ?? 'N/A';
                                  final addedDate =
                                      brand['CreatedAt'] ?? 'N/A';
                                  final id = brand['BrandID'] ?? 0;

                                  return DataRow(cells: [
                                    DataCell(Text(name)),
                                    DataCell(Text(category)),
                                    DataCell(Text(subcategory)),
                                    DataCell(Text(addedDate.toString())),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _openAddEdit(brand),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => deleteBrand(id),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AddEditBrandDialog extends StatefulWidget {
  final Map<String, dynamic>? brand;

  const AddEditBrandDialog({super.key, this.brand});

  @override
  State<AddEditBrandDialog> createState() => _AddEditBrandDialogState();
}

class _AddEditBrandDialogState extends State<AddEditBrandDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  int? selectedCategoryId;
  int? selectedSubcategoryId;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subcategories = [];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.brand?['Name'] ?? '');
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      categories = await ApiService.getCategories();

      if (widget.brand != null) {
        // ⬇️ These come from getBrands() mapping
        selectedCategoryId = widget.brand!['CategoryID'];
        selectedSubcategoryId = widget.brand!['SubcategoryID'];

        if (selectedCategoryId != null) {
          await loadSubcategories(selectedCategoryId!);
        }
      }

      setState(() {});
    } catch (e) {
      categories = [];
      print('❌ Failed to load categories: $e');
      setState(() {});
    }
  }

  Future<void> loadSubcategories(int categoryId) async {
    try {
      subcategories = await ApiService.getSubcategories(categoryId);
      setState(() {});
    } catch (e) {
      subcategories = [];
      print('❌ Failed to load subcategories: $e');
      setState(() {});
    }
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCategoryId == null || selectedSubcategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and subcategory')),
      );
      return;
    }

    final name = _nameController.text.trim();

    final success = widget.brand == null
        ? await ApiService.addBrand(
            name: name,
            categoryId: selectedCategoryId!,
            subcategoryId: selectedSubcategoryId!,
          )
        : await ApiService.updateBrand(
            id: widget.brand?['BrandID'] ?? 0,
            name: name,
            categoryId: selectedCategoryId!,
            subcategoryId: selectedSubcategoryId!,
          );

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save brand')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.brand == null ? 'Add Brand' : 'Edit Brand'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Brand Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: selectedCategoryId,
                items: categories.map((c) {
                  final id = c['CategoryID'] ?? c['id'];
                  final name = c['Name'] ?? c['name'] ?? 'Unnamed';
                  return DropdownMenuItem<int>(
                    value: id is int ? id : int.tryParse(id.toString()),
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedCategoryId = value;
                    selectedSubcategoryId = null;
                    subcategories = [];
                  });
                  if (value != null) {
                    await loadSubcategories(value);
                  }
                },
                validator: (v) => v == null ? 'Select category' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Subcategory'),
                value: selectedSubcategoryId,
                items: subcategories.map((c) {
                  final id = c['SubcategoryID'] ?? c['id'];
                  final name = c['Name'] ?? c['name'] ?? 'Unnamed';
                  return DropdownMenuItem<int>(
                    value: id is int ? id : int.tryParse(id.toString()),
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => selectedSubcategoryId = value),
                validator: (v) => v == null ? 'Select subcategory' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: save,
          child: Text(widget.brand == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
