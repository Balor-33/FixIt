import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import 'edit_issue_screen.dart';
import 'review_screen.dart';
import 'chat_screen.dart';
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
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Action button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            _buildAction(context, issue),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Status
                        StatusChip(status: issue.status),

                        // ✅ Professional info — only if assigned
                        if (issue.assignedProfessionalId != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _ProfessionalInfo(
                            professionalId: issue.assignedProfessionalId!,
                            issue: issue,
                          ),
                        ],
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
    // ✅ Show chat button if professional is assigned and issue is accepted/working
    // Chat available once professional accepts (not for 'open' or 'rejected')
    final canChat =
        issue.assignedProfessionalId != null &&
        issue.status != 'open' &&
        issue.status != 'rejected';

    if (canChat) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat button
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Chat with professional',
            onPressed: () => _openChat(context, issue),
          ),
          // Edit button only for open status (this shouldn't happen if canChat is true, but keeping as fallback)
          if (issue.status == 'open')
            TextButton(
              child: const Text('Edit'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditIssueScreen(issue: issue),
                  ),
                );
              },
            ),
        ],
      );
    }

    // Edit button for open issues without professional
    if (issue.status == 'open') {
      return TextButton(
        child: const Text('Edit'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditIssueScreen(issue: issue)),
          );
        },
      );
    }

    // Review button for completed issues
    if (issue.status == 'completed') {
      return TextButton(
        child: const Text('Review'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReviewScreen(issue: issue)),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  // ✅ Centralized chat opening method with error handling
  Future<void> _openChat(BuildContext context, IssueModel issue) async {
    if (issue.assignedProfessionalId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No professional assigned to this issue yet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final service = FirestoreService();
      final chatRoomId = await service.getOrCreateChatRoom(
        issueId: issue.id!,
        customerId: issue.customerId,
        professionalId: issue.assignedProfessionalId!,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 240),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (_, __, ___) =>
                ChatScreen(chatRoomId: chatRoomId, issueTitle: issue.title),
            transitionsBuilder: (_, animation, __, child) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
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
}

// ✅ Fetches and shows professional's displayName + phoneNumber + chat button
class _ProfessionalInfo extends StatelessWidget {
  final String professionalId;
  final IssueModel issue;

  const _ProfessionalInfo({required this.professionalId, required this.issue});

  // ✅ Chat opening method with error handling
  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    // ✅ Check if customer can chat - only if professional has accepted and not rejected/open

    return FutureBuilder<UserModel?>(
      future: service.getUser(professionalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final professional = snapshot.data!;
        final displayName = professional.displayName ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned Professional',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),

                    // ✅ Display Name
                    Text(
                      displayName.isNotEmpty ? displayName : 'Professional',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    // ✅ Phone Number
                    if (professional.phoneNumber != null &&
                        professional.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            professional.phoneNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ✅ Service
                    if (professional.service != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            professional.service!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Single chat entry point is in the issue card header.
            ],
          ),
        );
      },
    );
  }
}

