import 'package:flutter/material.dart';

import '../models/group.dart';
import '../models/loan.dart';

/// Per-group loan health derived from loan statuses (dashboard heatmap / scores).
class GroupLoanRiskSummary {
  final String groupName;
  final double overdueRatio;
  final int trustScore;

  const GroupLoanRiskSummary({
    required this.groupName,
    required this.overdueRatio,
    required this.trustScore,
  });

  String get letterGrade {
    if (trustScore >= 90) return 'A';
    if (trustScore >= 75) return 'B';
    if (trustScore >= 60) return 'C';
    return 'D';
  }

  Color get riskColor {
    if (overdueRatio == 0) return Colors.greenAccent;
    if (overdueRatio < 0.3) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

/// Builds sorted summaries (highest trust first) for dashboard risk widgets.
List<GroupLoanRiskSummary> computeGroupLoanRiskSummaries({
  required List<GroupModel> groups,
  required List<LoanModel> loans,
}) {
  final risks = <GroupLoanRiskSummary>[];

  for (final group in groups) {
    final groupLoans = loans.where((l) => l.groupId == group.id).toList();
    if (groupLoans.isEmpty) {
      risks.add(GroupLoanRiskSummary(
        groupName: group.name,
        overdueRatio: 0,
        trustScore: 100,
      ));
      continue;
    }

    var overdueCount = 0;
    var totalPoints = 0.0;

    for (final loan in groupLoans) {
      final status = loan.status.toLowerCase();
      if (status == 'overdue') {
        overdueCount++;
        totalPoints += 20;
      } else if (status == 'paid') {
        totalPoints += 100;
      } else {
        totalPoints += 80;
      }
    }

    final ratio = overdueCount / groupLoans.length;
    final score = (totalPoints / groupLoans.length).round();
    risks.add(GroupLoanRiskSummary(
      groupName: group.name,
      overdueRatio: ratio,
      trustScore: score,
    ));
  }

  risks.sort((a, b) => b.trustScore.compareTo(a.trustScore));
  return risks;
}
