// ignore_for_file: use_build_context_synchronously, avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'package:admin_panel/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  String username = '';
  String password = '';
  bool isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
      Uri.parse('http://10.248.214.36:3001/api/admin/login'),

        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      );

      setState(() => isLoading = false);
      print('🟢 Response: ${response.body}');

      final data = jsonDecode(response.body);

      // ✅ Success condition: checks multiple possibilities
      if (response.statusCode == 200 &&
          (data['success'] == true ||
              data['message'] == "✅ Login successful" ||
              data['message'].toString().contains("Login successful"))) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token'] ?? '');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Login successful')),
        );

        // ✅ Navigate to AdminHomePage
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) =>  AdminHomePage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Invalid username or password')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Username'),
                onChanged: (v) => username = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter username' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (v) => password = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color.fromARGB(255, 17, 17, 17),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Color.fromARGB(255, 243, 236, 236))
                    : const Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class LoginPage extends StatefulWidget {
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _formKey = GlobalKey<FormState>();
//   String username = '';
//   String password = '';
//   bool isLoading = false;

//   Future<void> _login() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => isLoading = true);

//     try {
//       final response = await http.post(
//     Uri.parse('http://10.37.224.36:3000/api/admin/login'),
//   headers: {'Content-Type': 'application/json'},
//   body: jsonEncode({
//     'username': username,
//     'password': password,
//   }),
// );
//       setState(() => isLoading = false);

//       if (response.statusCode == 200) {
//         // ✅ Login success
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Login successful!')),
//         );
        
//         /// ✅ CHANGE THIS:
//         /// Old: Navigator.pushReplacementNamed(context, '/products');
//         /// New:
//         Navigator.pushReplacementNamed(context, '/home');
        
//       } else {
//         // ❌ Invalid credentials
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Invalid username or password')),
//         );
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: ${e.toString()}')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Admin Login')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 decoration: InputDecoration(labelText: 'Username'),
//                 onChanged: (v) => username = v,
//                 validator: (v) =>
//                     v == null || v.trim().isEmpty ? 'Username is required' : null,
//               ),
//               TextFormField(
//                 decoration: InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//                 onChanged: (v) => password = v,
//                 validator: (v) =>
//                     v == null || v.trim().isEmpty ? 'Password is required' : null,
//               ),
//               SizedBox(height: 24),
//               isLoading
//                   ? CircularProgressIndicator()
//                   : SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _login,
//                         child: Text('Login'),
//                       ),
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
