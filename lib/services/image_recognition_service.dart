import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/cloudinary_config.dart';

class ImageRecognitionService {
  final ImagePicker _picker = ImagePicker();
  ImageLabeler? _imageLabeler;

  ImageRecognitionService() {
    _initializeMLKit();
  }

  void _initializeMLKit() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: CloudinaryConfig.maxImageWidth.toDouble(),
        maxHeight: CloudinaryConfig.maxImageHeight.toDouble(),
        imageQuality: CloudinaryConfig.maxImageQuality,
      );
      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<List<ImageLabel>> analyzeImage(File imageFile) async {
    if (_imageLabeler == null) throw Exception('Image labeler not initialized');
    try {
      final inputImage = InputImage.fromFile(imageFile);
      return await _imageLabeler!.processImage(inputImage);
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      return [];
    }
  }

  Future<String?> suggestCategory(File imageFile) async {
    final labels = await analyzeImage(imageFile);
    if (labels.isEmpty) return null;

    final Map<String, List<String>> categoryKeywords = {
      'Plumbing': [
        'pipe',
        'faucet',
        'sink',
        'toilet',
        'drain',
        'water',
        'leak',
      ],
      'Electrical': ['wire', 'socket', 'outlet', 'light', 'switch', 'bulb'],
      'Cleaning': ['dirty', 'stain', 'dust', 'trash', 'garbage'],
      'General Repair': [
        'broken',
        'crack',
        'damage',
        'repair',
        'door',
        'window',
      ],
    };

    Map<String, int> scores = {};

    for (var label in labels) {
      final text = label.label.toLowerCase();
      for (var entry in categoryKeywords.entries) {
        for (var keyword in entry.value) {
          if (text.contains(keyword)) {
            scores[entry.key] =
                (scores[entry.key] ?? 0) + (label.confidence * 10).round();
          }
        }
      }
    }

    if (scores.isEmpty) return 'Other';
    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String getDetectionSummary(List<ImageLabel> labels) {
    if (labels.isEmpty) return 'No specific objects detected';
    return labels
        .take(3)
        .map((l) => '${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)')
        .join(', ');
  }

  Future<String> uploadImage(
    File imageFile,
    String userId,
    String issueId,
  ) async {
    final url =
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload';
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final folder = '${CloudinaryConfig.uploadFolder}/$userId/$issueId';
    final publicId = 'image_${DateTime.now().millisecondsSinceEpoch}';

    final signature = _generateSignature(
      timestamp: timestamp,
      folder: folder,
      publicId: publicId,
    );

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['api_key'] = CloudinaryConfig.apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
    request.fields['folder'] = folder;
    request.fields['public_id'] = publicId;

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(responseData);
      return jsonResponse['secure_url'];
    } else {
      throw Exception('Upload failed: $responseData');
    }
  }

  String _generateSignature({
    required int timestamp,
    required String folder,
    required String publicId,
  }) {
    final paramsToSign =
        'folder=$folder&public_id=$publicId&timestamp=$timestamp${CloudinaryConfig.apiSecret}';
    return sha1.convert(utf8.encode(paramsToSign)).toString();
  }

  // ✅ FIXED: Changed issueId to optional named parameter
  Future<List<String>> uploadMultipleImages(
    List<File> images,
    String userId, {
    String? issueId,
  }) async {
    List<String> urls = [];
    // Use a temporary issueId if none provided
    final uploadIssueId =
        issueId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    for (var img in images) {
      try {
        urls.add(await uploadImage(img, userId, uploadIssueId));
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    return urls;
  }

  void dispose() {
    _imageLabeler?.close();
  }
}
