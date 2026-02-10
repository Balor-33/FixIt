import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import '../services/firestore_service.dart';
import '../widgets/primary_button.dart';
import '../config/app_theme.dart';

class EditIssueScreen extends StatefulWidget {
  final IssueModel issue;
  const EditIssueScreen({super.key, required this.issue});

  @override
  State<EditIssueScreen> createState() => _EditIssueScreenState();
}

class _EditIssueScreenState extends State<EditIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _description;
  late TextEditingController _address;
  late String _category;
  late int _emergencyLevel;

  bool _isSaving = false;

  final _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'General Repair',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.issue.title);
    _description = TextEditingController(text: widget.issue.description);
    _address = TextEditingController(text: widget.issue.address);
    _category = widget.issue.category;
    _emergencyLevel = widget.issue.emergencyLevel;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    await FirestoreService().updateIssue(
      widget.issue.id!,
      {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'category': _category,
        'emergencyLevel': _emergencyLevel,
      },
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.issue.status != 'open') {
      return const Scaffold(
        body: Center(child: Text('This issue can no longer be edited')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Issue')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field('Title', _title),
              _field('Description', _description, maxLines: 4),
              _field('Address', _address),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _category,
                items: _categories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                value: _emergencyLevel,
                decoration:
                    const InputDecoration(labelText: 'Emergency Level'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Low')),
                  DropdownMenuItem(value: 2, child: Text('Medium')),
                  DropdownMenuItem(value: 3, child: Text('High')),
                ],
                onChanged: (v) => setState(() => _emergencyLevel = v!),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
