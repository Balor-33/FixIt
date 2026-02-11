import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../auth_service.dart';
import 'chat_screen.dart';

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

      await _firestoreService.updateIssue(widget.issue.id!, {
        'status': status,
        'assignedProfessionalId': user.uid,
      });

      await _firestoreService.createNotification(
        userId: widget.issue.customerId,
        title: 'Issue Update',
        body: 'Your issue "${widget.issue.title}" is now $status',
        type: 'issue_status',
        data: {'issueId': widget.issue.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue $status successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
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

  // ✅ Open chat with customer
  Future<void> _openChat() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final chatRoomId = await _firestoreService.getOrCreateChatRoom(
        issueId: widget.issue.id!,
        customerId: widget.issue.customerId,
        professionalId: user.uid,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatRoomId: chatRoomId,
              issueTitle: widget.issue.title,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Opens a fullscreen image viewer
  void _openImageViewer(List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullscreenImageViewer(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final user = _authService.currentUser;

    // ✅ Get imageUrls — filter out nulls/empty
    final imageUrls = (issue.imageUrls ?? [])
        .where((url) => url!.isNotEmpty)
        .cast<String>()
        .toList();

    // ✅ Check if professional has accepted/is working on this issue
    final isAssignedToProfessional = issue.assignedProfessionalId == user?.uid;
    final canChat =
        isAssignedToProfessional &&
        issue.status != 'rejected' &&
        issue.status != 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Details'),
        backgroundColor: const Color(0xFF1DB9AA),
        actions: [
          // ✅ Chat button in app bar - only show if professional accepted the issue
          if (canChat)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _openChat,
              tooltip: 'Chat with customer',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Issue Title & Category ──────────────────────────────
            Text(
              issue.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(issue.category, style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 16),

            // ── Issue Info Card ─────────────────────────────────────
            _SectionCard(
              title: 'Issue Info',
              icon: Icons.report_problem_outlined,
              children: [
                _infoRow(Icons.location_on_outlined, 'Address', issue.address),
                _infoRow(
                  Icons.warning_amber_outlined,
                  'Emergency Level',
                  issue.emergencyLevel.toString(),
                ),
                _infoRow(
                  Icons.info_outline,
                  'Status',
                  issue.status.toUpperCase(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Description Card ────────────────────────────────────
            _SectionCard(
              title: 'Description',
              icon: Icons.description_outlined,
              children: [
                Text(
                  issue.description,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Images Card — only shown if imageUrls is not empty ──
            if (imageUrls.isNotEmpty)
              _SectionCard(
                title: 'Attached Photos (${imageUrls.length})',
                icon: Icons.photo_library_outlined,
                children: [
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        return GestureDetector(
                          onTap: () => _openImageViewer(imageUrls, i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.network(
                                  imageUrls[i],
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 110,
                                      height: 110,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 110,
                                    height: 110,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                // Tap to expand hint
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            if (imageUrls.isNotEmpty) const SizedBox(height: 12),

            // ── Customer Info Card ──────────────────────────────────
            FutureBuilder<UserModel?>(
              future: _firestoreService.getUser(issue.customerId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customer = snapshot.data!;
                final displayName = customer.displayName;

                return _SectionCard(
                  title: 'Customer Info',
                  icon: Icons.person_outline,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF1DB9AA),
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
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // ✅ Chat button next to customer name
                        if (canChat)
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            iconSize: 20,
                            color: const Color(0xFF1DB9AA),
                            onPressed: _openChat,
                            tooltip: 'Chat with customer',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (customer.phoneNumber != null &&
                        customer.phoneNumber!.isNotEmpty)
                      _infoRow(
                        Icons.phone_outlined,
                        'Phone',
                        customer.phoneNumber!,
                      ),
                    if (customer.email.isNotEmpty)
                      _infoRow(Icons.email_outlined, 'Email', customer.email),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ──────────────────────────────────────
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(issue.status),

            const SizedBox(height: 16),
          ],
        ),
      ),
      // ✅ Floating Action Button for Chat - only show if professional accepted
      floatingActionButton: canChat
          ? FloatingActionButton.extended(
              onPressed: _openChat,
              backgroundColor: const Color(0xFF1DB9AA),
              icon: const Icon(Icons.chat),
              label: const Text('Chat with Customer'),
            )
          : null,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1DB9AA)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
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
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _updateStatus('accepted'),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _updateStatus('rejected'),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _updateStatus('working'),
            icon: const Icon(Icons.construction),
            label: const Text('Start Working'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );

      case 'working':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _updateStatus('completed'),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark as Completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Fullscreen image viewer with swipe support ────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 60,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Reusable section card widget ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1DB9AA)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1DB9AA),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }
}
