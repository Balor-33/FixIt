import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../config/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      headerHeight: 200,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Stay up to date with your jobs and reports',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Back', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 24),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'You will receive updates about jobs, messages, and appointments here.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
