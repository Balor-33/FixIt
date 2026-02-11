import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import 'issue_detail_professional.dart';
import 'role_selection_screen.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import '../widgets/app_card.dart';
import '../widgets/app_scaffold.dart';
import '../config/app_theme.dart';

class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  EdgeInsets _responsivePadding(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width >= 900) {
      return const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    }
    if (width >= 600) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    return const EdgeInsets.all(20);
  }

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
        final displayName = userData?.displayName ?? userData?.email ?? 'Pro';

        return AppScaffold(
          headerHeight: 220,
          header: Column(
            children: [
              _AnimatedProHero(
                title: displayName,
                subtitle: category == null || category.isEmpty
                    ? 'Set your service category to start.'
                    : 'Category: $category',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Welcome back',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
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
    return Center(
      child: AppCard(
        child: Column(
          children: [
            const Icon(Icons.category, size: 48, color: Color(0xFF38BDF8)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set your service category',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Update your profile to start receiving jobs that match your skills.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String professionalId, String category) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        children: [
          const SectionHeader(title: 'Available Jobs'),
          const SizedBox(height: AppSpacing.sm),
          _availableJobs(category),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'My Active Jobs'),
          const SizedBox(height: AppSpacing.sm),
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
          return Text(
            'No jobs available right now',
            style: TextStyle(color: Colors.grey[600]),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: const ValueKey('available'),
            children: jobs.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _IssueTile(issue: issue, onTap: () => _openIssue(issue)),
              );
            }).toList(),
          ),
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
          return Text(
            'No active jobs',
            style: TextStyle(color: Colors.grey[600]),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: const ValueKey('active'),
            children: jobs.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _IssueTile(issue: issue, onTap: () => _openIssue(issue)),
              );
            }).toList(),
          ),
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  issue.address,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusChip(status: issue.status),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AnimatedProHero({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF2563EB)],
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
                  'Professional',
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _ProHeroBubble(),
        ],
      ),
    );
  }
}

class _ProHeroBubble extends StatelessWidget {
  const _ProHeroBubble();

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
            child: const Icon(Icons.handyman, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
