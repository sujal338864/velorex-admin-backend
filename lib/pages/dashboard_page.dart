// ignore_for_file: deprecated_member_use, use_build_context_synchronously, use_key_in_widget_constructors

import 'package:admin_panel/pages/coupons_page.dart';
import 'package:admin_panel/pages/full_analytics_page.dart';
import 'package:admin_panel/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:admin_panel/services/api_service.dart';
import 'package:admin_panel/pages/add_edit_product_page.dart';
import 'package:admin_panel/pages/brands_page.dart';
import 'package:admin_panel/pages/categories_page.dart';
import 'package:admin_panel/pages/notifications_page.dart';
import 'package:admin_panel/pages/orders_page.dart';
import 'package:admin_panel/pages/posters_page.dart';
import 'package:admin_panel/pages/subcategories_page.dart';
import 'package:admin_panel/pages/variantTypes_page.dart';
import 'package:admin_panel/pages/varients_page.dart';
import 'package:admin_panel/pages/spec_builder_table_page.dart';
import 'package:admin_panel/pages/bulk_product_upload_page.dart';

class AdminHomePage extends StatefulWidget {
  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  // Scroll controllers (FIXED ERROR)
  final ScrollController _productScrollController = ScrollController();
  final ScrollController _ordersScrollController = ScrollController();

  // ---------- TITLES ----------
  final List<String> _titles = [
    'Dashboard',
    'Categories',
    'SubCategories',
    'Brands',
    'Variant Types',
    'Variants',
    'Orders',
    'Posters',
    'Notifications',
    'SpecBuilder',
    'BulkProductUpload',
    'CouponPage',
  ];

  // ---------- STATIC PAGES ----------
  final List<Widget> _staticPages = [
    CategoriesPage(),
    SubcategoriesPage(),
    BrandsPage(),
    VariantTypesPage(),
    VariantsPage(),
    AdminOrdersPage(),
    PostersPage(),
    CouponPage(),
    NotificationPage(),
    SpecBuilderSplitPage(),
    BulkUploadPage(),
  ];

  // ---------- DATA ----------
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  List<dynamic> orders = [];

  bool isLoading = false;

  // product stats
  int totalProducts = 0;
  int inStockCount = 0;
  int lowStockCount = 0;
  int outOfStockCount = 0;

  // order stats
  int totalOrders = 0;
  int pendingOrders = 0;
  int processingOrders = 0;
  int shippedOrders = 0;
  int cancelledOrders = 0;
  double totalRevenue = 0;

  // filters
  String _productFilter = 'ALL';
  String _orderFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  // ---------- LOAD DATA ----------
  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    try {
      products = await ApiService.getProducts();
      orders = await AdminOrderService.getAllOrders();

      _recalculateStats();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      products = [];
      orders = [];
      _recalculateStats();
    }
    setState(() => isLoading = false);
  }

 void _recalculateStats() {
  // PRODUCTS
  totalProducts = products.length;
  inStockCount = 0;
  lowStockCount = 0;
  outOfStockCount = 0;

  for (final p in products) {
    final dyn = p['stock'];
    final stock =
        dyn is num ? dyn.toInt() : int.tryParse('$dyn') ?? 0;

    if (stock <= 0) {
      outOfStockCount++;
    } else if (stock <= 5) {
      lowStockCount++;
    } else {
      inStockCount++;
    }
  }

  // ORDERS (based on items)
  totalOrders = 0;
  pendingOrders = 0;
  processingOrders = 0;
  shippedOrders = 0;
  cancelledOrders = 0;
  totalRevenue = 0;

  for (final o in orders) {
    totalOrders++;

    final status =
        (o['orderItemStatus'] ?? o['status'] ?? '').toString().toLowerCase().trim();

    final qDyn = o['quantity'] ?? 1;
    final pDyn = o['price'] ?? 0;

    final qty = qDyn is num ? qDyn.toInt() : int.tryParse('$qDyn') ?? 1;
    final price = pDyn is num ? pDyn.toDouble() : double.tryParse('$pDyn') ?? 0;

    totalRevenue += qty * price;

    // ---------- FIXED STATUS HANDLING ----------
    if (status.contains('pending')) {
      pendingOrders++;
    }
    else if (status.contains('process') || status.contains('packing') || status.contains('packed')) {
      processingOrders++;
    }
    else if (
        status.contains('ship') ||
        status.contains('shipped') ||
        status.contains('out for delivery') ||
        status.contains('delivery') ||
        status.contains('delivered') ||
        status.contains('dispatch') ||
        status.contains('dispatched') ||
        status.contains('on the way') ||
        status.contains('transit') ||
        status.contains('courier')
    ) {
      shippedOrders++;
    }
    else if (status.contains('cancel')) {
      cancelledOrders++;
    }
  }

  _applyProductFilter(_productFilter, recalcOnly: true);
}

  // ---------- FILTERS ----------
  void _applyProductFilter(String key, {bool recalcOnly = false}) {
    _productFilter = key;

    List<dynamic> base = List.from(products);

    switch (key) {
      case 'INSTOCK':
        base = base.where((p) {
          final s = p['stock'];
          final stock = s is num ? s.toInt() : int.tryParse('$s') ?? 0;
          return stock > 5;
        }).toList();
        break;

      case 'LOWSTOCK':
        base = base.where((p) {
          final s = p['stock'];
          final stock = s is num ? s.toInt() : int.tryParse('$s') ?? 0;
          return stock > 0 && stock <= 5;
        }).toList();
        break;

      case 'OUTOFSTOCK':
        base = base.where((p) {
          final s = p['stock'];
          final stock = s is num ? s.toInt() : int.tryParse('$s') ?? 0;
          return stock <= 0;
        }).toList();
        break;
    }

    filteredProducts = base;
    if (!recalcOnly) setState(() {});
  }

  void _applyOrderFilter(String key) {
    setState(() => _orderFilter = key);
  }

  List<dynamic> get _filteredOrders {
    if (_orderFilter == 'ALL') return orders;

    return orders.where((o) {
      final status = (o['orderItemStatus'] ?? '').toString().toLowerCase();

      if (_orderFilter == 'PENDING') return status.contains('pending');
      if (_orderFilter == 'PROCESSING') return status.contains('process');
      if (_orderFilter == 'SHIPPED') return status.contains('ship');
      if (_orderFilter == 'CANCELLED') return status.contains('cancel');

      return true;
    }).toList();
  }

  // ---------- UI HELPERS ----------
  String _getTitle() => _titles[_selectedIndex];

  void _onSelectPage(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) fetchAllData();
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      tileColor: _selectedIndex == index ? Colors.blue.shade700 : null,
      onTap: () => _onSelectPage(index),
    );
  }

  // ---------- DASHBOARD UI ----------
  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // -------------------- TOP CARDS --------------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSummaryCards()),
                      const SizedBox(width: 16),
                      _buildRightButtons(),
                    ],
                  ),

                 

                  // -------------------- BAR CHART --------------------
                  // Card(
                  //   elevation: 2,
                  //   shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12)),
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(16),
                  //     child: SizedBox(height: 220, child: _buildStockBarChart()),
                  //   ),
                  // ),

                  const SizedBox(height: 24),

                  // -------------------- TABLE + ORDERS --------------------
                  SizedBox(
                    height: 480,
                    child: Row(
                      children: [
                        Expanded(flex: 7, child: _buildProductTableCard()),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _buildOrdersCard()),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  // ---------- SUMMARY CARDS ----------
  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DashboardCard(
                title: 'Total Products',
                value: '$totalProducts',
                color: Colors.blue,
                onTap: () => _applyProductFilter('ALL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'In Stock',
                value: '$inStockCount',
                color: Colors.green,
                onTap: () => _applyProductFilter('INSTOCK'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'Low Stock (≤5)',
                value: '$lowStockCount',
                color: Colors.orange,
                onTap: () => _applyProductFilter('LOWSTOCK'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'Out of Stock',
                value: '$outOfStockCount',
                color: Colors.red,
                onTap: () => _applyProductFilter('OUTOFSTOCK'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardCard(
                title: 'Total Order Items',
                value: '$totalOrders',
                color: Colors.indigo,
                onTap: () => _applyOrderFilter('ALL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'Pending Items',
                value: '$pendingOrders',
                color: Colors.amber,
                onTap: () => _applyOrderFilter('PENDING'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'Shipped Items',
                value: '$shippedOrders',
                color: Colors.teal,
                onTap: () => _applyOrderFilter('SHIPPED'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCard(
                title: 'Cancelled Items',
                value: '$cancelledOrders',
                color: Colors.grey,
                onTap: () => _applyOrderFilter('CANCELLED'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- RIGHT BUTTONS ----------
  Widget _buildRightButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          onPressed: fetchAllData,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.pie_chart_outline),
          label: const Text('View Summary'),
          onPressed: _showSummaryDialog,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.analytics),
          label: const Text('Full Analytics'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullAnalyticsPage(
                  totalProducts: totalProducts,
                  inStock: inStockCount,
                  lowStock: lowStockCount,
                  outOfStock: outOfStockCount,
                  totalOrders: totalOrders,
                  pending: pendingOrders,
                  processing: processingOrders,
                  shipped: shippedOrders,
                  cancelled: cancelledOrders,
                  totalRevenue: totalRevenue,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

 // ---------- PRODUCT TABLE CARD WITH SEARCH ----------
Widget _buildProductTableCard() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- TOP ROW ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              // ---------- SEARCH BAR ----------
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search products...",
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (query) {
                    query = query.toLowerCase();

                    setState(() {
                      filteredProducts = products.where((p) {
                        final name = (p['name'] ?? '').toString().toLowerCase();
                        final category =
                            (p['categoryName'] ?? '').toString().toLowerCase();
                        final sub =
                            (p['subcategoryName'] ?? '').toString().toLowerCase();

                        return name.contains(query) ||
                            category.contains(query) ||
                            sub.contains(query);
                      }).toList();
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ---------- FILTER BUTTONS ----------
          Row(
            children: [
              TextButton(
                onPressed: () => _applyProductFilter('ALL'),
                child: Text(
                  'All',
                  style: TextStyle(
                    fontWeight:
                        _productFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _applyProductFilter('INSTOCK'),
                child: Text(
                  'In Stock',
                  style: TextStyle(
                    fontWeight: _productFilter == 'INSTOCK'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _applyProductFilter('LOWSTOCK'),
                child: Text(
                  'Low Stock',
                  style: TextStyle(
                    fontWeight: _productFilter == 'LOWSTOCK'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _applyProductFilter('OUTOFSTOCK'),
                child: Text(
                  'Out of Stock',
                  style: TextStyle(
                    fontWeight: _productFilter == 'OUTOFSTOCK'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditProductPage()),
                  );
                  fetchAllData();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---------- PRODUCT TABLE ----------
          Expanded(child: _buildProductTable()),
        ],
      ),
    ),
  );
}

  // ---------- PRODUCT TABLE ----------
Widget _buildProductTable() {
  final list = filteredProducts;

  if (list.isEmpty) {
    return const Center(child: Text('No products for this filter'));
  }

  return Scrollbar(
    thumbVisibility: true,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1000,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 16,
            dataRowHeight: 70,
            headingRowHeight: 56,
            columns: const [
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Subcategory')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Actions')),
            ],
            rows: list.map((product) {
              // get a valid image
              List imgs = product['images'] ?? product['imageUrls'] ?? [];
              String img = imgs.isNotEmpty
                  ? imgs[0]
                  : "https://via.placeholder.com/80?text=No+Image";

              return DataRow(
                cells: [
                  // PRODUCT IMAGE + NAME
                  DataCell(
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            img,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            product['name'] ?? "",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  DataCell(Text(product['categoryName'] ?? '')),
                  DataCell(Text(product['subcategoryName'] ?? '')),
                  DataCell(Text(product['price']?.toString() ?? '')),
                  DataCell(Text(
                    product['stock']?.toString() ?? '0',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  )),

                  // ACTION BUTTONS
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditProductPage(
                                productId: product['id'],
                              ),
                            ),
                          );
                          fetchAllData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteProduct(product['id']),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

  // ---------- ORDERS CARD ----------
  Widget _buildOrdersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders & Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _orderFilter == 'ALL',
                  onSelected: (_) => _applyOrderFilter('ALL'),
                ),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _orderFilter == 'PENDING',
                  onSelected: (_) => _applyOrderFilter('PENDING'),
                ),
                ChoiceChip(
                  label: const Text('Processing'),
                  selected: _orderFilter == 'PROCESSING',
                  onSelected: (_) => _applyOrderFilter('PROCESSING'),
                ),
                ChoiceChip(
                  label: const Text('Shipped'),
                  selected: _orderFilter == 'SHIPPED',
                  onSelected: (_) => _applyOrderFilter('SHIPPED'),
                ),
                ChoiceChip(
                  label: const Text('Cancelled'),
                  selected: _orderFilter == 'CANCELLED',
                  onSelected: (_) => _applyOrderFilter('CANCELLED'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text('Revenue: ₹${totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(),

            const Text('Recent Order Items',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            Expanded(child: _buildOrdersList()),

            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('View All Orders'),
                onPressed: () => _onSelectPage(6),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ---------- ORDERS LIST ----------
  Widget _buildOrdersList() {
    final list = _filteredOrders.take(10).toList();

    if (list.isEmpty) {
      return const Center(child: Text('No orders for this filter'));
    }

    return Scrollbar(
      controller: _ordersScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _ordersScrollController,
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (context, index) {
          final o = list[index];

          final id = o['orderId'] ?? '';
          final quantity = o['quantity'] ?? 1;
          final price = (o['price'] ?? 0).toDouble();
          final total = price * quantity;

          final status = (o['orderItemStatus'] ?? '').toString();
          final created = (o['createdAt'] ?? '').toString();

          return ListTile(
            dense: true,
            title: Text('Order #$id • x$quantity',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '₹${total.toStringAsFixed(2)} • $status\n$created',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

  // ---------- BAR CHART ----------
  Widget _buildStockBarChart() {
    if (totalProducts == 0) {
      return const Center(child: Text('No data'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String label = '';
                if (value == 0) label = 'In Stock';
                if (value == 1) label = 'Low';
                if (value == 2) label = 'Out';
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(label),
                );
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: inStockCount.toDouble(), width: 26),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: lowStockCount.toDouble(), width: 26),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: outOfStockCount.toDouble(), width: 26),
          ]),
        ],
      ),
    );
  }

  // ---------- DELETE PRODUCT ----------
  Future<void> deleteProduct(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    final success = await ApiService.deleteProduct(id);
    if (success) {
      fetchAllData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product deleted')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete')));
    }
  }

  // ---------- SUMMARY DIALOG ----------
  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Summary'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Products', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Total: $totalProducts'),
            Text('In Stock: $inStockCount'),
            Text('Low Stock: $lowStockCount'),
            Text('Out Of Stock: $outOfStockCount'),
            const SizedBox(height: 12),
            const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Total Items: $totalOrders'),
            Text('Pending: $pendingOrders'),
            Text('Processing: $processingOrders'),
            Text('Shipped: $shippedOrders'),
            Text('Cancelled: $cancelledOrders'),
            Text('Revenue: ₹${totalRevenue.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // -------- SIDEBAR --------
          Container(
            width: 240,
            color: Colors.blue.shade800,
            child: Column(
              children: [
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  color: Colors.blue.shade900,
                  child: const Text(
                    'Admin Panel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                      _buildNavItem(Icons.category, 'Categories', 1),
                      _buildNavItem(Icons.subdirectory_arrow_right, 'SubCategories', 2),
                      _buildNavItem(Icons.branding_watermark, 'Brands', 3),
                      _buildNavItem(Icons.view_module, 'Variant Types', 4),
                      _buildNavItem(Icons.widgets, 'Variants', 5),
                      _buildNavItem(Icons.receipt_long, 'Orders', 6),
                      _buildNavItem(Icons.image, 'Posters', 7),
                      _buildNavItem(Icons.file_upload, ' Coupons', 8),
                      _buildNavItem(Icons.notifications, 'Notifications', 9),
                      _buildNavItem(Icons.list_alt, 'SpecBuilder', 10),
                      _buildNavItem(Icons.file_upload, 'BulkProductUpload', 11),
                     
                     
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -------- MAIN CONTENT --------
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.grey[200],
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: _selectedIndex == 0
                      ? _buildDashboard()
                      : _staticPages[_selectedIndex - 1],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- DASHBOARD CARD ----------
class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      card = InkWell(onTap: onTap, child: card);
    }

    return card;
  }
}
