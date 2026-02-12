import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';

class ImageRecognitionService {
  final ImagePicker _picker = ImagePicker();
  ImageLabeler? _imageLabeler;
  static DateTime? _geminiRateLimitedUntil;
  static DateTime? _modelsFetchedAt;
  static List<String>? _cachedGenerateContentModels;
  static String? _resolvedGeminiModel;
  static final Map<String, GeminiVisionResult> _geminiResultCache = {};
  static final Map<String, Future<GeminiVisionResult?>> _inFlightGemini = {};
  static const Duration _geminiRequestTimeout = Duration(seconds: 25);
  static const Duration _modelListCacheTtl = Duration(minutes: 30);
  static const int _geminiMaxAttemptsPerModel = 2;

  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String get _geminiModel {
    final configuredModel = dotenv.env['GEMINI_MODEL']?.trim() ?? '';
    return configuredModel.isNotEmpty ? configuredModel : 'gemini-2.0-flash';
  }

  static Future<void> logGeminiModelStatus() async {
    if (_geminiApiKey.isEmpty) {
      debugPrint('Gemini check: GEMINI_API_KEY is missing.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_geminiApiBaseUrl?key=$_geminiApiKey'),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Gemini check failed: ${response.statusCode} ${response.body}',
        );
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final models = (json['models'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      final supported = models.where((model) {
        final methods = (model['supportedGenerationMethods'] as List<dynamic>?)
                ?.map((m) => m.toString())
                .toList() ??
            const <String>[];
        return methods.contains('generateContent');
      }).toList();

      final supportedNames = supported
          .map((m) => (m['name'] ?? '').toString().replaceFirst('models/', ''))
          .where((name) => name.isNotEmpty)
          .toSet();

      final preferredOrder = <String>[
        _geminiModel,
        'gemini-2.0-flash',
        'gemini-1.5-flash-latest',
      ];

      final selected = preferredOrder.firstWhere(
        (m) => supportedNames.contains(m),
        orElse: () => '',
      );

      if (selected.isNotEmpty) {
        debugPrint('Gemini check: model available for generateContent: $selected');
      } else {
        debugPrint(
          'Gemini check: no preferred model available. '
          'Set GEMINI_MODEL to one of: ${supportedNames.take(8).join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('Gemini check error: $e');
    }
  }

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

  Future<GeminiVisionResult?> analyzeImageWithGemini(File imageFile) async {
    if (_geminiApiKey.isEmpty) {
      debugPrint('Gemini API key not set. Using ML Kit fallback.');
      return null;
    }

    final now = DateTime.now();
    if (_geminiRateLimitedUntil != null &&
        now.isBefore(_geminiRateLimitedUntil!)) {
      final seconds = _geminiRateLimitedUntil!.difference(now).inSeconds;
      debugPrint(
        'Gemini temporarily paused due to rate limit. '
        'Retrying in about $seconds seconds.',
      );
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final imageHash = sha1.convert(bytes).toString();

      final cached = _geminiResultCache[imageHash];
      if (cached != null) return cached;

      final inFlight = _inFlightGemini[imageHash];
      if (inFlight != null) return await inFlight;

      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);

      final task = _analyzeImageBytesWithGemini(
        imageBytes: bytes,
        mimeType: mimeType,
      );
      _inFlightGemini[imageHash] = task;

      final result = await task;
      if (result != null) {
        _geminiResultCache[imageHash] = result;
      }
      _inFlightGemini.remove(imageHash);
      return result;
    } catch (e) {
      debugPrint('Error calling Gemini Vision API: $e');
      return null;
    }
  }

  Future<GeminiVisionResult?> _analyzeImageBytesWithGemini({
    required List<int> imageBytes,
    required String mimeType,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final modelsToTry = await _resolveCandidateModels();
    var sawRateLimit = false;
    var maxRetryAfterSeconds = 0;

    for (final model in modelsToTry) {
      for (var attempt = 1; attempt <= _geminiMaxAttemptsPerModel; attempt++) {
        final response = await _postGeminiRequest(
          model: model,
          base64Image: base64Image,
          mimeType: mimeType,
        );

        if (response == null) return null;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _resolvedGeminiModel = model;
          debugPrint('Gemini model in use: $model');
          return _parseGeminiResponse(data);
        }

        if (response.statusCode == 404 || _isModelMethodUnsupported(response)) {
          debugPrint('Gemini model not supported: $model');
          break;
        }

        if (response.statusCode == 429) {
          sawRateLimit = true;
          final retryAfterSeconds = _retryAfterSeconds(response);
          if (retryAfterSeconds > maxRetryAfterSeconds) {
            maxRetryAfterSeconds = retryAfterSeconds;
          }
          debugPrint(
            'Gemini rate limit for model $model. Trying next available model.',
          );
          break;
        }

        if (_isRetriableStatus(response.statusCode) &&
            attempt < _geminiMaxAttemptsPerModel) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }

        debugPrint(
          'Gemini API error: ${response.statusCode} (model: $model, attempt: $attempt)',
        );
        debugPrint('Response: ${response.body}');
        break;
      }
    }

    if (sawRateLimit) {
      _geminiRateLimitedUntil = DateTime.now().add(
        Duration(seconds: maxRetryAfterSeconds > 0 ? maxRetryAfterSeconds : 30),
      );
      debugPrint(
        'Gemini rate limited across attempted models. Using ML Kit fallback.',
      );
      return null;
    }

    debugPrint('No compatible Gemini model found. Using ML Kit fallback.');
    return null;
  }

  Future<List<String>> _resolveCandidateModels() async {
    final ordered = <String>[];
    void addModel(String? model) {
      if (model == null || model.trim().isEmpty) return;
      if (!ordered.contains(model)) ordered.add(model);
    }

    addModel(_geminiModel);
    addModel(_resolvedGeminiModel);

    final now = DateTime.now();
    final shouldRefresh = _cachedGenerateContentModels == null ||
        _modelsFetchedAt == null ||
        now.difference(_modelsFetchedAt!) > _modelListCacheTtl;

    if (shouldRefresh) {
      try {
        final response = await http
            .get(Uri.parse('$_geminiApiBaseUrl?key=$_geminiApiKey'))
            .timeout(_geminiRequestTimeout);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final models = (json['models'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>();

          final discovered = <String>[];
          for (final model in models) {
            final name = (model['name'] ?? '')
                .toString()
                .replaceFirst('models/', '')
                .trim();
            final methods =
                (model['supportedGenerationMethods'] as List<dynamic>? ?? const [])
                    .map((m) => m.toString())
                    .toSet();
            if (name.isNotEmpty && methods.contains('generateContent')) {
              discovered.add(name);
            }
          }
          _cachedGenerateContentModels = discovered;
          _modelsFetchedAt = now;
        }
      } catch (_) {
        // Keep fallback list if model discovery fails.
      }
    }

    for (final model in _cachedGenerateContentModels ?? const <String>[]) {
      addModel(model);
    }

    addModel('gemini-2.0-flash');
    addModel('gemini-1.5-flash-latest');
    addModel('gemini-1.5-flash');

    return ordered;
  }

  Future<http.Response?> _postGeminiRequest({
    required String model,
    required String base64Image,
    required String mimeType,
  }) async {
    try {
      return await http
          .post(
            Uri.parse(
              '$_geminiApiBaseUrl/$model:generateContent?key=$_geminiApiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inlineData': {'mimeType': mimeType, 'data': base64Image},
                    },
                    {'text': _buildPrompt()},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'topK': 40,
                'topP': 0.95,
                'maxOutputTokens': 1024,
              },
            }),
          )
          .timeout(_geminiRequestTimeout);
    } catch (_) {
      return null;
    }
  }

  bool _isModelMethodUnsupported(http.Response response) {
    if (response.statusCode != 400 && response.statusCode != 404) return false;
    final body = response.body.toLowerCase();
    return body.contains('not supported for generatecontent') ||
        body.contains('is not found for api version');
  }

  bool _isRetriableStatus(int statusCode) {
    return statusCode == 408 || statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  int _retryAfterSeconds(http.Response response) {
    final retryAfterHeader = response.headers['retry-after'];
    return int.tryParse(retryAfterHeader ?? '') ?? 60;
  }

  String _buildPrompt() {
    return '''You are an expert home repair technician analyzing an image for FixIt.

Analyze the image for a home repair issue and return JSON only.

Categories: Plumbing, Electrical, Cleaning, Carpentry, Painting, General Repair, Appliance Repair, HVAC, Landscaping, Other.

Return exactly:
{
  "objects": ["object1", "object2"],
  "damage": "specific description of damage or 'No obvious damage visible'",
  "category": "one category from the list",
  "description": "one clear sentence describing the repair need",
  "confidence": "high/medium/low"
}

Prefer repair-context terms like exposed wiring, outlet, burn marks, leakage, crack, rust.''';
  }

  GeminiVisionResult? _parseGeminiResponse(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String?;
      if (text == null || text.isEmpty) return null;

      var jsonStr = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (match == null) return null;

      final result = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return GeminiVisionResult(
        objects: List<String>.from(result['objects'] ?? const []),
        damage: (result['damage'] ?? 'No obvious damage visible').toString(),
        category: (result['category'] ?? 'Other').toString(),
        description: (result['description'] ?? 'Unable to determine issue')
            .toString(),
        confidence: (result['confidence'] ?? 'medium').toString(),
      );
    } catch (e) {
      debugPrint('Error parsing Gemini response: $e');
      return null;
    }
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
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
    final geminiResult = await analyzeImageWithGemini(imageFile);
    if (geminiResult != null && geminiResult.category != 'Other') {
      return geminiResult.category;
    }
    return _suggestCategoryWithMLKit(imageFile);
  }

  Future<String?> suggestCategoryWithMLKit(File imageFile) async {
    return _suggestCategoryWithMLKit(imageFile);
  }

  Future<String?> _suggestCategoryWithMLKit(File imageFile) async {
    final labels = await analyzeImage(imageFile);
    if (labels.isEmpty) return null;

    final Map<String, List<String>> categoryKeywords = {
      'Plumbing': ['pipe', 'faucet', 'sink', 'toilet', 'drain', 'water', 'leak'],
      'Electrical': [
        'wire',
        'wiring',
        'cable',
        'socket',
        'outlet',
        'switch',
        'electric',
        'circuit',
        'burn',
        'fire'
      ],
      'Cleaning': ['stain', 'dirt', 'dust', 'grime', 'mold', 'trash'],
      'Carpentry': ['wood', 'door', 'window', 'cabinet', 'furniture'],
      'Painting': ['paint', 'wall', 'ceiling', 'peeling', 'crack'],
      'Appliance Repair': [
        'refrigerator',
        'fridge',
        'oven',
        'washer',
        'dryer',
        'dishwasher'
      ],
      'HVAC': ['air conditioner', 'heater', 'furnace', 'thermostat', 'vent'],
      'Landscaping': ['garden', 'lawn', 'yard', 'plant', 'tree'],
      'General Repair': ['broken', 'damage', 'repair', 'fix', 'hole', 'dent'],
    };

    final scores = <String, double>{};
    for (final label in labels) {
      final text = label.label.toLowerCase();
      for (final entry in categoryKeywords.entries) {
        for (final keyword in entry.value) {
          if (text.contains(keyword) || keyword.contains(text)) {
            scores[entry.key] = (scores[entry.key] ?? 0) + label.confidence;
          }
        }
      }
    }

    if (scores.isEmpty) return 'Other';

    var bestCategory = 'Other';
    var bestScore = 0.0;
    scores.forEach((category, score) {
      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }
    });

    return bestScore > 0.4 ? bestCategory : 'Other';
  }

  Future<String> getSmartDetectionSummary(File imageFile) async {
    final geminiResult = await analyzeImageWithGemini(imageFile);
    if (geminiResult != null) {
      if (geminiResult.damage.isNotEmpty &&
          geminiResult.damage != 'No obvious damage visible') {
        return '${geminiResult.description}\n${geminiResult.damage}';
      }
      return geminiResult.description;
    }

    final labels = await analyzeImage(imageFile);
    return getDetectionSummary(labels);
  }

  String getDetectionSummary(List<ImageLabel> labels) {
    if (labels.isEmpty) return 'No specific objects detected';

    final filteredLabels = labels.where((l) {
      const genericLabels = ['object', 'thing', 'item', 'product', 'goods'];
      return !genericLabels.contains(l.label.toLowerCase());
    }).toList();

    if (filteredLabels.isEmpty) return 'Unable to identify specific objects';

    return filteredLabels
        .take(3)
        .map((l) => '${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)')
        .join(', ');
  }

  Future<String?> getProblemDescription(File imageFile) async {
    final geminiResult = await analyzeImageWithGemini(imageFile);
    return geminiResult?.description;
  }

  Future<List<String>> getDetectedObjects(File imageFile) async {
    final geminiResult = await analyzeImageWithGemini(imageFile);
    if (geminiResult != null && geminiResult.objects.isNotEmpty) {
      return geminiResult.objects;
    }

    final labels = await analyzeImage(imageFile);
    return labels.take(5).map((l) => l.label).toList();
  }

  Future<String?> getDamageDescription(File imageFile) async {
    final geminiResult = await analyzeImageWithGemini(imageFile);
    if (geminiResult != null &&
        geminiResult.damage != 'No obvious damage visible') {
      return geminiResult.damage;
    }
    return null;
  }

  Future<String> uploadImage(File imageFile, String userId, String issueId) async {
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
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(responseData);
      return jsonResponse['secure_url'];
    }

    throw Exception('Upload failed: $responseData');
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

  Future<List<String>> uploadMultipleImages(
    List<File> images,
    String userId, {
    String? issueId,
  }) async {
    final urls = <String>[];
    final uploadIssueId = issueId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    for (final img in images) {
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

class GeminiVisionResult {
  final List<String> objects;
  final String damage;
  final String category;
  final String description;
  final String confidence;

  GeminiVisionResult({
    required this.objects,
    required this.damage,
    required this.category,
    required this.description,
    required this.confidence,
  });

  @override
  String toString() {
    return 'GeminiVisionResult(objects: $objects, damage: $damage, category: $category, description: $description, confidence: $confidence)';
  }

  Map<String, dynamic> toJson() {
    return {
      'objects': objects,
      'damage': damage,
      'category': category,
      'description': description,
      'confidence': confidence,
    };
  }
}
