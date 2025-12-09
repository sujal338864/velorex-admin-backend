// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<dynamic> categories = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() => isLoading = true);
    try {
      categories = await ApiService.getCategories();
      print('✅ Fetched categories: $categories');
    } catch (e) {
      print('❌ Failed to fetch categories: $e');
      categories = [];
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteCategory(int id) async {
    final ok = await ApiService.deleteCategory(id);
    if (ok) {
      fetchCategories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete category')),
      );
    }
  }

  void _openAddEdit([Map? category]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditCategoryDialog(category: category),
    );
    fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCategories,
          ),
          ElevatedButton(
            onPressed: () => _openAddEdit(),
            child: const Text('Add Category'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : categories.isEmpty
                ? const Center(child: Text('No categories found'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Category Name')),
                          DataColumn(label: Text('Added Date')),
                          DataColumn(label: Text('Edit')),
                          DataColumn(label: Text('Delete')),
                        ],
                        rows: categories.map<DataRow>((cat) {
                          final id = cat['CategoryID'] ?? cat['id'] ?? 0;
                          final name = cat['Name'] ?? cat['name'] ?? 'Unnamed';
                          final date = cat['CreatedAt'] ?? cat['createdAt'] ?? '';
                          final imageUrl = cat['ImageUrl'] ?? cat['imageUrl'] ?? '';

                          return DataRow(cells: [
                            DataCell(
                              imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                  : const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                            DataCell(Text(name)),
                            DataCell(Text(date)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openAddEdit(cat),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteCategory(id),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class AddEditCategoryDialog extends StatefulWidget {
  final Map? category;
  const AddEditCategoryDialog({super.key, this.category});

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isUploading = false;

  // For mobile and web
  File? _pickedImageFile;       // Mobile file
  Uint8List? _pickedImageBytes; // Web bytes
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.category?['Name'] ?? widget.category?['name'] ?? '';
    _uploadedImageUrl = widget.category?['ImageUrl'] ?? widget.category?['imageUrl'];
  }

  /// ✅ Pick image (works on both web and mobile)
  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      if (kIsWeb) {
        // Web
        setState(() => _pickedImageBytes = result.files.single.bytes);
      } else {
        // Mobile
        final path = result.files.single.path;
        if (path != null) {
          setState(() => _pickedImageFile = File(path));
        }
      }
    }
  }

  /// ✅ Upload to Supabase (works for both web and mobile)
  Future<String?> uploadToSupabase() async {
    try {
      setState(() => _isUploading = true);
      final supabase = Supabase.instance.client;
      final bucket = supabase.storage.from('categories');

      final fileName = 'categories/${DateTime.now().millisecondsSinceEpoch}.png';
      if (kIsWeb && _pickedImageBytes != null) {
        // Web upload
        await bucket.uploadBinary(
          fileName,
          _pickedImageBytes!,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
      } else if (_pickedImageFile != null) {
        // Mobile upload
        await bucket.uploadBinary(
          fileName,
          await _pickedImageFile!.readAsBytes(),
          fileOptions: FileOptions(
            contentType: 'image/${_pickedImageFile!.path.split('.').last}',
          ),
        );
      } else {
        return null;
      }

      final publicUrl = bucket.getPublicUrl(fileName);
      print('✅ Uploaded image URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Upload failed: $e');
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  /// ✅ Save category
  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    String? imageUrl = _uploadedImageUrl;

    // Upload if new image picked
    if (_pickedImageFile != null || _pickedImageBytes != null) {
      final uploaded = await uploadToSupabase();
      if (uploaded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
        return;
      }
      imageUrl = uploaded;
    }

    bool success;
    if (widget.category == null) {
      success = await ApiService.addCategory(_nameController.text, imageUrl);
    } else {
      final int id = widget.category?['CategoryID'] ?? widget.category?['id'] ?? 0;
      success = await ApiService.updateCategory(id, _nameController.text, imageUrl);
    }

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save category')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: pickImage,
              child: _pickedImageBytes != null
                  ? Image.memory(_pickedImageBytes!, height: 100, width: 100, fit: BoxFit.cover)
                  : _pickedImageFile != null
                      ? Image.file(_pickedImageFile!, height: 100, width: 100, fit: BoxFit.cover)
                      : _uploadedImageUrl != null
                          ? Image.network(_uploadedImageUrl!, height: 100, width: 100, fit: BoxFit.cover)
                          : Container(
                              height: 100,
                              width: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.add_a_photo),
                            ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: save,
          child: Text(widget.category == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
