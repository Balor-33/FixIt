import 'package:fixit/models/user_model.dart';

import '../models/issue_model.dart';

class RecommendationService {

  // ===============================
  // PROFESSIONAL JOB RECOMMENDATION
  // ===============================
  List<IssueModel> recommendIssuesForProfessional({
    required List<IssueModel> issues,
    required String professionalCategory, required UserModel professional,
  }) {
    final scoredIssues = issues.map((issue) {
      int score = 0;

      // Category match
      if (issue.category == professionalCategory) {
        score += 50;
      }

      // Emergency priority
      score += issue.emergencyLevel * 20;

      // Recent jobs priority
      final ageInHours =
          DateTime.now().difference(issue.createdAt).inHours;
      if (ageInHours < 24) score += 10;
      if (ageInHours < 6) score += 10;

      return _ScoredIssue(issue, score);
    }).toList();

    scoredIssues.sort((a, b) => b.score.compareTo(a.score));

    return scoredIssues.map((e) => e.issue).toList();
  }

  // ===============================
  // CUSTOMER → PROFESSIONAL MATCHING
  // ===============================
  List<Map<String, dynamic>> recommendProfessionalsForCustomer({
    required List<Map<String, dynamic>> professionals,
    required String issueCategory,
  }) {
    final scoredProfessionals = professionals.map((profile) {
      int score = 0;

      // Service match
      if (profile['service'] == issueCategory) {
        score += 50;
      }

      // ⭐ Rating (SAFE CAST)
      final rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
      score += (rating * 10).toInt();

      // ✔ Completed jobs (SAFE CAST)
      final completedJobs =
          (profile['completedJobs'] as num?)?.toInt() ?? 0;
      score += completedJobs;

      // Availability
      if (profile['isOnline'] == true &&
          profile['isAcceptingJobs'] == true) {
        score += 20;
      }

      return {
        'profile': profile,
        'score': score,
      };
    }).toList();

    scoredProfessionals.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    return scoredProfessionals
        .map((e) => e['profile'] as Map<String, dynamic>)
        .toList();
  }
}

// ===============================
// INTERNAL SCORING CLASS
// ===============================
class _ScoredIssue {
  final IssueModel issue;
  final int score;

  _ScoredIssue(this.issue, this.score);
}
