// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_service.dart';


class SubcategoriesPage extends StatefulWidget {
  const SubcategoriesPage({super.key});

  @override
  State<SubcategoriesPage> createState() => _SubcategoriesPageState();
}

class _SubcategoriesPageState extends State<SubcategoriesPage> {
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subcategories = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ---------------------- HELPER FUNCTION ----------------------
String getCategoryName(int? categoryId) {
  if (categoryId == null) return 'Unknown';
  final cat = categories.firstWhere(
    (c) => c['CategoryID'] == categoryId,
    orElse: () => {'Name': 'Unknown'},
  );
  return cat['Name'] ?? cat['CategoryName'] ?? 'Unknown';
}


  // ---------------------- FETCH DATA ----------------------
Future<void> loadData() async {
  setState(() => isLoading = true);
  try {
    categories = await ApiService.getCategories();
    subcategories = [];

    for (var cat in categories) {
      final subs = await ApiService.getSubcategories(cat['CategoryID']);
      subcategories.addAll(
        List<Map<String, dynamic>>.from(subs.map((s) => {
          'SubcategoryID': s['subcategoryId'] ?? s['SubcategoryID'],
          'Name': s['subcategoryName'] ?? s['Name'] ?? 'Unnamed',
          'CategoryID': s['categoryId'] ?? s['CategoryID'],
          'CategoryName': s['categoryName'] ?? s['CategoryName'] ?? 'Unknown',
          'CreatedAt': s['CreatedAt'] ?? 'N/A',
        })),
      );
    }

  } catch (e) {
    categories = [];
    subcategories = [];
    print('❌ Failed to load data: $e');
  }
  setState(() => isLoading = false);
}



  Future<void> deleteSubcategory(int id) async {
    try {
      await ApiService.deleteSubcategory(id);
      loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete subcategory')));
    }
  }

  void _openAddEdit([Map<String, dynamic>? subcategory]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditSubcategoryDialog(
        subcategory: subcategory,
        categories: categories,
      ),
    );
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subcategories Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
child: Column(
  children: [
    Row(
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.blue),
          onPressed: loadData,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _openAddEdit(),
          icon: const Icon(Icons.add),
          label: const Text('New Subcategory'),
        ),
      ],
    ),
    const SizedBox(height: 16),
    Expanded(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : subcategories.isEmpty
              ? const Center(child: Text('No subcategories found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Subcategory Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Added Date')),
                        DataColumn(label: Text('Edit')),
                        DataColumn(label: Text('Delete')),
                      ],
                      rows: subcategories.map((sub) {
                        final id = sub['SubcategoryID'] ?? 0;
                        return DataRow(cells: [
                          DataCell(Text(sub['Name'] ?? 'Unnamed')),
                          DataCell(Text(getCategoryName(sub['CategoryID']))),
                          DataCell(Text(sub['CreatedAt'] ?? 'N/A')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openAddEdit(sub),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteSubcategory(id),
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

// ---------------- ADD / EDIT DIALOG ----------------
class AddEditSubcategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? subcategory;
  final List<Map<String, dynamic>> categories;

  const AddEditSubcategoryDialog({
    super.key,
    this.subcategory,
    required this.categories,
  });

  @override
  State<AddEditSubcategoryDialog> createState() =>
      _AddEditSubcategoryDialogState();
}

class _AddEditSubcategoryDialogState extends State<AddEditSubcategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.subcategory?['Name'] ?? '');
    _selectedCategoryId = widget.subcategory?['CategoryID'];
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    try {
      if (widget.subcategory == null) {
        await ApiService.addSubcategory(_selectedCategoryId!, _nameController.text.trim());
      } else {
        final id = widget.subcategory!['SubcategoryID'] ?? 0;
        await ApiService.updateSubcategory(id, _selectedCategoryId!, _nameController.text.trim());
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to save subcategory')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subcategory == null ? 'Add Subcategory' : 'Edit Subcategory'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Subcategory Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Select Category'),
              items: widget.categories.map((cat) {
                return DropdownMenuItem<int>(
                  value: cat['CategoryID'],
                  child: Text(cat['Name']),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
              validator: (v) => v == null ? 'Please select a category' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: save, child: Text(widget.subcategory == null ? 'Add' : 'Save')),
      ],
    );
  }
}



// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import '../api_service.dart';

// const String baseUrl = 'http://10.0.2.2:3000/api'; // set your API URL

// class SubcategoriesPage extends StatefulWidget {
//   const SubcategoriesPage({Key? key}) : super(key: key);

//   @override
//   State<SubcategoriesPage> createState() => _SubcategoriesPageState();
// }

// class _SubcategoriesPageState extends State<SubcategoriesPage> {
//   List<Map<String, dynamic>> categories = [];
//   List<Map<String, dynamic>> subcategories = [];
//   int? selectedCategoryId;
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     fetchCategories();
//   }

//   Future<void> fetchCategories() async {
//     setState(() => isLoading = true);
//     try {
//       categories = await ApiService.getCategories();
//       if (categories.isNotEmpty) {
//         selectedCategoryId = categories.first['CategoryID'] as int;
//         fetchSubcategories(selectedCategoryId!);
//       } else {
//         subcategories = [];
//       }
//     } catch (e) {
//       categories = [];
//       subcategories = [];
//       print('❌ Failed to fetch categories: $e');
//     }
//     setState(() => isLoading = false);
//   }

//   Future<void> fetchSubcategories(int categoryId) async {
//     setState(() => isLoading = true);
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/subcategories/category/$categoryId'));
//       if (res.statusCode == 200) {
//         final List data = json.decode(res.body);
//         subcategories = data.map((e) => e as Map<String, dynamic>).toList();
//       } else {
//         subcategories = [];
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to fetch subcategories')),
//         );
//       }
//     } catch (e) {
//       subcategories = [];
//       print('❌ Error fetching subcategories: $e');
//     }
//     setState(() => isLoading = false);
//   }

//   void _openAddDialog() async {
//     final result = await showDialog(
//       context: context,
//       builder: (_) => AddEditSubcategoryDialog(
//         categories: categories, // only required parameter
//       ),
//     );
//     if (result == true && selectedCategoryId != null) {
//       fetchSubcategories(selectedCategoryId!);
//     }
//   }

//   void _openEditDialog(Map<String, dynamic> subcategory) async {
//     final result = await showDialog(
//       context: context,
//       builder: (_) => AddEditSubcategoryDialog(
//         subcategory: subcategory,  // named parameter
//         categories: categories,    // named parameter
//       ),
//     );
//     if (result == true && selectedCategoryId != null) {
//       fetchSubcategories(selectedCategoryId!);
//     }
//   }

//   Future<void> deleteSubcategory(int id) async {
//     final ok = await ApiService.deleteSubcategory(id);
//     if (ok && selectedCategoryId != null) {
//       fetchSubcategories(selectedCategoryId!);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to delete subcategory')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 const Text(
//                   'Subcategories',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   icon: const Icon(Icons.refresh),
//                   onPressed: fetchCategories,
//                 ),
//                 ElevatedButton(
//                   onPressed: _openAddDialog,
//                   child: const Text('Add Subcategory'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             if (isLoading)
//               const Center(child: CircularProgressIndicator())
//             else
//               Expanded(
//                 child: subcategories.isEmpty
//                     ? const Center(child: Text('No subcategories found'))
//                     : ListView(
//                         children: subcategories.map((sc) {
//                           final String name = sc['Name'] ?? sc['name'] ?? 'Unnamed';
//                           final int id = sc['SubcategoryID'] ?? sc['id'] ?? 0;
//                           final int categoryId = sc['CategoryID'] ?? sc['categoryId'] ?? 0;

//                           return Card(
//                             child: ListTile(
//                               leading: const Icon(Icons.subdirectory_arrow_right),
//                               title: Text(name),
//                               subtitle: Text('ID: $id | CategoryID: $categoryId'),
//                               trailing: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   IconButton(
//                                     icon: const Icon(Icons.edit),
//                                     onPressed: () => _openEditDialog(sc),
//                                   ),
//                                   IconButton(
//                                     icon: const Icon(Icons.delete),
//                                     onPressed: () => deleteSubcategory(id),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                       ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AddEditSubcategoryDialog extends StatefulWidget {
//   final Map<String, dynamic>? subcategory;
//   final List<Map<String, dynamic>> categories;

//   const AddEditSubcategoryDialog({
//     Key? key,
//     this.subcategory,
//     required this.categories,
//   }) : super(key: key);

//   @override
//   State<AddEditSubcategoryDialog> createState() => _AddEditSubcategoryDialogState();
// }

// class _AddEditSubcategoryDialogState extends State<AddEditSubcategoryDialog> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   int? _selectedCategoryId;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.subcategory?['Name'] ?? '');
//     _selectedCategoryId = widget.subcategory?['CategoryID'];
//   }

//   Future<void> save() async {
//     if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a category')),
//       );
//       return;
//     }

//     bool success;
//     if (widget.subcategory == null) {
//       success = await ApiService.addSubcategory(
//         _selectedCategoryId!,
//         _nameController.text.trim(),
//       );
//     } else {
//       final int id = widget.subcategory!['SubcategoryID'] ?? 0;
//       success = await ApiService.updateSubcategory(
//         id,
//         _selectedCategoryId!,
//         _nameController.text.trim(),
//       );
//     }

//     if (success) {
//       Navigator.pop(context, true);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to save subcategory')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(widget.subcategory == null ? 'Add Subcategory' : 'Edit Subcategory'),
//       content: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextFormField(
//               controller: _nameController,
//               decoration: const InputDecoration(labelText: 'Subcategory Name'),
//               validator: (v) => v == null || v.isEmpty ? 'Required' : null,
//             ),
//             const SizedBox(height: 16),
//             DropdownButtonFormField<int>(
//               value: _selectedCategoryId,
//               decoration: const InputDecoration(labelText: 'Select Category'),
//               items: widget.categories.map((cat) {
//                 return DropdownMenuItem<int>(
//                   value: cat['CategoryID'],
//                   child: Text(cat['Name']),
//                 );
//               }).toList(),
//               onChanged: (val) => setState(() => _selectedCategoryId = val),
//               validator: (v) => v == null ? 'Please select a category' : null,
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context, false),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: save,
//           child: Text(widget.subcategory == null ? 'Add' : 'Save'),
//         ),
//       ],
//     );
//   }
// }
