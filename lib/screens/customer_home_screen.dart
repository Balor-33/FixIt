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
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import '../config/app_theme.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return AppScaffold(
      headerHeight: 220,
      header: _CustomerDashboardHeader(userId: currentUser.uid),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickActions(),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Recent Issues'),
          Expanded(child: _RecentIssues(userId: currentUser.uid)),
        ],
      ),
    );
  }
}

class _CustomerDashboardHeader extends StatelessWidget {
  final String userId;
  const _CustomerDashboardHeader({required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<UserModel?>(
      stream: service.getUserStream(userId),
      builder: (_, snapshot) {
        final displayName =
            snapshot.data?.displayName ?? snapshot.data?.email ?? 'Welcome';
        return Column(
          children: [
            _AnimatedDashboardHero(
              title: displayName,
              subtitle: 'Ready to get things fixed?',
              label: 'Customer',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
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
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedDashboardHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String label;

  const _AnimatedDashboardHero({
    required this.title,
    required this.subtitle,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF2563EB),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _HeroVisualBubble(icon: Icons.flash_on),
        ],
      ),
    );
  }
}

class _HeroVisualBubble extends StatelessWidget {
  final IconData icon;
  const _HeroVisualBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 700) {
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: actions,
          );
        }
        return Row(
          children: [
            Expanded(child: actions[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: actions[1]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: actions[2]),
          ],
        );
      },
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
          return Center(
            child: Text(
              'No issues reported yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: ListView.builder(
            key: const ValueKey('issues'),
            itemCount: issues.length,
            itemBuilder: (_, i) {
              final issue = issues[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyIssuesScreen(focusIssueId: issue.id),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StatusChip(status: issue.status),
                      if (issue.assignedProfessionalId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _ProfessionalInfo(
                          professionalId: issue.assignedProfessionalId!,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
              ),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfessionalInfo extends StatelessWidget {
  final String professionalId;
  const _ProfessionalInfo({required this.professionalId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return FutureBuilder<UserModel?>(
      future: service.getUser(professionalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final professional = snapshot.data!;
        final displayName = professional.displayName ?? professional.email;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
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
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned to',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (professional.service != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              professional.service!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
