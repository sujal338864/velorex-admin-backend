// product_spec_editor_page.dart
// A generic specification editor for ANY product (parent OR child)

import 'package:flutter/material.dart';
import 'package:admin_panel/services/api_service.dart';
import 'package:admin_panel/models/spec_models.dart';

class ProductSpecEditorPage extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductSpecEditorPage({
    Key? key,
    required this.productId,
    required this.productName,
  }) : super(key: key);

  @override
  State<ProductSpecEditorPage> createState() => _ProductSpecEditorPageState();
}

class _ProductSpecEditorPageState extends State<ProductSpecEditorPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<SpecSection> _sections = [];

  /// fieldId -> controller
  final Map<int, TextEditingController> _controllersByFieldId = {};

  @override
  void initState() {
    super.initState();
    _loadTemplateAndValues();
  }

  @override
  void dispose() {
    for (final c in _controllersByFieldId.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplateAndValues() async {
    try {
      setState(() => _isLoading = true);

      // 1) Get sections + fields
      final sections = await ApiService.getSpecSectionsWithFields();

      // 2) Get existing values for THIS product (parent or child)
      final existingMap =
          await ApiService.getProductSpecs(widget.productId); // Map<int, String>

      // 3) Build controllers
      for (final sec in sections) {
        for (final field in sec.fields) {
          final existingValue = existingMap[field.fieldId] ?? '';
          _controllersByFieldId[field.fieldId] =
              TextEditingController(text: existingValue);
        }
      }

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load specifications: $e')),
      );
    }
  }

  Future<void> _saveSpecs() async {
    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> specsToSave = [];

      for (final sec in _sections) {
        for (final field in sec.fields) {
          final ctrl = _controllersByFieldId[field.fieldId];
          if (ctrl == null) continue;

          final val = ctrl.text.trim();
          if (val.isEmpty) {
            // we skip empty ones, backend already ignores empties too
            continue;
          }

          specsToSave.add({
            'fieldId': field.fieldId,
            'value': val,
          });
        }
      }

      final ok = await ApiService.saveProductSpecs(
        productId: widget.productId,
        specs: specsToSave,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Specifications saved')),
        );
        Navigator.pop(context, true); // return "true" to refresh caller if needed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save specifications')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // Decide input widget based on field.inputType
  Widget _buildFieldInput(SpecField field, TextEditingController controller) {
    final type = field.inputType.toLowerCase();

    TextInputType keyboardType = TextInputType.text;
    int maxLines = 1;

    if (type == 'number' || type == 'int' || type == 'decimal') {
      keyboardType = TextInputType.number;
    } else if (type == 'longtext' ||
        type == 'textarea' ||
        type == 'multiline') {
      maxLines = 3;
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: field.name,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Specifications • ${widget.productName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? const Center(
                  child: Text(
                    'No specification sections configured.\n'
                    'Go to Specification Builder to create sections & fields.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final sec = _sections[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sec.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (sec.fields.isEmpty)
                                const Text(
                                  'No fields in this section.',
                                  style: TextStyle(color: Colors.grey),
                                )
                              else
                                Column(
                                  children: sec.fields.map((field) {
                                    final ctrl = _controllersByFieldId[field.fieldId]!;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10.0),
                                      child: _buildFieldInput(field, ctrl),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSpecs,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Specifications',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
