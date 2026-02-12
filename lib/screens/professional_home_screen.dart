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
        final phoneNumber = userData?.phoneNumber;

        // Build subtitle with phone and category
        String subtitle;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          if (category == null || category.isEmpty) {
            subtitle = phoneNumber;
          } else {
            subtitle = '$phoneNumber • $category';
          }
        } else {
          subtitle = category == null || category.isEmpty
              ? 'Set your service category to start.'
              : 'Category: $category';
        }

        return AppScaffold(
          headerHeight: 220,
          header: Column(
            children: [
              _AnimatedProHero(title: displayName, subtitle: subtitle),
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
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.category,
                      size: 48,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Set your service category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(String professionalId, String category) {
    return RefreshIndicator(
      onRefresh: () async {},
      color: const Color(0xFF38BDF8),
      child: ListView(
        children: [
          _buildSectionHeader(
            context,
            'Available Jobs',
            Icons.work_outline,
            const Color(0xFF38BDF8),
          ),
          const SizedBox(height: AppSpacing.md),
          _availableJobs(category),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionHeader(
            context,
            'My Active Jobs',
            Icons.assignment_turned_in_outlined,
            const Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.md),
          _myJobs(professionalId),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _availableJobs(String category) {
    return StreamBuilder<List<IssueModel>>(
      stream: _firestoreService.getOpenIssuesByCategory(category),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            ),
          );
        }

        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No jobs available',
            subtitle: 'Check back later for new opportunities',
            color: const Color(0xFF38BDF8),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Column(
            key: const ValueKey('available'),
            children: jobs.asMap().entries.map((entry) {
              final index = entry.key;
              final issue = entry.value;
              return _AnimatedIssueTile(
                issue: issue,
                index: index,
                onTap: () => _openIssue(issue),
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
          );
        }

        final jobs = snapshot.data!
            .where((e) => e.status != 'completed' && e.status != 'rejected')
            .toList();

        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No active jobs',
            subtitle: 'Accepted jobs will appear here',
            color: const Color(0xFF6366F1),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Column(
            key: const ValueKey('active'),
            children: jobs.asMap().entries.map((entry) {
              final index = entry.key;
              final issue = entry.value;
              return _AnimatedIssueTile(
                issue: issue,
                index: index,
                onTap: () => _openIssue(issue),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Icon(icon, size: 48, color: color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
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

class _AnimatedIssueTile extends StatefulWidget {
  final IssueModel issue;
  final int index;
  final VoidCallback onTap;

  const _AnimatedIssueTile({
    required this.issue,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedIssueTile> createState() => _AnimatedIssueTileState();
}

class _AnimatedIssueTileState extends State<_AnimatedIssueTile>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _hoverController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    final delay = widget.index * 0.08;
    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
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

    // Hover animation
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onHoverExit() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _hoverController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: MouseRegion(
                onEnter: (_) => _onHoverEnter(),
                onExit: (_) => _onHoverExit(),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.grey.shade50],
                      ),
                      border: Border.all(
                        color: _isHovered
                            ? const Color(0xFF38BDF8).withOpacity(0.4)
                            : Colors.grey.withOpacity(0.15),
                        width: _isHovered ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? const Color(0xFF38BDF8).withOpacity(0.2)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: _isHovered ? 24 : 12,
                          offset: Offset(0, _isHovered ? 8 : 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onTap,
                        child: Stack(
                          children: [
                            // Gradient accent on hover
                            if (_isHovered)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 4,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF38BDF8),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Status indicator bar
                                      Container(
                                        width: 4,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: _getStatusGradient(
                                            widget.issue.status,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Title with icon
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        _getCategoryColorGradient(
                                                          widget.issue.category,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    _getCategoryIcon(
                                                      widget.issue.category,
                                                    ),
                                                    size: 18,
                                                    color:
                                                        _getCategoryIconColor(
                                                          widget.issue.category,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    widget.issue.title,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),

                                            // Address
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.location_on,
                                                    size: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    widget.issue.address,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            // Status chip
                                            StatusChip(
                                              status: widget.issue.status,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Arrow button
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        tween: Tween(
                                          begin: 0.0,
                                          end: _isHovered ? 1.0 : 0.0,
                                        ),
                                        builder: (context, value, child) {
                                          return Transform.translate(
                                            offset: Offset(value * 4, 0),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: _isHovered
                                                    ? const LinearGradient(
                                                        colors: [
                                                          Color(0xFF38BDF8),
                                                          Color(0xFF6366F1),
                                                        ],
                                                      )
                                                    : null,
                                                color: _isHovered
                                                    ? null
                                                    : Colors.grey.shade100,
                                                boxShadow: _isHovered
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(
                                                            0xFF38BDF8,
                                                          ).withOpacity(0.4),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward,
                                                size: 20,
                                                color: _isHovered
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),

                                  // Customer info section
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.grey.withOpacity(0.2),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _CustomerInfo(
                                    customerId: widget.issue.customerId,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  LinearGradient _getStatusGradient(String status) {
    switch (status) {
      case 'open':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
        );
      case 'accepted':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        );
      case 'working':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        );
      case 'completed':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
        );
    }
  }

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();

    // Plumbing related
    if (categoryLower.contains('plumb')) {
      return Icons.plumbing;
    }
    if (categoryLower.contains('pipe') || categoryLower.contains('leak')) {
      return Icons.water_drop;
    }
    if (categoryLower.contains('drain') || categoryLower.contains('sink')) {
      return Icons.kitchen;
    }

    // Electrical related
    if (categoryLower.contains('electric') ||
        categoryLower.contains('wiring')) {
      return Icons.electrical_services;
    }
    if (categoryLower.contains('light') || categoryLower.contains('bulb')) {
      return Icons.lightbulb_outline;
    }
    if (categoryLower.contains('power') || categoryLower.contains('outlet')) {
      return Icons.power;
    }
    if (categoryLower.contains('fan') ||
        categoryLower.contains('ceiling fan')) {
      return Icons.air;
    }

    // Carpentry & Woodwork
    if (categoryLower.contains('carpen') || categoryLower.contains('wood')) {
      return Icons.carpenter;
    }
    if (categoryLower.contains('door')) {
      return Icons.door_front_door;
    }
    if (categoryLower.contains('window')) {
      return Icons.window;
    }
    if (categoryLower.contains('furniture') ||
        categoryLower.contains('cabinet')) {
      return Icons.chair;
    }
    if (categoryLower.contains('floor')) {
      return Icons.layers;
    }

    // Painting & Decoration
    if (categoryLower.contains('paint')) {
      return Icons.format_paint;
    }
    if (categoryLower.contains('wall') && !categoryLower.contains('repair')) {
      return Icons.wallpaper;
    }
    if (categoryLower.contains('decor')) {
      return Icons.palette;
    }

    // Cleaning Services
    if (categoryLower.contains('clean')) {
      return Icons.cleaning_services;
    }
    if (categoryLower.contains('wash') || categoryLower.contains('laundry')) {
      return Icons.local_laundry_service;
    }
    if (categoryLower.contains('pest') || categoryLower.contains('bug')) {
      return Icons.pest_control;
    }

    // Gardening & Outdoor
    if (categoryLower.contains('garden') || categoryLower.contains('lawn')) {
      return Icons.grass;
    }
    if (categoryLower.contains('tree') || categoryLower.contains('plant')) {
      return Icons.park;
    }
    if (categoryLower.contains('landscap')) {
      return Icons.nature;
    }

    // HVAC & Climate
    if (categoryLower.contains('ac') ||
        categoryLower.contains('air condition')) {
      return Icons.ac_unit;
    }
    if (categoryLower.contains('heat') || categoryLower.contains('hvac')) {
      return Icons.thermostat;
    }
    if (categoryLower.contains('ventilation')) {
      return Icons.air;
    }

    // Appliance Repair
    if (categoryLower.contains('appliance') ||
        categoryLower.contains('refriger')) {
      return Icons.kitchen_outlined;
    }
    if (categoryLower.contains('washer') || categoryLower.contains('dryer')) {
      return Icons.local_laundry_service;
    }
    if (categoryLower.contains('microwave') || categoryLower.contains('oven')) {
      return Icons.microwave;
    }

    // Roofing & Exterior
    if (categoryLower.contains('roof')) {
      return Icons.roofing;
    }
    if (categoryLower.contains('gutter')) {
      return Icons.water_damage;
    }
    if (categoryLower.contains('siding') ||
        categoryLower.contains('exterior')) {
      return Icons.home;
    }

    // Masonry & Construction
    if (categoryLower.contains('mason') || categoryLower.contains('brick')) {
      return Icons.foundation;
    }
    if (categoryLower.contains('concrete') ||
        categoryLower.contains('cement')) {
      return Icons.construction;
    }
    if (categoryLower.contains('tile')) {
      return Icons.grid_on;
    }

    // Locksmith & Security
    if (categoryLower.contains('lock') || categoryLower.contains('key')) {
      return Icons.lock_outline;
    }
    if (categoryLower.contains('security') || categoryLower.contains('alarm')) {
      return Icons.security;
    }
    if (categoryLower.contains('camera') || categoryLower.contains('cctv')) {
      return Icons.videocam_outlined;
    }

    // Moving & Delivery
    if (categoryLower.contains('mov') || categoryLower.contains('transport')) {
      return Icons.local_shipping;
    }
    if (categoryLower.contains('delivery')) {
      return Icons.delivery_dining;
    }

    // Handyman & General
    if (categoryLower.contains('handyman') ||
        categoryLower.contains('general')) {
      return Icons.handyman;
    }
    if (categoryLower.contains('repair') &&
        !categoryLower.contains('appliance')) {
      return Icons.build;
    }
    if (categoryLower.contains('install')) {
      return Icons.settings_suggest;
    }

    // IT & Tech Services
    if (categoryLower.contains('computer') ||
        categoryLower.contains('laptop')) {
      return Icons.computer;
    }
    if (categoryLower.contains('wifi') || categoryLower.contains('internet')) {
      return Icons.wifi;
    }
    if (categoryLower.contains('phone') || categoryLower.contains('mobile')) {
      return Icons.phone_android;
    }

    // Auto & Vehicle
    if (categoryLower.contains('car') || categoryLower.contains('auto')) {
      return Icons.directions_car;
    }
    if (categoryLower.contains('bike') ||
        categoryLower.contains('motorcycle')) {
      return Icons.two_wheeler;
    }

    // Wellness & Personal
    if (categoryLower.contains('beauty') || categoryLower.contains('salon')) {
      return Icons.face_retouching_natural;
    }
    if (categoryLower.contains('massage') || categoryLower.contains('spa')) {
      return Icons.spa;
    }
    if (categoryLower.contains('fitness') || categoryLower.contains('gym')) {
      return Icons.fitness_center;
    }

    // Education & Tutoring
    if (categoryLower.contains('tutor') || categoryLower.contains('teach')) {
      return Icons.school;
    }
    if (categoryLower.contains('music') ||
        categoryLower.contains('instrument')) {
      return Icons.music_note;
    }

    // Pet Services
    if (categoryLower.contains('pet') ||
        categoryLower.contains('dog') ||
        categoryLower.contains('cat') ||
        categoryLower.contains('animal')) {
      return Icons.pets;
    }
    if (categoryLower.contains('vet') || categoryLower.contains('veterinary')) {
      return Icons.medical_services;
    }

    // Photography & Media
    if (categoryLower.contains('photo') || categoryLower.contains('camera')) {
      return Icons.photo_camera;
    }
    if (categoryLower.contains('video') || categoryLower.contains('film')) {
      return Icons.videocam;
    }

    // Event Services
    if (categoryLower.contains('event') || categoryLower.contains('party')) {
      return Icons.celebration;
    }
    if (categoryLower.contains('catering') || categoryLower.contains('food')) {
      return Icons.restaurant;
    }
    if (categoryLower.contains('dj') || categoryLower.contains('music')) {
      return Icons.queue_music;
    }

    // Default fallback
    return Icons.home_repair_service;
  }

  LinearGradient _getCategoryColorGradient(String category) {
    final categoryLower = category.toLowerCase();

    // Plumbing - Blue tones
    if (categoryLower.contains('plumb') ||
        categoryLower.contains('pipe') ||
        categoryLower.contains('leak') ||
        categoryLower.contains('drain')) {
      return LinearGradient(
        colors: [
          const Color(0xFF0EA5E9).withOpacity(0.15),
          const Color(0xFF06B6D4).withOpacity(0.15),
        ],
      );
    }

    // Electrical - Yellow/Amber
    if (categoryLower.contains('electric') ||
        categoryLower.contains('light') ||
        categoryLower.contains('power') ||
        categoryLower.contains('wiring')) {
      return LinearGradient(
        colors: [
          const Color(0xFFFBBF24).withOpacity(0.15),
          const Color(0xFFF59E0B).withOpacity(0.15),
        ],
      );
    }

    // Carpentry - Brown tones
    if (categoryLower.contains('carpen') ||
        categoryLower.contains('wood') ||
        categoryLower.contains('door') ||
        categoryLower.contains('furniture')) {
      return LinearGradient(
        colors: [
          const Color(0xFF92400E).withOpacity(0.15),
          const Color(0xFFA16207).withOpacity(0.15),
        ],
      );
    }

    // Painting - Purple/Pink
    if (categoryLower.contains('paint') ||
        categoryLower.contains('decor') ||
        categoryLower.contains('wall')) {
      return LinearGradient(
        colors: [
          const Color(0xFFC026D3).withOpacity(0.15),
          const Color(0xFFA855F7).withOpacity(0.15),
        ],
      );
    }

    // Cleaning - Teal/Cyan
    if (categoryLower.contains('clean') ||
        categoryLower.contains('wash') ||
        categoryLower.contains('pest')) {
      return LinearGradient(
        colors: [
          const Color(0xFF14B8A6).withOpacity(0.15),
          const Color(0xFF06B6D4).withOpacity(0.15),
        ],
      );
    }

    // Gardening - Green
    if (categoryLower.contains('garden') ||
        categoryLower.contains('lawn') ||
        categoryLower.contains('tree') ||
        categoryLower.contains('landscap')) {
      return LinearGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.15),
          const Color(0xFF059669).withOpacity(0.15),
        ],
      );
    }

    // HVAC - Light blue
    if (categoryLower.contains('ac') ||
        categoryLower.contains('heat') ||
        categoryLower.contains('hvac') ||
        categoryLower.contains('ventilation')) {
      return LinearGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.15),
          const Color(0xFF60A5FA).withOpacity(0.15),
        ],
      );
    }

    // Security - Dark blue/Indigo
    if (categoryLower.contains('lock') ||
        categoryLower.contains('security') ||
        categoryLower.contains('alarm') ||
        categoryLower.contains('camera')) {
      return LinearGradient(
        colors: [
          const Color(0xFF4F46E5).withOpacity(0.15),
          const Color(0xFF6366F1).withOpacity(0.15),
        ],
      );
    }

    // Construction/Masonry - Gray/Stone
    if (categoryLower.contains('mason') ||
        categoryLower.contains('brick') ||
        categoryLower.contains('concrete') ||
        categoryLower.contains('roof')) {
      return LinearGradient(
        colors: [
          const Color(0xFF64748B).withOpacity(0.15),
          const Color(0xFF475569).withOpacity(0.15),
        ],
      );
    }

    // IT/Tech - Violet
    if (categoryLower.contains('computer') ||
        categoryLower.contains('wifi') ||
        categoryLower.contains('tech') ||
        categoryLower.contains('internet')) {
      return LinearGradient(
        colors: [
          const Color(0xFF7C3AED).withOpacity(0.15),
          const Color(0xFF8B5CF6).withOpacity(0.15),
        ],
      );
    }

    // Auto/Vehicle - Red
    if (categoryLower.contains('car') ||
        categoryLower.contains('auto') ||
        categoryLower.contains('bike') ||
        categoryLower.contains('vehicle')) {
      return LinearGradient(
        colors: [
          const Color(0xFFEF4444).withOpacity(0.15),
          const Color(0xFFDC2626).withOpacity(0.15),
        ],
      );
    }

    // Wellness/Beauty - Rose
    if (categoryLower.contains('beauty') ||
        categoryLower.contains('spa') ||
        categoryLower.contains('massage') ||
        categoryLower.contains('salon')) {
      return LinearGradient(
        colors: [
          const Color(0xFFF472B6).withOpacity(0.15),
          const Color(0xFFEC4899).withOpacity(0.15),
        ],
      );
    }

    // Pet Services - Orange
    if (categoryLower.contains('pet') ||
        categoryLower.contains('dog') ||
        categoryLower.contains('cat') ||
        categoryLower.contains('vet')) {
      return LinearGradient(
        colors: [
          const Color(0xFFFB923C).withOpacity(0.15),
          const Color(0xFFF97316).withOpacity(0.15),
        ],
      );
    }

    // Event/Food Services - Emerald
    if (categoryLower.contains('event') ||
        categoryLower.contains('catering') ||
        categoryLower.contains('party') ||
        categoryLower.contains('food')) {
      return LinearGradient(
        colors: [
          const Color(0xFF34D399).withOpacity(0.15),
          const Color(0xFF10B981).withOpacity(0.15),
        ],
      );
    }

    // Default - Blue/Purple gradient
    return LinearGradient(
      colors: [
        const Color(0xFF38BDF8).withOpacity(0.15),
        const Color(0xFF6366F1).withOpacity(0.15),
      ],
    );
  }

  Color _getCategoryIconColor(String category) {
    final categoryLower = category.toLowerCase();

    if (categoryLower.contains('plumb') || categoryLower.contains('pipe')) {
      return const Color(0xFF0EA5E9);
    }
    if (categoryLower.contains('electric') || categoryLower.contains('light')) {
      return const Color(0xFFF59E0B);
    }
    if (categoryLower.contains('carpen') || categoryLower.contains('wood')) {
      return const Color(0xFF92400E);
    }
    if (categoryLower.contains('paint') || categoryLower.contains('decor')) {
      return const Color(0xFFA855F7);
    }
    if (categoryLower.contains('clean')) {
      return const Color(0xFF14B8A6);
    }
    if (categoryLower.contains('garden') || categoryLower.contains('lawn')) {
      return const Color(0xFF10B981);
    }
    if (categoryLower.contains('ac') || categoryLower.contains('heat')) {
      return const Color(0xFF3B82F6);
    }
    if (categoryLower.contains('lock') || categoryLower.contains('security')) {
      return const Color(0xFF4F46E5);
    }
    if (categoryLower.contains('mason') || categoryLower.contains('concrete')) {
      return const Color(0xFF64748B);
    }
    if (categoryLower.contains('computer') || categoryLower.contains('tech')) {
      return const Color(0xFF7C3AED);
    }
    if (categoryLower.contains('car') || categoryLower.contains('auto')) {
      return const Color(0xFFEF4444);
    }
    if (categoryLower.contains('beauty') || categoryLower.contains('spa')) {
      return const Color(0xFFEC4899);
    }
    if (categoryLower.contains('pet')) {
      return const Color(0xFFF97316);
    }
    if (categoryLower.contains('event') || categoryLower.contains('food')) {
      return const Color(0xFF10B981);
    }

    return const Color(0xFF38BDF8);
  }
}

// Keep all the existing _AnimatedProHero, _PulsatingBadge, _ProHeroBubble, and _CustomerInfo classes unchanged
// from the original file...

class _AnimatedProHero extends StatefulWidget {
  final String title;
  final String subtitle;

  const _AnimatedProHero({required this.title, required this.subtitle});

  @override
  State<_AnimatedProHero> createState() => _AnimatedProHeroState();
}

class _AnimatedProHeroState extends State<_AnimatedProHero>
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
                        _PulsatingBadge(label: 'Professional'),
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
                  _ProHeroBubble(),
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

class _ProHeroBubble extends StatefulWidget {
  const _ProHeroBubble();

  @override
  State<_ProHeroBubble> createState() => _ProHeroBubbleState();
}

class _ProHeroBubbleState extends State<_ProHeroBubble>
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
                      child: const Icon(Icons.handyman, color: Colors.white),
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

class _CustomerInfo extends StatelessWidget {
  final String customerId;
  const _CustomerInfo({required this.customerId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return FutureBuilder<UserModel?>(
      future: service.getUser(customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final customer = snapshot.data!;
        final displayName = customer.displayName ?? customer.email;
        final phoneNumber = customer.phoneNumber;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF38BDF8).withOpacity(0.08),
                const Color(0xFF6366F1).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Avatar with gradient border
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF38BDF8),
                    backgroundImage: customer.photoUrl != null
                        ? NetworkImage(customer.photoUrl!)
                        : null,
                    child: customer.photoUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CUSTOMER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.phone_outlined,
                              size: 11,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0284C7),
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
