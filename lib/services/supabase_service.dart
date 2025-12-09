// ignore_for_file: unnecessary_import

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  /// Upload either a mobile File or web bytes to `bucket`.
  /// Returns the public URL string on success, or null on failure.
  Future<String?> uploadImage({
    required String bucket,
    File? file,
    Uint8List? bytes,
    String? namePrefix,
  }) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = file != null ? file.path.split('.').last : 'png';
      final fileName = '${namePrefix ?? 'poster'}_$ts.$ext';
      final path = fileName; // e.g., posters/poster_123.png

      if (kIsWeb) {
        if (bytes == null) throw Exception('No bytes provided for web upload');
        // ✅ uploadBinary now returns a String path
        await client.storage
            .from(bucket)
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
      } else {
        if (file == null) throw Exception('No file provided for mobile upload');
        // ✅ upload returns a String path
        await client.storage.from(bucket).upload(path, file);
      }

      // ✅ Generate public URL
      final publicUrl = client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e, st) {
      debugPrint('❌ SupabaseService.uploadImage error: $e\n$st');
      return null;
    }
  }
}
