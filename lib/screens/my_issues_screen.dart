import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import 'edit_issue_screen.dart';
import 'review_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/status_chip.dart';
import '../config/app_theme.dart';

class MyIssuesScreen extends StatelessWidget {
  final String? focusIssueId;
  const MyIssuesScreen({super.key, this.focusIssueId});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Issues')),
      body: StreamBuilder<List<IssueModel>>(
        stream: service.getCustomerIssues(userId),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final issues = snapshot.data!;
          if (issues.isEmpty) {
            return const Center(child: Text('No issues found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: issues.length,
            itemBuilder: (_, i) {
              final issue = issues[i];
              final isFocused = issue.id == focusIssueId;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  onTap: null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFocused
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              StatusChip(status: issue.status),
                            ],
                          ),
                        ),
                        _buildAction(context, issue),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAction(BuildContext context, IssueModel issue) {
    if (issue.status == 'open') {
      return TextButton(
        child: const Text('Edit'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditIssueScreen(issue: issue),
            ),
          );
        },
      );
    }

    if (issue.status == 'completed') {
      return TextButton(
        child: const Text('Review'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(issue: issue),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
