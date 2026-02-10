import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import '../services/firestore_service.dart';
import '../auth_service.dart';

class IssueDetailProfessionalScreen extends StatefulWidget {
  final IssueModel issue;

  const IssueDetailProfessionalScreen({super.key, required this.issue});

  @override
  State<IssueDetailProfessionalScreen> createState() =>
      _IssueDetailProfessionalScreenState();
}

class _IssueDetailProfessionalScreenState
    extends State<IssueDetailProfessionalScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      // Update issue status
      await _firestoreService.updateIssue(widget.issue.id!, {
        'status': status,
        'assignedProfessionalId': user.uid,
      });

      // Create notification
      await _firestoreService.createNotification(
        userId: widget.issue.customerId,
        title: 'Issue Update',
        body: 'Your issue "${widget.issue.title}" is now $status',
        type: 'issue_status',
        data: {'issueId': widget.issue.id},
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue $status successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop with result to refresh previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating issue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Details'),
        backgroundColor: const Color(0xFF1DB9AA),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(issue.category, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            _infoRow(Icons.location_on, issue.address),
            _infoRow(Icons.warning, 'Emergency Level: ${issue.emergencyLevel}'),
            _infoRow(Icons.info, 'Status: ${issue.status.toUpperCase()}'),

            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(issue.description),

            const Spacer(),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(issue.status),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    switch (status) {
      case 'open':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () => _updateStatus('accepted'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Accept'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () => _updateStatus('rejected'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ),
          ],
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : () => _updateStatus('working'),
            child: const Text('Start Working'),
          ),
        );

      case 'working':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : () => _updateStatus('completed'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Mark as Completed'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
