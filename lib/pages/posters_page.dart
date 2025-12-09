// ignore_for_file: unnecessary_import, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class PostersPage extends StatefulWidget {
  const PostersPage({super.key});

  @override
  State<PostersPage> createState() => _PostersPageState();
}

class _PostersPageState extends State<PostersPage> {
  List<Map<String, dynamic>> posters = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPosters();
  }

  // ✅ Helper to form full Supabase image URL
  String getPosterImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return "https://zyryndjeojrzvoubsqsg.supabase.co/storage/v1/object/public/poster/$imageUrl";
  }

  Future<void> fetchPosters() async {
    setState(() => isLoading = true);
    try {
      posters = await ApiService.getPosters();
    } catch (e) {
      posters = [];
      debugPrint('Error loading posters: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> deletePoster(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Poster'),
        content: const Text('Are you sure you want to delete this poster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await ApiService.deletePoster(id);
    if (success) {
      fetchPosters();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poster deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posters.isEmpty
              ? const Center(child: Text('No posters found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Posters',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditPosterPage(),
                                ),
                              );
                              fetchPosters();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Poster'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Title')),
                              DataColumn(label: Text('Images')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: posters.map((p) {
                              // ✅ Handle both single and multiple image cases
                              final images = p['imageUrls'] is List
                                  ? p['imageUrls']
                                  : [p['imageUrl'] ?? ''];

                              return DataRow(
                                cells: [
                                  DataCell(Text(p['title'] ?? '')),
                                  DataCell(
                                    Row(
                                      children: images.take(3).map<Widget>((url) {
                                        final fullUrl = getPosterImageUrl(url);
                                        return Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: fullUrl.isNotEmpty
                                              ? Image.network(
                                                  fullUrl,
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.broken_image),
                                                )
                                              : const Icon(Icons.broken_image),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddEditPosterPage(poster: p),
                                              ),
                                            );
                                            fetchPosters();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => deletePoster(p['id']),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class AddEditPosterPage extends StatefulWidget {
  final Map<String, dynamic>? poster;
  const AddEditPosterPage({super.key, this.poster});

  @override
  State<AddEditPosterPage> createState() => _AddEditPosterPageState();
}

class _AddEditPosterPageState extends State<AddEditPosterPage> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  bool isSaving = false;

  File? selectedImageFile; // ✅ single file for mobile
  Uint8List? selectedImageBytes; // ✅ single file for web

  @override
  void initState() {
    super.initState();
    if (widget.poster != null) {
      titleController.text = widget.poster!['title'] ?? '';
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (kIsWeb) {
      selectedImageBytes = await picked.readAsBytes();
    } else {
      selectedImageFile = File(picked.path);
    }
    setState(() {});
  }

  Future<String> uploadPosterImageToSupabase() async {
    final supabase = Supabase.instance.client;
    final bucket = supabase.storage.from('posters');

    final fileName =
        'poster_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'png' : selectedImageFile!.path.split('.').last}';

    if (kIsWeb) {
      await bucket.uploadBinary(
        fileName,
        selectedImageBytes!,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: false),
      );
    } else {
      await bucket.uploadBinary(
        fileName,
        await selectedImageFile!.readAsBytes(),
        fileOptions: FileOptions(
          contentType: 'image/${selectedImageFile!.path.split('.').last}',
          upsert: false,
        ),
      );
    }

    final imageUrl = bucket.getPublicUrl(fileName);
    debugPrint('✅ Uploaded poster to Supabase: $imageUrl');
    return imageUrl;
  }

  Future<void> savePoster() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedImageFile == null && selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() => isSaving = true);
try {
  final title = titleController.text.trim();

  // ✅ Upload image to Supabase
  final imageUrl = await uploadPosterImageToSupabase(); 

  // ✅ Send to backend
  final success = await ApiService.addPoster(
    title: title,
    imageUrl: imageUrl,
  );

  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Poster added successfully!')),
    );
    Navigator.pop(context);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save poster.')),
    );
  }
} catch (e) {
  debugPrint('❌ Error adding poster: $e');
}
}

  @override
  Widget build(BuildContext context) {
    final selectedWidget = kIsWeb
        ? (selectedImageBytes != null
            ? Image.memory(selectedImageBytes!, width: 120, height: 120)
            : null)
        : (selectedImageFile != null
            ? Image.file(selectedImageFile!, width: 120, height: 120)
            : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.poster == null ? 'Add Poster' : 'Edit Poster'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Poster Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Pick Image'),
              ),
              const SizedBox(height: 10),
              if (selectedWidget != null) selectedWidget,
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save),
                label: const Text('Save Poster'),
                onPressed: isSaving ? null : savePoster,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'dart:io';
// import 'package:admin_panel/api_service.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class PostersPage extends StatefulWidget {
//   const PostersPage({super.key});

//   @override
//   State<PostersPage> createState() => _PostersPageState();
// }

// class _PostersPageState extends State<PostersPage> {
//   List<dynamic> posters = [];
//   bool loading = true;

//   @override
//   void initState() {
//     super.initState();
//     loadPosters();
//   }

//   Future<void> loadPosters() async {
//     setState(() => loading = true);
//     try {
//       posters = await ApiService.fetchPosters();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
//     }
//     setState(() => loading = false);
//   }

//   Future<void> addPoster() async {
//     final titleCtrl = TextEditingController();
//     XFile? picked;

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Add Poster"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
//             const SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: () async {
//                 final picker = ImagePicker();
//                 picked = await picker.pickImage(source: ImageSource.gallery);
//               },
//               child: const Text("Pick Image"),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
//           ElevatedButton(
//             onPressed: () async {
//               if (titleCtrl.text.isEmpty || picked == null) return;
//               final success = await ApiService.addPoster(titleCtrl.text, File(picked!.path));
//               if (success) {
//                 Navigator.pop(context);
//                 await loadPosters();
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add poster")));
//               }
//             },
//             child: const Text("Save"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> deletePoster(int id) async {
//     final success = await ApiService.deletePoster(id);
//     if (success) {
//       await loadPosters();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete poster")));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Posters"),
//         actions: [
//           IconButton(onPressed: loadPosters, icon: const Icon(Icons.refresh)),
//           IconButton(onPressed: addPoster, icon: const Icon(Icons.add)),
//         ],
//       ),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : posters.isEmpty
//               ? const Center(child: Text("No posters found"))
//               : ListView.builder(
//                   itemCount: posters.length,
//                   itemBuilder: (context, i) {
//                     final p = posters[i];
//                     return ListTile(
//                       leading: Image.network(p['imageUrl'], width: 50, height: 50, fit: BoxFit.cover),
//                       title: Text(p['title'] ?? 'Untitled'),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => deletePoster(p['id']),
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }




// // ───────────────────────────────
// // ✅ Add / Edit Poster Page
// // ───────────────────────────────
// class AddEditPosterPage extends StatefulWidget {
//   final Map<String, dynamic>? poster;
//   const AddEditPosterPage({super.key, this.poster});

//   @override
//   State<AddEditPosterPage> createState() => _AddEditPosterPageState();
// }

// class _AddEditPosterPageState extends State<AddEditPosterPage> {
//   final _formKey = GlobalKey<FormState>();
//   final titleController = TextEditingController();
//   final descriptionController = TextEditingController();

//   File? imageFile;
//   Uint8List? imageBytes;
//   bool isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.poster != null) {
//       titleController.text = widget.poster!['title'] ?? '';
//       descriptionController.text = widget.poster!['description'] ?? '';
//     }
//   }

//   Future<void> pickImage() async {
//     final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (picked != null) {
//       if (kIsWeb) {
//         final bytes = await picked.readAsBytes();
//         setState(() => imageBytes = bytes);
//       } else {
//         setState(() => imageFile = File(picked.path));
//       }
//     }
//   }

//   Future<String> uploadPosterToSupabase() async {
//     final supabase = Supabase.instance.client;
//     final bucket = supabase.storage.from('posters');
//     final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.png';

//     if (kIsWeb && imageBytes != null) {
//       await bucket.uploadBinary(
//         fileName,
//         imageBytes!,
//         fileOptions: const FileOptions(contentType: 'image/png', upsert: false),
//       );
//     } else if (imageFile != null) {
//       await bucket.uploadBinary(
//         fileName,
//         await imageFile!.readAsBytes(),
//         fileOptions: FileOptions(contentType: 'image/png', upsert: false),
//       );
//     }

//     return bucket.getPublicUrl(fileName);
//   }

//   Future<void> savePoster() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => isSaving = true);
//     try {
//       String? imageUrl = widget.poster?['imageUrl'];
//       if (imageFile != null || imageBytes != null) {
//         imageUrl = await uploadPosterToSupabase();
//       }

//       final data = {
//         'title': titleController.text.trim(),
//         'description': descriptionController.text.trim(),
//         'imageUrl': imageUrl ?? '',
//       };

//       bool success;
//       if (widget.poster != null) {
//         // Update existing poster
//         success = await ApiService.updatePoster(widget.poster!['id'], data);
//       } else {
//         // Create new poster
//         success = await ApiService.uploadPoster(
//           title: data['title']!,
//           description: data['description']!,
//           imageUrl: data['imageUrl']!,
//         );
//       }

//       setState(() => isSaving = false);

//       if (success) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text('Poster saved successfully!')));
//       } else {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text('Failed to save poster')));
//       }
//     } catch (e) {
//       setState(() => isSaving = false);
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.poster == null ? 'Add Poster' : 'Edit Poster')),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Card(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           elevation: 5,
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   ElevatedButton.icon(
//                     onPressed: pickImage,
//                     icon: const Icon(Icons.add_photo_alternate),
//                     label: const Text('Pick Poster Image'),
//                   ),
//                   const SizedBox(height: 10),
//                   if (imageFile != null || imageBytes != null)
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(8),
//                       child: kIsWeb
//                           ? Image.memory(imageBytes!, width: 150, height: 150, fit: BoxFit.cover)
//                           : Image.file(imageFile!, width: 150, height: 150, fit: BoxFit.cover),
//                     )
//                   else if (widget.poster?['imageUrl'] != null)
//                     Image.network(widget.poster!['imageUrl'], width: 150, height: 150, fit: BoxFit.cover),
//                   const SizedBox(height: 20),
//                   TextFormField(
//                     controller: titleController,
//                     decoration: const InputDecoration(labelText: 'Poster Title'),
//                     validator: (value) => value == null || value.isEmpty ? 'Enter a title' : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: descriptionController,
//                     decoration: const InputDecoration(labelText: 'Description'),
//                     validator: (value) => value == null || value.isEmpty ? 'Enter a description' : null,
//                   ),
//                   const SizedBox(height: 20),
//                   SizedBox(
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       icon: isSaving
//                           ? const CircularProgressIndicator(color: Colors.white)
//                           : const Icon(Icons.save),
//                       label: const Text('Save Poster', style: TextStyle(fontSize: 18)),
//                       onPressed: isSaving ? null : savePoster,
//                       style: ElevatedButton.styleFrom(
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
// }
