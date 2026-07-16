import 'package:cloud_firestore/cloud_firestore.dart';

class EnergyUsage {
  final DateTime timestamp;
  final double power;
  final String deviceId;
  final bool limitExceeded;
  final bool isPeakHours;

  EnergyUsage({
    required this.timestamp,
    required this.power,
    required this.deviceId,
    this.limitExceeded = false,
    this.isPeakHours = false,
  });

  factory EnergyUsage.fromFirestore(Map<String, dynamic> data) {
    return EnergyUsage(
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      power: (data['power'] as num).toDouble(),
      deviceId: data['device_id'] ?? '',
      limitExceeded: data['limit_exceeded'] ?? false,
      isPeakHours: data['is_peak_hours'] ?? false,
    );
  }
}