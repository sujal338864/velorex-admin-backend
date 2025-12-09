// ignore_for_file: avoid_print, file_names, use_build_context_synchronously

import 'package:admin_panel/services/api_service.dart';
import 'package:flutter/material.dart';


class VariantTypesPage extends StatefulWidget {
  const VariantTypesPage({super.key});

  @override
  State<VariantTypesPage> createState() => _VariantTypesPageState();
}

class _VariantTypesPageState extends State<VariantTypesPage> {
  List<Map<String, dynamic>> variantTypes = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchVariantTypes();
  }

Future<void> fetchVariantTypes() async {
  setState(() => isLoading = true);
  try {
    final data = await ApiService.getVariantTypes();
    variantTypes = List<Map<String, dynamic>>.from(data);
  } catch (e) {
    variantTypes = [];
    print('❌ Error fetching variant types: $e');
  }
  setState(() => isLoading = false);
}


Future<void> deleteVariantType(int id) async {
  try {
    await ApiService.deleteVariantType(id); // just await
    fetchVariantTypes(); // refresh after success
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}

  void _openAddEdit([Map<String, dynamic>? vt]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditVariantTypeDialog(variantType: vt),
    );
    fetchVariantTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Variant Types Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Variant Types',
                        style:
                            TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: fetchVariantTypes,
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('New Variant Type'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: variantTypes.isEmpty
                        ? const Center(child: Text('No variant types found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Variant Name')),
                                  DataColumn(label: Text('Variant Type')),
                                  DataColumn(label: Text('Added Date')),
                                  DataColumn(label: Text('Edit')),
                                  DataColumn(label: Text('Delete')),
                                ],
                                rows: variantTypes.map((vt) {
                                final id = vt['VariantTypeID'];

                                  return DataRow(cells: [
                                    DataCell(Text(vt['VariantName']?.toString() ?? '')),
DataCell(Text(vt['VariantType']?.toString() ?? '')),
DataCell(Text(
  vt['AddedDate'] != null
      ? vt['AddedDate'].toString().substring(0, 10)
      : '',
)),


                                    DataCell(IconButton(
                                      icon:
                                          const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _openAddEdit(vt),
                                    )),
                                    DataCell(IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => deleteVariantType(id),
                                    )),
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
class AddEditVariantTypeDialog extends StatefulWidget {
  final Map<String, dynamic>? variantType;
  const AddEditVariantTypeDialog({super.key, this.variantType});

  @override
  State<AddEditVariantTypeDialog> createState() =>
      _AddEditVariantTypeDialogState();
}

class _AddEditVariantTypeDialogState extends State<AddEditVariantTypeDialog> {
  late TextEditingController _nameController;
  late TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.variantType != null ? widget.variantType!['VariantName'] : '');
    _typeController = TextEditingController(
        text: widget.variantType != null ? widget.variantType!['VariantType'] : '');
  }

  Future<void> save() async {
    final name = _nameController.text.trim();
    final type = _typeController.text.trim();
    if (name.isEmpty || type.isEmpty) return;

    try {
      if (widget.variantType == null) {
        await ApiService.addVariantType(name, type);
      } else {
        await ApiService.editVariantType(widget.variantType!['VariantTypeID'], name, type);
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.variantType == null ? 'Add Variant Type' : 'Edit Variant Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Variant Name'),
          ),
          TextField(
            controller: _typeController,
            decoration: const InputDecoration(labelText: 'Variant Type'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: save, child: Text(widget.variantType == null ? 'Add' : 'Save')),
      ],
    );
  }
}


// import 'package:flutter/material.dart';
// import '../api_service.dart';

// class VariantTypesPage extends StatefulWidget {
//   const VariantTypesPage({super.key});

//   @override
//   State<VariantTypesPage> createState() => _VariantTypesPageState();
// }

// class _VariantTypesPageState extends State<VariantTypesPage> {
//   List<Map<String, dynamic>> variantTypes = [];
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => isLoading = true);
//     try {
//       variantTypes = await ApiService.getVariantTypes();
//     } catch (e) {
//       debugPrint('Error loading variant types: $e');
//     }
//     if (mounted) setState(() => isLoading = false);
//   }

//   // Add/Edit Variant Type with Variants
//   void _addEditVariantType([Map<String, dynamic>? vt]) async {
//     final isEdit = vt != null;
//     final typeController = TextEditingController(text: isEdit ? vt['VariantType'] : '');
//     List<String> variants = isEdit
//         ? List<String>.from(vt['Variants'] ?? [])
//         : [];

//     final variantController = TextEditingController();

//     await showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setStateDialog) => AlertDialog(
//           title: Text(isEdit ? 'Edit Variant Type' : 'Add Variant Type'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: typeController,
//                 decoration: const InputDecoration(labelText: 'Variant Type'),
//               ),
//               const SizedBox(height: 10),
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: variantController,
//                       decoration: const InputDecoration(labelText: 'Add Variant'),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.add, color: Colors.green),
//                     onPressed: () {
//                       final vName = variantController.text.trim();
//                       if (vName.isEmpty) return;
//                       setStateDialog(() {
//                         variants.add(vName);
//                         variantController.clear();
//                       });
//                     },
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               if (variants.isNotEmpty)
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 4,
//                   children: variants
//                       .map((v) => Chip(
//                             label: Text(v),
//                             onDeleted: () => setStateDialog(() => variants.remove(v)),
//                           ))
//                       .toList(),
//                 ),
//             ],
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//             ElevatedButton(
//               onPressed: () async {
//                 final typeName = typeController.text.trim();
//                 if (typeName.isEmpty) return;

//                 try {
//                   if (isEdit) {
//                     await ApiService.updateVariantType(vt!['VariantTypeID'], typeName);
//                     // Update variants
//                     for (var v in variants) {
//                       if (!(vt['Variants'] as List).contains(v)) {
//                         await ApiService.addVariantByType(vt['VariantTypeID'], v);
//                       }
//                     }
//                   } else {
//                     final success = await ApiService.addVariantType(typeName);
//                     if (success) {
//                       final newList = await ApiService.getVariantTypes();
//                       final newType = newList.last;
//                       for (var v in variants) {
//                         await ApiService.addVariantByType(newType['VariantTypeID'], v);
//                       }
//                     }
//                   }
//                   Navigator.pop(context);
//                   _loadData();
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Failed to save: $e')),
//                   );
//                 }
//               },
//               child: Text(isEdit ? 'Update' : 'Add'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Delete Variant Type
//   void _deleteVariantType(int id) async {
//     try {
//       await ApiService.deleteVariantType(id);
//       _loadData();
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
//     }
//   }

//   // Delete individual Variant
//   void _deleteVariant(int typeId, String variantName) async {
//     try {
//       await ApiService.deleteVariantByType(typeId, variantName);
//       _loadData();
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Failed to delete variant: $e')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Variant Types'),
//         actions: [
//           IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
//           IconButton(onPressed: () => _addEditVariantType(), icon: const Icon(Icons.add)),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : variantTypes.isEmpty
//               ? const Center(child: Text('No variant types found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columns: const [
//                       DataColumn(label: Text('Variant Type')),
//                       DataColumn(label: Text('Variants')),
//                       DataColumn(label: Text('Added Date')),
//                       DataColumn(label: Text('Edit')),
//                       DataColumn(label: Text('Delete')),
//                     ],
//                     rows: variantTypes.map((vt) {
//                       final typeId = vt['VariantTypeID'];
//                       final typeName = vt['VariantType'];
//                       final addedDate = vt['AddedDate']?.toString().split(' ')[0] ?? '';
//                       final variants = List<String>.from(vt['Variants'] ?? []);

//                       return DataRow(cells: [
//                         DataCell(Text(typeName)),
//                         DataCell(Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: variants
//                               .map((v) => Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Text(v),
//                                       IconButton(
//                                         icon: const Icon(Icons.delete, size: 18, color: Colors.red),
//                                         onPressed: () => _deleteVariant(typeId, v),
//                                       ),
//                                     ],
//                                   ))
//                               .toList(),
//                         )),
//                         DataCell(Text(addedDate)),
//                         DataCell(IconButton(
//                           icon: const Icon(Icons.edit, color: Colors.blue),
//                           onPressed: () => _addEditVariantType(vt),
//                         )),
//                         DataCell(IconButton(
//                           icon: const Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => _deleteVariantType(typeId),
//                         )),
//                       ]);
//                     }).toList(),
//                   ),
//                 ),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import '../api_service.dart';

// class VariantTypesPage extends StatefulWidget {
//   const VariantTypesPage({super.key});

//   @override
//   State<VariantTypesPage> createState() => _VariantTypesPageState();
// }

// class _VariantTypesPageState extends State<VariantTypesPage> {
//   List<Map<String, dynamic>> variantTypes = [];
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     fetchAll();
//   }

//   Future<void> fetchAll() async {
//     setState(() => isLoading = true);
//     try {
//       variantTypes = await ApiService.getVariantTypes();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//     if (!mounted) return;
//     setState(() => isLoading = false);
//   }

//   Future<void> deleteVariantType(int id) async {
//     final ok = await ApiService.deleteVariantType(id);
//     if (ok) {
//       fetchAll();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to delete variant type')),
//       );
//     }
//   }

//   Future<void> _openAddEdit([Map<String, dynamic>? variantType]) async {
//     await showDialog(
//       context: context,
//       builder: (_) => AddEditVariantTypeDialog(variantType: variantType),
//     );
//     fetchAll();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Variant Types'),
//         actions: [
//           IconButton(
//             onPressed: () => _openAddEdit(),
//             icon: const Icon(Icons.add),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: variantTypes.length,
//               itemBuilder: (_, index) {
//                 final variantType = variantTypes[index];
//                 return ListTile(
//                   title: Text(variantType['VariantTypeName'] ?? ''),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.edit),
//                         onPressed: () => _openAddEdit(variantType),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete),
//                         onPressed: () => deleteVariantType(
//                           variantType['VariantTypeID'] ?? variantType['id'],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }


// class AddEditVariantTypeDialog extends StatefulWidget {
//   final Map<String, dynamic>? variantType;

//   const AddEditVariantTypeDialog({super.key, this.variantType});

//   @override
//   State<AddEditVariantTypeDialog> createState() => _AddEditVariantTypeDialogState();
// }

// class _AddEditVariantTypeDialogState extends State<AddEditVariantTypeDialog> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(
//       text: widget.variantType?['VariantTypeName'] ?? '',
//     );
//   }

//   Future<void> save() async {
//     if (!_formKey.currentState!.validate()) return;

//     final success = widget.variantType == null
//         ? await ApiService.addVariantType(name: _nameController.text)
//         : await ApiService.updateVariantType(
//             id: widget.variantType?['VariantTypeID'] ?? widget.variantType?['id'],
//             name: _nameController.text,
//           );

//     if (success) {
//       Navigator.pop(context);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to save variant type')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(widget.variantType == null ? 'Add Variant Type' : 'Edit Variant Type'),
//       content: Form(
//         key: _formKey,
//         child: TextFormField(
//           controller: _nameController,
//           decoration: const InputDecoration(labelText: 'Variant Type Name'),
//           validator: (v) => v == null || v.isEmpty ? 'Required' : null,
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: save,
//           child: Text(widget.variantType == null ? 'Add' : 'Save'),
//         ),
//       ],
//     );
//   }
// }
