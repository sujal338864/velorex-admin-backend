import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spec_models.dart';

class SpecBuilderSplitPage extends StatefulWidget {
  const SpecBuilderSplitPage({Key? key}) : super(key: key);

  @override
  State<SpecBuilderSplitPage> createState() => _SpecBuilderSplitPageState();
}

class _SpecBuilderSplitPageState extends State<SpecBuilderSplitPage> {
  bool isLoading = false;
  List<SpecSection> sections = [];
  SpecSection? selectedSection;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.getSpecSectionsWithFields();
      setState(() {
        sections = res;
        if (sections.isNotEmpty) {
          selectedSection ??= sections.first;
        } else {
          selectedSection = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showSectionDialog({SpecSection? section}) async {
    final nameController = TextEditingController(text: section?.name ?? '');
    final sortController =
        TextEditingController(text: section?.sortOrder.toString() ?? '0');
    final isEdit = section != null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Section' : 'Add Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Section Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sortController,
              decoration: const InputDecoration(labelText: 'Sort Order'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;
              if (name.isEmpty) return;

              final ok = isEdit
                  ? await ApiService.updateSpecSection(
                      sectionId: section!.sectionId,
                      name: name,
                      sortOrder: sortOrder,
                    )
                  : await ApiService.createSpecSection(
                      name: name,
                      sortOrder: sortOrder,
                    );

              if (!mounted) return;
              if (ok) {
                Navigator.pop(context);
                await _loadSections();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save section')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSection(SpecSection section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Delete section "${section.name}" and all its fields?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ApiService.deleteSpecSection(section.sectionId);
    if (!mounted) return;
    if (ok) {
      await _loadSections();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete section')),
      );
    }
  }

  Future<void> _showFieldDialog({required SpecSection section, SpecField? field}) async {
    final nameController = TextEditingController(text: field?.name ?? '');
    final sortController =
        TextEditingController(text: field?.sortOrder.toString() ?? '0');
    String inputType = field?.inputType ?? 'text';
    final isEdit = field != null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Field' : 'Add Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Field Name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: inputType,
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Text')),
                DropdownMenuItem(value: 'number', child: Text('Number')),
                DropdownMenuItem(value: 'textarea', child: Text('textarea')),
              ],
              onChanged: (v) => inputType = v ?? 'text',
              decoration: const InputDecoration(labelText: 'Input Type'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sortController,
              decoration: const InputDecoration(labelText: 'Sort Order'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;
              if (name.isEmpty) return;

              final ok = isEdit
                  ? await ApiService.updateSpecField(
                      fieldId: field!.fieldId,
                      sectionId: section.sectionId,
                      name: name,
                      inputType: inputType,
                      sortOrder: sortOrder,
                    )
                  : await ApiService.createSpecField(
                      sectionId: section.sectionId,
                      name: name,
                      inputType: inputType,
                      sortOrder: sortOrder,
                    );

              if (!mounted) return;
              if (ok) {
                Navigator.pop(context);
                await _loadSections();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save field')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteField(SpecField field) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Delete field "${field.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ApiService.deleteSpecField(field.fieldId);
    if (!mounted) return;
    if (ok) {
      await _loadSections();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete field')),
      );
    }
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Sections',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showSectionDialog(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sections.isEmpty
                ? const Center(child: Text('No sections'))
                : ListView.builder(
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final sec = sections[index];
                      final isSelected = selectedSection?.sectionId == sec.sectionId;
                      return ListTile(
                        selected: isSelected,
                        title: Text(sec.name),
                        subtitle: Text('Sort: ${sec.sortOrder}'),
                        onTap: () => setState(() => selectedSection = sec),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showSectionDialog(section: sec),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              onPressed: () => _confirmDeleteSection(sec),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    final sec = selectedSection;
    if (sec == null) {
      return const Center(child: Text('Select a section to manage fields'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sec.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text('(Sort: ${sec.sortOrder})'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showFieldDialog(section: sec),
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sec.fields.isEmpty
                ? const Text('No fields yet for this section')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Field Name')),
                        DataColumn(label: Text('Input Type')),
                        DataColumn(label: Text('Sort')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: sec.fields.map((f) {
                        return DataRow(
                          cells: [
                            DataCell(Text(f.name)),
                            DataCell(Text(f.inputType)),
                            DataCell(Text(f.sortOrder.toString())),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () =>
                                        _showFieldDialog(section: sec, field: f),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    onPressed: () => _confirmDeleteField(f),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Specification Builder - Split View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSections,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isWide
              ? Row(
                  children: [
                    _buildLeftPanel(),
                    Expanded(child: _buildRightPanel()),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 260,
                      child: _buildLeftPanel(),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildRightPanel()),
                  ],
                ),
    );
  }
}
