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

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scrollAnimation;
  double _targetScroll = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scrollAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newTarget = _scrollController.offset;
    if ((_targetScroll - newTarget).abs() > 0.1) {
      setState(() {
        _targetScroll = newTarget;
        _scrollAnimation =
            Tween<double>(
              begin: _scrollAnimation.value,
              end: newTarget,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOutCubic,
              ),
            );
      });
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return AnimatedBuilder(
      animation: _scrollAnimation,
      builder: (context, child) {
        final scrollOffset = _scrollAnimation.value;

        // Smooth fade out with cubic easing over 120 pixels
        final fadeProgress = (scrollOffset / 120).clamp(0.0, 1.0);
        final opacity = 1.0 - Curves.easeInCubic.transform(fadeProgress);

        // Smooth slide with overdamped spring feel
        final slideProgress = (scrollOffset / 100).clamp(0.0, 1.0);
        final translateY =
            -100 * Curves.easeInOutCubic.transform(slideProgress);

        // Scale down slightly for depth effect
        final scale = 1.0 - (0.05 * Curves.easeInCubic.transform(fadeProgress));

        return AppScaffold(
          headerHeight: 220,
          header: _CustomerDashboardHeader(userId: currentUser.uid),
          body: Stack(
            children: [
              // Main content with issues list
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic placeholder space that smoothly shrinks
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    height: 200 * opacity,
                  ),
                  const SectionHeader(title: 'Recent Issues'),
                  Expanded(
                    child: _RecentIssues(
                      userId: currentUser.uid,
                      scrollController: _scrollController,
                    ),
                  ),
                ],
              ),
              // Quick actions overlay with smooth transforms
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: opacity < 0.05,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          children: [
                            _QuickActions(),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        final userData = snapshot.data;
        // Use displayName first, then fall back to email
        final displayName =
            userData?.displayName ?? userData?.email ?? 'Welcome';
        final phoneNumber = userData?.phoneNumber;

        // Build subtitle with phone number if available
        final subtitle = phoneNumber != null && phoneNumber.isNotEmpty
            ? '$phoneNumber • Ready to get things fixed?'
            : 'Ready to get things fixed?';

        return Column(
          children: [
            _AnimatedDashboardHero(
              title: displayName,
              subtitle: subtitle,
              label: 'Customer',
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

class _AnimatedDashboardHero extends StatefulWidget {
  final String title;
  final String subtitle;
  final String label;

  const _AnimatedDashboardHero({
    required this.title,
    required this.subtitle,
    required this.label,
  });

  @override
  State<_AnimatedDashboardHero> createState() => _AnimatedDashboardHeroState();
}

class _AnimatedDashboardHeroState extends State<_AnimatedDashboardHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
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
          child: Stack(
            children: [
              // Shimmer effect
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  child: Transform.translate(
                    offset: Offset(_shimmerAnimation.value * 300, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PulsatingBadge(label: widget.label),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _HeroVisualBubble(icon: Icons.person),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsatingBadge extends StatefulWidget {
  final String label;

  const _PulsatingBadge({required this.label});

  @override
  State<_PulsatingBadge> createState() => _PulsatingBadgeState();
}

class _PulsatingBadgeState extends State<_PulsatingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
        );
      },
    );
  }
}

class _HeroVisualBubble extends StatefulWidget {
  final IconData icon;
  const _HeroVisualBubble({required this.icon});

  @override
  State<_HeroVisualBubble> createState() => _HeroVisualBubbleState();
}

class _HeroVisualBubbleState extends State<_HeroVisualBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.1,
          end: -0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.1,
          end: 0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: SizedBox(
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
                      child: Icon(widget.icon, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatefulWidget {
  @override
  State<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<_QuickActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for each card
    _slideAnimations = List.generate(3, (index) {
      final start = index * 0.15;
      final end = start + 0.5;
      return Tween<double>(begin: 50.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _fadeAnimations = List.generate(3, (index) {
      final start = index * 0.15;
      final end = start + 0.5;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionCard(
        icon: Icons.add,
        title: 'Report Issue',
        index: 0,
        slideAnimation: _slideAnimations[0],
        fadeAnimation: _fadeAnimations[0],
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
        index: 1,
        slideAnimation: _slideAnimations[1],
        fadeAnimation: _fadeAnimations[1],
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
        index: 2,
        slideAnimation: _slideAnimations[2],
        fadeAnimation: _fadeAnimations[2],
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
  final ScrollController scrollController;

  const _RecentIssues({required this.userId, required this.scrollController});

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
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'No issues reported yet',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: ListView.builder(
            key: const ValueKey('issues'),
            controller: scrollController,
            itemCount: issues.length,
            itemBuilder: (_, i) {
              final issue = issues[i];
              return _AnimatedIssueCard(issue: issue, index: i);
            },
          ),
        );
      },
    );
  }
}

class _AnimatedIssueCard extends StatefulWidget {
  final IssueModel issue;
  final int index;

  const _AnimatedIssueCard({required this.issue, required this.index});

  @override
  State<_AnimatedIssueCard> createState() => _AnimatedIssueCardState();
}

class _AnimatedIssueCardState extends State<_AnimatedIssueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final delay = widget.index * 0.1;
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, 0.6 + delay, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, 0.6 + delay, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: Matrix4.identity()
                    ..translate(0.0, _isHovered ? -4.0 : 0.0),
                  child: AppCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MyIssuesScreen(focusIssueId: widget.issue.id),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.issue.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        StatusChip(status: widget.issue.status),
                        if (widget.issue.assignedProfessionalId != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _ProfessionalInfo(
                            professionalId:
                                widget.issue.assignedProfessionalId!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int index;
  final Animation<double> slideAnimation;
  final Animation<double> fadeAnimation;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.index,
    required this.slideAnimation,
    required this.fadeAnimation,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _floatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Press animation
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );

    // Floating animation
    _floatController = AnimationController(
      duration: Duration(milliseconds: 2000 + (widget.index * 200)),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.slideAnimation,
        widget.fadeAnimation,
        _floatAnimation,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            widget.slideAnimation.value + _floatAnimation.value,
          ),
          child: Opacity(
            opacity: widget.fadeAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: AnimatedBuilder(
                animation: _pressController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          Transform.scale(
                            scale: _iconScaleAnimation.value,
                            child: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF38BDF8),
                                    Color(0xFF6366F1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.3),
                                    blurRadius: 8 * _iconScaleAnimation.value,
                                    spreadRadius: 2 * _iconScaleAnimation.value,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.icon,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
        final phoneNumber = professional.phoneNumber;

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
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                    ),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phoneNumber,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.grey[600]),
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
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              professional.service!,
                              style: Theme.of(context).textTheme.labelSmall
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
