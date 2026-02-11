// customer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';
import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import 'report_issue_screen.dart';
import 'my_issues_screen.dart';
import 'notifications_screen.dart';
import 'role_selection_screen.dart';
import 'chat_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1DB9AA), Color(0xFF4A90E2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(userId: currentUser.uid),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActions(),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Issues',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _RecentIssues(userId: currentUser.uid)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userId;
  const _Header({required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<UserModel?>(
        stream: service.getUserStream(userId),
        builder: (_, snapshot) {
          return Row(
            children: [
              const Text(
                'Welcome 👋',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await AuthService().signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (_) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionCard(
          icon: Icons.add,
          title: 'Report Issue',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
            );
          },
        ),
        const SizedBox(width: 12),
        _ActionCard(
          icon: Icons.list_alt,
          title: 'My Issues',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyIssuesScreen()),
            );
          },
        ),
        const SizedBox(width: 12),
        _ActionCard(
          icon: Icons.notifications,
          title: 'Alerts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _RecentIssues extends StatelessWidget {
  final String userId;
  const _RecentIssues({required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<List<IssueModel>>(
      stream: service.getCustomerIssues(userId),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final issues = snapshot.data!.take(3).toList();

        if (issues.isEmpty) {
          return const Center(child: Text('No issues reported yet'));
        }

        return ListView.builder(
          itemCount: issues.length,
          itemBuilder: (_, i) {
            final issue = issues[i];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  issue.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _StatusChip(status: issue.status),
                    if (issue.assignedProfessionalId != null) ...[
                      const SizedBox(height: 8),
                      _ProfessionalInfo(
                        professionalId: issue.assignedProfessionalId!,
                        issue: issue,
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyIssuesScreen(focusIssueId: issue.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: const Color(0xFF1DB9AA)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'working':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'working':
        return Icons.construction;
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getStatusIcon(), size: 16, color: _getStatusColor()),
        const SizedBox(width: 4),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            color: _getStatusColor(),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfessionalInfo extends StatelessWidget {
  final String professionalId;
  final IssueModel issue;

  const _ProfessionalInfo({required this.professionalId, required this.issue});

  // ✅ Open chat with professional
  Future<void> _openChat(BuildContext context) async {
    final service = FirestoreService();
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) return;

    try {
      // Create or get existing chat room
      final chatRoomId = await service.getOrCreateChatRoom(
        issueId: issue.id!,
        customerId: user.uid,
        professionalId: professionalId,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(chatRoomId: chatRoomId, issueTitle: issue.title),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    // ✅ Check if customer can chat - only if professional has accepted and not rejected/completed
    final canChat =
        issue.assignedProfessionalId != null &&
        issue.status != 'rejected' &&
        issue.status != 'open';

    return FutureBuilder<UserModel?>(
      future: service.getUser(professionalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final professional = snapshot.data!;
        final displayName = professional.displayName ?? professional.email;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1DB9AA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1DB9AA).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with photo or initial
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1DB9AA),
                backgroundImage: professional.photoUrl != null
                    ? NetworkImage(professional.photoUrl!)
                    : null,
                child: professional.photoUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned to',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ✅ Phone number row
                    if (professional.phoneNumber != null &&
                        professional.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 10,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              professional.phoneNumber!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (professional.service != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 10,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              professional.service!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // ✅ Chat button - only show if professional accepted the issue
              if (canChat) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  iconSize: 20,
                  color: const Color(0xFF1DB9AA),
                  onPressed: () => _openChat(context),
                  tooltip: 'Chat with professional',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
