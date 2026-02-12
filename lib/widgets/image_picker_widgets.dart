import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_recognition_service.dart';
import '../config/app_theme.dart';

class ImagePickerWidget extends StatelessWidget {
  final List<File> selectedImages;
  final Function(File) onImageAdded;
  final Function(int) onImageRemoved;
  final int maxImages;

  const ImagePickerWidget({
    super.key,
    required this.selectedImages,
    required this.onImageAdded,
    required this.onImageRemoved,
    this.maxImages = 5,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    if (selectedImages.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $maxImages images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final imageService = ImageRecognitionService();
    final image = await imageService.pickImage(source: source);

    if (image != null) {
      onImageAdded(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${selectedImages.length}/$maxImages)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildPickerButton(
                context: context,
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => _pickImage(context, ImageSource.camera),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildPickerButton(
                context: context,
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickImage(context, ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (selectedImages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return _buildImageThumbnail(
                  context,
                  selectedImages[index],
                  index,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Supported: JPG, PNG',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
              ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, File image, int index) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Image.file(
              image,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => onImageRemoved(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
