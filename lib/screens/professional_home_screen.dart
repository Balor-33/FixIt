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
        final displayName = userData?.displayName ?? 'Professional';

        return Scaffold(
          appBar: AppBar(
            title: Text('Welcome, $displayName'),
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

// ✅ Updated _IssueTile — fetches and shows customer displayName
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
    final service = FirestoreService();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Status chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      issue.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: _statusColor().withOpacity(0.12),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Address
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ✅ Customer displayName fetched from Firestore using customerId
              FutureBuilder<UserModel?>(
                future: service.getUser(issue.customerId),
                builder: (context, snapshot) {
                  final customerName =
                      snapshot.data?.displayName ??
                      snapshot.data?.email ??
                      'Unknown Customer';

                  return Row(
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(0xFF1DB9AA),
                        child: Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Posted by: $customerName',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1DB9AA),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
