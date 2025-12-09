// // ignore_for_file: depend_on_referenced_packages, avoid_print

// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class  SupabaseAuthService {
//   static const String baseUrl = "http://10.147.77.36:3001/api";

//   static Future<String?> uploadFile(File file) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('auth_token'); // JWT from login

//     final request = http.MultipartRequest(
//       'POST',
//       Uri.parse('$baseUrl/upload'),
//     );

//     request.files.add(await http.MultipartFile.fromPath('file', file.path));

//     // Add JWT if backend requires it
//     if (token != null) {
//       request.headers['Authorization'] = 'Bearer $token';
//     }

//     final response = await request.send();
//     final responseBody = await response.stream.bytesToString();

//     if (response.statusCode == 200) {
//       final data = jsonDecode(responseBody);
//       return data['url']; // Supabase public URL
//     } else {
//       print('❌ Upload failed: $responseBody');
//       return null;
//     }
//   }
// }
