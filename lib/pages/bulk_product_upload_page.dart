import 'dart:io';

import 'package:admin_panel/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BulkUploadPage extends StatefulWidget {
  const BulkUploadPage({super.key});

  @override
  State<BulkUploadPage> createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends State<BulkUploadPage> {
  bool uploading = false;
  String? lastResult;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      uploading = true;
      lastResult = null;
    });

    bool ok = false;
    if (kIsWeb) {
      final file = result.files.first;
      ok = await ApiService.uploadBulkProductsBytes(
        file.bytes!,
        file.name,
      );
    } else {
      final path = result.files.single.path;
      if (path != null) {
        ok = await ApiService.uploadBulkProductsFile(File(path));
      }
    }

    setState(() {
      uploading = false;
      lastResult = ok ? "✅ Upload successful" : "❌ Upload failed";
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lastResult!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bulk Product Upload")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: uploading ? null : _pickAndUpload,
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(uploading ? "Uploading..." : "Select Excel & Upload"),
            ),
            const SizedBox(height: 16),
            if (lastResult != null) Text(lastResult!),
          ],
        ),
      ),
    );
  }
}
