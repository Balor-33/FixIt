import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import 'issue_detail_professional.dart';
import 'role_selection_screen.dart';

class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return StreamBuilder<UserModel?>(
      stream: _firestoreService.getUserStream(user.uid),
      builder: (context, userSnap) {
        final userData = userSnap.data;
        final category = userData?.service;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Professional Dashboard'),
            backgroundColor: const Color(0xFF1DB9AA),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await _authService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                      (_) => false,
                    );
                  }
                },
              ),
            ],
          ),
          body: category == null || category.isEmpty
              ? _buildCategoryMissing()
              : _buildBody(user.uid, category),
        );
      },
    );
  }

  Widget _buildCategoryMissing() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Please set your service category in profile to view jobs.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBody(String professionalId, String category) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Available Jobs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _availableJobs(category),

          const SizedBox(height: 24),

          const Text(
            'My Active Jobs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _myJobs(professionalId),
        ],
      ),
    );
  }

  Widget _availableJobs(String category) {
    return StreamBuilder<List<IssueModel>>(
      stream: _firestoreService.getOpenIssuesByCategory(category),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return const Text('No jobs available right now');
        }

        return Column(
          children: jobs.map((issue) {
            return _IssueTile(issue: issue, onTap: () => _openIssue(issue));
          }).toList(),
        );
      },
    );
  }

  Widget _myJobs(String professionalId) {
    return StreamBuilder<List<IssueModel>>(
      stream: _firestoreService.getProfessionalJobs(professionalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!
            .where((e) => e.status != 'completed' && e.status != 'rejected')
            .toList();

        if (jobs.isEmpty) {
          return const Text('No active jobs');
        }

        return Column(
          children: jobs.map((issue) {
            return _IssueTile(issue: issue, onTap: () => _openIssue(issue));
          }).toList(),
        );
      },
    );
  }

  void _openIssue(IssueModel issue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailProfessionalScreen(issue: issue),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final IssueModel issue;
  final VoidCallback onTap;

  const _IssueTile({required this.issue, required this.onTap});

  Color _statusColor() {
    switch (issue.status) {
      case 'open':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'working':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(issue.title),
        subtitle: Text(issue.address),
        trailing: Chip(
          label: Text(issue.status.toUpperCase()),
          backgroundColor: _statusColor().withOpacity(0.15),
          labelStyle: TextStyle(color: _statusColor()),
        ),
      ),
    );
  }
}
