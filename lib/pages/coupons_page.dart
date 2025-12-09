import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  List<Map<String, dynamic>> coupons = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCoupons();
  }

  Future<void> loadCoupons() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getCoupons();
      setState(() {
        coupons = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Failed to load coupons: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void openAddCouponForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCouponForm()),
    );

    if (result == true) loadCoupons();
  }

  Future<void> deleteCoupon(int id) async {
    final success = await ApiService.deleteCoupon(id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coupon deleted')),
      );
      loadCoupons();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete coupon')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coupons"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddCouponForm,
        icon: const Icon(Icons.add),
        label: const Text("Add New Coupon"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : coupons.isEmpty
              ? const Center(child: Text("No coupons found"))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Coupon Code")),
                      DataColumn(label: Text("Status")),
                      DataColumn(label: Text("Amount")),
                      DataColumn(label: Text("Valid Date")),
                      DataColumn(label: Text("Edit")),
                      DataColumn(label: Text("Delete")),
                    ],
                    rows: coupons.map((coupon) {
                      final id = coupon['CouponID'];
                      final code = coupon['Code'];
                      final status = coupon['Status'];
                      final amount = coupon['DiscountAmount'];
                      final start = coupon['StartDate'];
                      final end = coupon['EndDate'];

                      return DataRow(
                        cells: [
                          DataCell(Text(code.toString())),
                          DataCell(Text(status.toString())),
                          DataCell(Text(amount.toString())),
                          DataCell(Text("$start → $end")),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddCouponForm(editCoupon: coupon),
                                  ),
                                ).then((value) {
                                  if (value == true) loadCoupons();
                                });
                              },
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteCoupon(id),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}

class AddCouponForm extends StatefulWidget {
  final Map<String, dynamic>? editCoupon;
  const AddCouponForm({super.key, this.editCoupon});

  @override
  State<AddCouponForm> createState() => _AddCouponFormState();
}

class _AddCouponFormState extends State<AddCouponForm> {
  final _formKey = GlobalKey<FormState>();

  String couponCode = "";
  String discountType = "Fixed";
  double discountAmount = 0.0;
  double minimumPurchase = 0.0;
  String status = "Active";

  DateTime? startDate;
  DateTime? endDate;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadEditData();
  }

  void loadEditData() {
    if (widget.editCoupon == null) return;

    final c = widget.editCoupon!;
    couponCode = c["Code"] ?? "";
    discountType = c["DiscountType"] ?? "Fixed";
    discountAmount = (c["DiscountAmount"] ?? 0).toDouble();
    minimumPurchase = (c["MinimumPurchase"] ?? 0).toDouble();
    status = c["Status"] ?? "Active";

    startDate = DateTime.tryParse(c["StartDate"] ?? "");
    endDate = DateTime.tryParse(c["EndDate"] ?? "");
  }

  Future<void> pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => startDate = d);
  }

  Future<void> pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => endDate = d);
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start & end dates")),
      );
      return;
    }

    setState(() => isSaving = true);

    bool success;
    final formattedStart = DateFormat("yyyy-MM-dd").format(startDate!);
    final formattedEnd = DateFormat("yyyy-MM-dd").format(endDate!);

    if (widget.editCoupon == null) {
      success = await ApiService.addCoupon(
        code: couponCode,
        discountType: discountType,
        discountAmount: discountAmount,
        minimumPurchase: minimumPurchase,
        startDate: formattedStart,
        endDate: formattedEnd,
        status: status,
      );
    } else {
      success = await ApiService.updateCoupon(
        id: widget.editCoupon!["CouponID"],
        code: couponCode,
        discountType: discountType,
        discountAmount: discountAmount,
        minimumPurchase: minimumPurchase,
        startDate: formattedStart,
        endDate: formattedEnd,
        status: status,
        categoryId: null,
        subcategoryId: null,
        productId: null,
      );
    }

    if (!mounted) return;

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save coupon")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.editCoupon == null ? "Add Coupon" : "Edit Coupon")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: "Coupon Code"),
                  initialValue: couponCode,
                  onChanged: (v) => couponCode = v,
                  validator: (v) =>
                      v == null || v.isEmpty ? "Required" : null,
                ),

                DropdownButtonFormField(
                  value: discountType,
                  decoration:
                      const InputDecoration(labelText: "Discount Type"),
                  items: const [
                    DropdownMenuItem(value: "Fixed", child: Text("Fixed Amount")),
                    DropdownMenuItem(
                        value: "Percentage", child: Text("Percentage %")),
                  ],
                  onChanged: (v) => setState(() => discountType = v!),
                ),

                TextFormField(
                  decoration:
                      const InputDecoration(labelText: "Discount Amount"),
                  initialValue: discountAmount.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      discountAmount = double.tryParse(v) ?? 0.0,
                ),

                TextFormField(
                  decoration:
                      const InputDecoration(labelText: "Minimum Purchase"),
                  initialValue: minimumPurchase.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      minimumPurchase = double.tryParse(v) ?? 0.0,
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(startDate == null
                        ? "Start Date: Not selected"
                        : "Start: ${DateFormat("yyyy-MM-dd").format(startDate!)}"),
                    TextButton(onPressed: pickStart, child: const Text("Pick"))
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(endDate == null
                        ? "End Date: Not selected"
                        : "End: ${DateFormat("yyyy-MM-dd").format(endDate!)}"),
                    TextButton(onPressed: pickEnd, child: const Text("Pick"))
                  ],
                ),

                DropdownButtonFormField(
                  value: status,
                  decoration: const InputDecoration(labelText: "Status"),
                  items: const [
                    DropdownMenuItem(value: "Active", child: Text("Active")),
                    DropdownMenuItem(value: "Expired", child: Text("Expired")),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : const Text("Save Coupon"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
