import 'package:flutter/material.dart';

import '../models/issue_model.dart';
import '../services/firestore_service.dart';
import '../widgets/status_chip.dart';

class JobDetailsScreen extends StatefulWidget {
  final String issueId;

  const JobDetailsScreen({
    super.key,
    required this.issueId,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: FutureBuilder<IssueModel?>(
        future: _firestoreService.getIssue(widget.issueId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final issue = snapshot.data;
          if (issue == null) {
            return const Center(child: Text('Issue not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                issue.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              StatusChip(status: issue.status),
              const SizedBox(height: 16),
              Text(
                'Category: ${issue.category}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Address: ${issue.address}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                issue.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}
