// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:admin_panel/services/api_service.dart';
import 'package:flutter/material.dart';

class VariantsPage extends StatefulWidget {
  const VariantsPage({super.key});



  @override
  State<VariantsPage> createState() => _VariantsPageState();
}

class _VariantsPageState extends State<VariantsPage> {
  List<Map<String, dynamic>> variants = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchVariants();
  }

  Future<void> fetchVariants() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getVariants();
      variants = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      variants = [];
      print('❌ Error fetching variants: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteVariant(int id) async {
    try {
      await ApiService.deleteVariant(id);
      fetchVariants();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  void _openAddEdit([Map<String, dynamic>? variant]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditVariantDialog(variant: variant),
    );
    fetchVariants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Variants Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Variants',
                        style:
                            TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: fetchVariants,
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('New Variant'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: variants.isEmpty
                        ? const Center(child: Text('No variants found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Variant')),
                                  DataColumn(label: Text('Variant Type')),
                                  DataColumn(label: Text('Added Date')),
                                  DataColumn(label: Text('Edit')),
                                  DataColumn(label: Text('Delete')),
                                ],
                                rows: variants.map((variant) {
                                  final id = variant['VariantID'] ?? 0;
                                  return DataRow(cells: [
                                    DataCell(Text(variant['Variant'] ?? '')),
                                    DataCell(Text(variant['VariantType'] ?? '')),
                                    DataCell(Text(variant['AddedDate'] ?? '')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _openAddEdit(variant),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => deleteVariant(id),
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
class AddEditVariantDialog extends StatefulWidget {
  final Map<String, dynamic>? variant;
  const AddEditVariantDialog({super.key, this.variant});

  @override
  State<AddEditVariantDialog> createState() => _AddEditVariantDialogState();
}

class _AddEditVariantDialogState extends State<AddEditVariantDialog> {
  late TextEditingController _variantController;
  List<Map<String, dynamic>> variantTypes = [];
  bool isLoading = true;
  int? selectedTypeId;

  @override
  void initState() {
    super.initState();
    _variantController = TextEditingController(
      text: widget.variant != null ? widget.variant!['Variant'] : '',
    );
    loadVariantTypes();
  }

  Future<void> loadVariantTypes() async {
    try {
      final data = await ApiService.getVariantTypes();
      variantTypes = List<Map<String, dynamic>>.from(data);

      if (widget.variant != null) {
        // find typeId that matches the VariantType name
final match = variantTypes.firstWhere( 
  (t) => t['VariantName'].toString().toLowerCase() ==
         widget.variant!['VariantType'].toString().toLowerCase(),
  orElse: () => {},
);

        if (match.isNotEmpty) {
          selectedTypeId = match['VariantTypeID'];
        }
      }
    } catch (e) {
      variantTypes = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to load types: $e")),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> save() async {
    final name = _variantController.text.trim();
    if (name.isEmpty || selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter name & select type")),
      );
      return;
    }

    try {
      if (widget.variant == null) {
        await ApiService.addVariant(name, selectedTypeId!);
      } else {
        await ApiService.editVariant(
          widget.variant!['VariantID'],
          name,
          selectedTypeId!,
        );
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.variant == null ? 'Add Variant' : 'Edit Variant'),
      content: isLoading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _variantController,
                  decoration: const InputDecoration(labelText: 'Variant Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedTypeId,
                  items: variantTypes.map((type) {
                    return DropdownMenuItem<int>(
                      value: type['VariantTypeID'],
                      child: Text(type['VariantName']),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedTypeId = value),
                  decoration: const InputDecoration(labelText: 'Variant Type'),
                ),
              ],
            ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: isLoading ? null : save,
            child: Text(widget.variant == null ? 'Add' : 'Save')),
      ],
    );
  }
}


// import 'package:flutter/material.dart';
// import '../api_service.dart';

// class VariantsPage extends StatefulWidget {
//   const VariantsPage({super.key});

//   @override
//   State<VariantsPage> createState() => _VariantsPageState();
// }

// class _VariantsPageState extends State<VariantsPage> {
//   List variants = [];
//   List variantTypes = [];
//   bool isLoading = true;
//   int? selectedVariantTypeId;

//   @override
//   void initState() {
//     super.initState();
//     fetchData();
//   }

//   Future<void> fetchData() async {
//     setState(() => isLoading = true);
//     try {
//       variants = await ApiService.getVariants();
//       variantTypes = await ApiService.getVariantTypes();
//       setState(() => isLoading = false);
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Error: $e")));
//     }
//   }

//   void deleteVariant(int id) async {
//     try {
//       await ApiService.deleteVariant(id);
//       fetchData();
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Failed: $e")));
//     }
//   }

//   void showAddEditVariantDialog({Map? variant}) {
//     final TextEditingController variantController =
//         TextEditingController(text: variant != null ? variant['Variant'] : '');
//     selectedVariantTypeId = variant != null ? variant['VariantType'] : null;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(variant == null ? 'Add Variant' : 'Edit Variant'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: variantController,
//               decoration: const InputDecoration(labelText: 'Variant Name'),
//             ),
//             const SizedBox(height: 10),
//             DropdownButtonFormField<int>(
//               value: selectedVariantTypeId,
//               decoration: const InputDecoration(labelText: "Variant Type"),
//               items: variantTypes.map<DropdownMenuItem<int>>((vt) {
//                 return DropdownMenuItem<int>(
//                   // value: vt['VariantTypeID'],
//                   child: Text(vt['VariantName']),
//                 );
//               }).toList(),
//               onChanged: (val) => setState(() => selectedVariantTypeId = val),
//             ),
//           ],
//         ),
// actions: [
//   TextButton(
//     onPressed: () => Navigator.pop(context),
//     child: const Text('Cancel'),
//   ),
//   ElevatedButton(
//     onPressed: () async {
//       final name = variantController.text.trim();
//       if (name.isEmpty || selectedVariantTypeId == null) return;

//       try {
//         if (variant == null) {
//           // Add new variant (no assignment since addVariant returns void)
//           await ApiService.addVariant(name, selectedVariantTypeId!.toString());
//           fetchData(); // reload the list to include the new variant
//         } else {
//           // Edit existing variant
//           await ApiService.editVariant(
//               variant['VariantID'], name, selectedVariantTypeId!.toString());
//           fetchData(); // reload list to reflect updates
//         }

//         Navigator.pop(context); // close the dialog
//       } catch (e) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Failed: $e')));
//       }
//     },
//     child: Text(variant == null ? 'Add' : 'Update'),
//   ),
// ],

//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Variants')),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: DataTable(
//                 columns: const [
//                   DataColumn(label: Text('Variant Name')),
//                   DataColumn(label: Text('Variant Type')),
//                   DataColumn(label: Text('Added Date')),
//                   DataColumn(label: Text('Edit')),
//                   DataColumn(label: Text('Delete')),
//                 ],
//                 rows: variants.map((variant) {
//                   return DataRow(cells: [
//                     // Variant Name
//                     DataCell(Text(variant['Variant'] ?? '')),
//                     // Variant Type Name (directly from backend)
//                     DataCell(Text(variant['VariantType'] ?? 'N/A')),
//                     // Added Date
//                     DataCell(Text(
//                       variant['AddedDate'] != null
//                           ? DateTime.parse(variant['AddedDate'])
//                               .toLocal()
//                               .toString()
//                           : '',
//                     )),
//                     // Edit
//                     DataCell(IconButton(
//                       icon: const Icon(Icons.edit, color: Colors.blue),
//                       onPressed: () => showAddEditVariantDialog(variant: variant),
//                     )),
//                     // Delete
//                     DataCell(IconButton(
//                       icon: const Icon(Icons.delete, color: Colors.red),
//                       onPressed: () => deleteVariant(variant['VariantID']),
//                     )),
//                   ]);
//                 }).toList(),
//               ),
//             ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => showAddEditVariantDialog(),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import '../api_service.dart';

// class VariantsPage extends StatefulWidget {
//   const VariantsPage({super.key});

//   @override
//   State<VariantsPage> createState() => _VariantsPageState();
// }

// class _VariantsPageState extends State<VariantsPage> {
//   List<dynamic> variants = [];
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadVariants();
//   }

//   Future<void> _loadVariants() async {
//     setState(() => isLoading = true);
//     try {
//       variants = await ApiService.getVariants();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load variants: $e')));
//     }
//     setState(() => isLoading = false);
//   }

//   void _addEditVariant([dynamic variant]) async {
//     final isEdit = variant != null;
//     final nameController = TextEditingController(text: isEdit ? variant['VariantName'] : '');
//     final typeController = TextEditingController(text: isEdit ? variant['VariantType'] : '');

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Variant' : 'Add Variant'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Variant Name')),
//             TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Variant Type')),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           ElevatedButton(
//             onPressed: () async {
//               final name = nameController.text.trim();
//               final type = typeController.text.trim();
//               if (name.isEmpty || type.isEmpty) return;

//               try {
//                 if (isEdit) {
//                   await ApiService.updateVariant(variant['VariantID'], name, type);
//                 } else {
//                   await ApiService.addVariant(name, type);
//                 }
//                 Navigator.pop(context);
//                 _loadVariants();
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save variant: $e')));
//               }
//             },
//             child: Text(isEdit ? 'Update' : 'Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _deleteVariant(int id) async {
//     await ApiService.deleteVariant(id);
//     _loadVariants();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Variants'),
//         actions: [
//           IconButton(onPressed: _loadVariants, icon: const Icon(Icons.refresh)),
//           IconButton(onPressed: () => _addEditVariant(), icon: const Icon(Icons.add)),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : variants.isEmpty
//               ? const Center(child: Text('No variants found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columns: const [
//                       DataColumn(label: Text('Variant Name')),
//                       DataColumn(label: Text('Variant Type')),
//                       DataColumn(label: Text('Added Date')),
//                       DataColumn(label: Text('Edit')),
//                       DataColumn(label: Text('Delete')),
//                     ],
//                     rows: variants.map((v) {
//                       return DataRow(cells: [
//                         DataCell(Text(v['VariantName'] ?? '')),
//                         DataCell(Text(v['VariantType'] ?? '')),
//                         DataCell(Text(v['AddedDate'] != null ? v['AddedDate'].split('T')[0] : '')),
//                         DataCell(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addEditVariant(v))),
//                         DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteVariant(v['VariantID']))),
//                       ]);
//                     }).toList(),
//                   ),
//                 ),
//     );
//   }
// }
