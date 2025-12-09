import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/login_page.dart';
import 'pages/add_edit_product_page.dart';
import 'pages/categories_page.dart';
import 'pages/subcategories_page.dart';
import 'pages/dashboard_page.dart';
// import 'pages/coupons_page.dart';
import 'pages/notifications_page.dart';
import 'pages/varianttypes_page.dart';
import 'pages/varients_page.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
 HardwareKeyboard.instance.addHandler((event) {
    try {
      return false;
    } catch (e) {
      return false;
    }
  });

  await Supabase.initialize(
    url: 'https://zyryndjeojrzvoubsqsg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5cnluZGplb2pyenZvdWJzcXNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3MzEyOTYsImV4cCI6MjA3MzMwNzI5Nn0.t8cnVhusOVzJRe3YEUFnpp8UtiCvDSnILueuz2hJrls', // your anon key
  );


  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSans', // optional
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AdminLoginPage(),
        '/home': (context) => AdminHomePage(),
        // '/products': (context) => ProductListPage(),
        '/addEdit': (context) => AddEditProductPage(),
        '/categories': (context) => CategoriesPage(),
        '/subcategories': (context) => SubcategoriesPage(),
        '/addProduct': (context) => AddEditProductPage(),
        // '/coupons': (context) => CouponPage(),
        '/notifications': (context) => NotificationPage(),
        '/varianTtypes': (context) => VariantTypesPage(),
        '/varients': (context) => VariantsPage(),
      },
    );
  }
}

