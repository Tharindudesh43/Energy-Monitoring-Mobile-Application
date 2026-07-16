class UserLimits {
  final double normalWattLimit;
  final double peakWattLimit;

  UserLimits({
    required this.normalWattLimit,
    required this.peakWattLimit,
  });

  factory UserLimits.fromFirestore(Map<String, dynamic> data) {
    return UserLimits(
      normalWattLimit: (data['NormalWattLimit'] as num).toDouble(),
      peakWattLimit: (data['PeakWattLimit'] as num).toDouble(),
    );
  }
}