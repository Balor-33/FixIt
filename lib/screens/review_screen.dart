import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../config/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final IssueModel issue;
  const ReviewScreen({super.key, required this.issue});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitReview() async {
    setState(() => _submitting = true);

    await FirestoreService().updateIssue(
      widget.issue.id!,
      {
        'rating': _rating,
        'review': _reviewController.text.trim(),
      },
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.issue.status != 'completed') {
      return const Scaffold(
        body: Center(child: Text('Review available after completion')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate the Professional',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _rating = i + 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Review',
                hintText: 'Write your experience...',
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Submit Review',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submitReview,
            ),
          ],
        ),
      ),
    );
  }
}
