// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> notifications = [];
  bool isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() => isLoading = true);
    try {
      notifications = await ApiService.getNotifications();
      print('✅ Notifications fetched: ${notifications.length}');
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      notifications = [];
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteNotification(int id) async {
    final ok = await ApiService.deleteNotification(id);
    if (ok) {
      fetchNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Notification deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to delete notification')),
      );
    }
  }

  void _openAddEdit([Map? notification]) async {
    await showDialog(
      context: context,
      builder: (_) => AddEditNotificationDialog(notification: notification),
    );
    fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchNotifications),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Notification'),
            onPressed: () => _openAddEdit(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? const Center(child: Text('No notifications found'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Title')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Created At')),
                          DataColumn(label: Text('Edit')),
                          DataColumn(label: Text('Delete')),
                        ],
                        rows: notifications.map<DataRow>((n) {
                          final id = n['NotificationID'] ?? n['id'] ?? 0;
                          final title = n['Title'] ?? '';
                          final desc = n['Description'] ?? '';
                          final imageUrl = n['ImageUrl'] ?? '';
                          final createdAt = n['CreatedAt'] ?? '';

                          return DataRow(cells: [
                            DataCell(Text(title)),
                            DataCell(SizedBox(width: 150, child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis))),
                            DataCell(imageUrl.isNotEmpty
                                ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                : const Icon(Icons.image_not_supported, color: Colors.grey)),
                            DataCell(Text(createdAt.toString().split(' ')[0])),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openAddEdit(n),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteNotification(id),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class AddEditNotificationDialog extends StatefulWidget {
  final Map? notification;
  const AddEditNotificationDialog({super.key, this.notification});

  @override
  State<AddEditNotificationDialog> createState() => _AddEditNotificationDialogState();
}

class _AddEditNotificationDialogState extends State<AddEditNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? uploadedImageUrl;
  final supabase = Supabase.instance.client;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.notification?['Title'] ?? '';
    _descController.text = widget.notification?['Description'] ?? '';
    uploadedImageUrl = widget.notification?['ImageUrl'];
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.bytes == null) return;

    final fileBytes = result.files.single.bytes!;
    final fileName = 'notifications/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
    try {
      await supabase.storage.from('notifications').uploadBinary(fileName, fileBytes,
          fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('notifications').getPublicUrl(fileName);
      setState(() => uploadedImageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Image uploaded')));
    } catch (e) {
      print('❌ Upload error: $e');
    }
  }

  Future<void> saveNotification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    bool success;
    if (widget.notification == null) {
      success = await ApiService.addNotification(
        _titleController.text,
        _descController.text,
        uploadedImageUrl ?? '',
      );
    } else {
      // Update logic can be added later if your backend supports it
      success = await ApiService.addNotification(
        _titleController.text,
        _descController.text,
        uploadedImageUrl ?? '',
      );
    }

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Failed to save notification')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.notification == null ? 'Add Notification' : 'Edit Notification'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploadImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Upload'),
                  ),
                  const SizedBox(width: 10),
                  if (uploadedImageUrl != null)
                    Image.network(uploadedImageUrl!, width: 50, height: 50, fit: BoxFit.cover),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: isSaving ? null : saveNotification,
          child: isSaving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.notification == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
