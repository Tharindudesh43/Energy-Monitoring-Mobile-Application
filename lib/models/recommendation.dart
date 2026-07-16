class Recommendation {
  final String message;
  final DateTime timestamp;
  final RecommendationType type;
  final List<String> actionItems;

  Recommendation({
    required this.message,
    required this.timestamp,
    required this.type,
    required this.actionItems,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      type: RecommendationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => RecommendationType.general,
      ),
      actionItems: List<String>.from(json['actionItems']),
    );
  }
}

enum RecommendationType {
  general,
  peakHours,
  appliance,
  savings,
}