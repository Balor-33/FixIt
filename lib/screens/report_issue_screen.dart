import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../auth_service.dart';
import '../services/firestore_service.dart';
import '../services/image_recognition_service.dart';
import '../models/issue_model.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final ImageRecognitionService _imageRecognitionService =
      ImageRecognitionService();

  String _selectedCategory = 'Plumbing';
  int _emergencyLevel = 1;
  bool _isSubmitting = false;
  bool _isUploading = false;
  bool _isAnalyzing = false;
  final List<File> _selectedImages = [];

  // Store AI detection results
  Map<int, String> _imageDetections = {};
  Map<int, List<ImageLabel>> _imageLabels = {};
  bool _isCategoryAISuggested = false;

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'General Repair',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _imageRecognitionService.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGE PICKER WITH AI RECOGNITION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Source'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sourceButton(Icons.camera_alt, 'Camera', ImageSource.camera),
            _sourceButton(Icons.photo_library, 'Gallery', ImageSource.gallery),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await _pickImage(source);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF4A90E2), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imageRecognitionService.pickImage(source: source);
    if (file != null && mounted) {
      final imageIndex = _selectedImages.length;

      setState(() {
        _selectedImages.add(file);
        _isAnalyzing = true;
      });

      // 🤖 AI Analysis happens here
      await _analyzeImage(file, imageIndex);

      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  /// 🤖 AI MAGIC: Analyzes the image and suggests category
  /// 🔥 NEW: Now asks user to confirm AI suggestion
  Future<void> _analyzeImage(File imageFile, int index) async {
    try {
      // Get AI detection labels
      final labels = await _imageRecognitionService.analyzeImage(imageFile);

      // Get detection summary
      final summary = _imageRecognitionService.getDetectionSummary(labels);

      // Get AI-suggested category
      final suggestedCategory = await _imageRecognitionService.suggestCategory(
        imageFile,
      );

      if (mounted) {
        setState(() {
          _imageLabels[index] = labels;
          _imageDetections[index] = summary;
        });

        // 🔥 AUTO-SELECT ONLY FOR FIRST IMAGE + ASK CONFIRMATION
        if (index == 0 && suggestedCategory != null) {
          _showCategoryConfirmationDialog(suggestedCategory, labels);
        }
      }
    } catch (e) {
      print('Error analyzing image: $e');
    }
  }

  /// 🔥 NEW: Ask user to confirm AI suggestion
  Future<void> _showCategoryConfirmationDialog(
    String suggested,
    List<ImageLabel> labels,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Color(0xFF1DB9AA), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Detected Issue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI thinks this is a:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB9AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1DB9AA), width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(suggested),
                    color: const Color(0xFF1DB9AA),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    suggested,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Is this correct?',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            // Show what AI detected
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected objects:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...labels
                      .take(5)
                      .map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            '• ${label.label} (${(label.confidence * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No, I\'ll choose',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB9AA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Yes, correct!'),
          ),
        ],
      ),
    );

    // Apply AI suggestion only if user confirms
    if (confirmed == true && mounted) {
      setState(() {
        _selectedCategory = suggested;
        _isCategoryAISuggested = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Category set to: $suggested')),
            ],
          ),
          backgroundColor: const Color(0xFF1DB9AA),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Get icon for each category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electrical':
        return Icons.electrical_services;
      case 'Plumbing':
        return Icons.plumbing;
      case 'Cleaning':
        return Icons.cleaning_services;
      case 'General Repair':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageDetections.remove(index);
      _imageLabels.remove(index);

      // Reindex remaining items
      final tempDetections = <int, String>{};
      final tempLabels = <int, List<ImageLabel>>{};

      _imageDetections.forEach((key, value) {
        if (key > index) {
          tempDetections[key - 1] = value;
        } else if (key < index) {
          tempDetections[key] = value;
        }
      });

      _imageLabels.forEach((key, value) {
        if (key > index) {
          tempLabels[key - 1] = value;
        } else if (key < index) {
          tempLabels[key] = value;
        }
      });

      _imageDetections = tempDetections;
      _imageLabels = tempLabels;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // SUBMIT ISSUE (Unchanged)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final issue = IssueModel(
        customerId: currentUser.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        address: _addressController.text.trim(),
        status: 'open',
        emergencyLevel: _emergencyLevel,
        imageUrls: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final issueId = await _firestoreService.createIssue(issue);

      if (_selectedImages.isNotEmpty) {
        setState(() => _isUploading = true);

        final imageUrls = await _imageRecognitionService.uploadMultipleImages(
          _selectedImages,
          currentUser.uid,
          issueId: issueId,
        );

        if (imageUrls.isNotEmpty) {
          await _firestoreService.updateIssue(issueId, {
            'imageUrls': imageUrls,
          });
        }

        setState(() => _isUploading = false);
      }

      print('Issue created with ID: $issueId');

      if (mounted) {
        setState(() => _isSubmitting = false);
        await _showSuccessAnimation();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      print('Error creating issue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showSuccessAnimation() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const _SuccessAnimationDialog(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI BUILD (Rest remains the same as original)
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF1DB9AA), Color(0xFF4A90E2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What needs to be fixed?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildPhotoSection(),
                          const SizedBox(height: 24),
                          _buildTextField(
                            'Title',
                            _titleController,
                            'e.g., Leaking kitchen sink',
                          ),
                          const SizedBox(height: 16),
                          _buildCategoryDropdown(),
                          const SizedBox(height: 16),
                          _buildEmergencyDropdown(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            'Description',
                            _descriptionController,
                            'Provide detailed information about the issue...',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            'Location/Address',
                            _addressController,
                            'e.g., 123 Main St, Apt 4B',
                          ),
                          const SizedBox(height: 30),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (_isAnalyzing) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF1DB9AA)),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '${_selectedImages.length}/5',
              style: const TextStyle(fontSize: 14, color: Color(0xFF718096)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._selectedImages.asMap().entries.map((entry) {
              final hasDetection = _imageDetections.containsKey(entry.key);
              final detection = _imageDetections[entry.key];

              return Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasDetection
                                ? const Color(0xFF1DB9AA)
                                : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: FileImage(entry.value),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (hasDetection)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB9AA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(entry.key),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasDetection && detection != null)
                    Container(
                      width: 96,
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB9AA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        detection,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF2D3748),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            }),
            if (_selectedImages.length < 5)
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4A90E2),
                      width: 2,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 28,
                        color: Color(0xFF4A90E2),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A90E2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_isAnalyzing)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1DB9AA)),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'AI is analyzing image...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF1DB9AA)),
                ),
              ],
            ),
          ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4A90E2)),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Uploading photos...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4A90E2)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            if (_isCategoryAISuggested) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB9AA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'AI Suggested',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
                _isCategoryAISuggested = false;
              });
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4A90E2)),
        ),
      ],
    );
  }

  Widget _buildEmergencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _emergencyLevel,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Low')),
            DropdownMenuItem(value: 2, child: Text('Medium')),
            DropdownMenuItem(value: 3, child: Text('High')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _emergencyLevel = value);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Report an Issue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitIssue,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4A90E2).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'SUBMIT REPORT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

// SUCCESS ANIMATION (Unchanged)
class _SuccessAnimationDialog extends StatefulWidget {
  const _SuccessAnimationDialog();

  @override
  State<_SuccessAnimationDialog> createState() =>
      _SuccessAnimationDialogState();
}

class _SuccessAnimationDialogState extends State<_SuccessAnimationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB9AA),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedBuilder(
                    animation: _checkAnimation,
                    builder: (context, child) => Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 50 * _checkAnimation.value,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your issue has been reported',
                  style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
