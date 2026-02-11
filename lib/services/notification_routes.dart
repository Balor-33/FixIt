import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/job_details_screen.dart';

class NotificationRouteNames {
  static const String home = '/home';
  static const String jobDetails = '/job-details';
  static const String chat = '/chat';
}

class NotificationNavigationRequest {
  final String routeName;
  final Object? arguments;

  const NotificationNavigationRequest({
    required this.routeName,
    this.arguments,
  });
}

class JobDetailsArgs {
  final String issueId;

  const JobDetailsArgs({required this.issueId});
}

class ChatArgs {
  final String threadId;

  const ChatArgs({required this.threadId});
}

class NotificationRoutes {
  static NotificationNavigationRequest fromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    final issueId = (data['issueId'] ?? '').toString().trim();
    final threadId = (data['threadId'] ?? '').toString().trim();

    switch (type) {
      case 'job_assigned':
      case 'job_accepted':
        if (issueId.isNotEmpty) {
          return NotificationNavigationRequest(
            routeName: NotificationRouteNames.jobDetails,
            arguments: JobDetailsArgs(issueId: issueId),
          );
        }
        break;
      case 'chat_message':
        final resolvedThreadId = threadId.isNotEmpty ? threadId : issueId;
        if (resolvedThreadId.isNotEmpty) {
          return NotificationNavigationRequest(
            routeName: NotificationRouteNames.chat,
            arguments: ChatArgs(threadId: resolvedThreadId),
          );
        }
        break;
      default:
        break;
    }

    return const NotificationNavigationRequest(
      routeName: NotificationRouteNames.home,
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case NotificationRouteNames.jobDetails:
        final args = settings.arguments;
        if (args is JobDetailsArgs) {
          return MaterialPageRoute(
            builder: (_) => JobDetailsScreen(issueId: args.issueId),
            settings: settings,
          );
        }
        return _fallbackRoute(settings);

      case NotificationRouteNames.chat:
        final args = settings.arguments;
        if (args is ChatArgs) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(threadId: args.threadId),
            settings: settings,
          );
        }
        return _fallbackRoute(settings);

      case NotificationRouteNames.home:
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
    }
  }

  static Route<dynamic> _fallbackRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const HomeScreen(),
      settings: settings,
    );
  }
}
