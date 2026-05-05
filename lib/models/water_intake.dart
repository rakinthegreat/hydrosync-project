import 'dart:convert';

class WaterIntake {
  final DateTime timestamp;
  final int amount; // in mL

  WaterIntake({
    required this.timestamp,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'amount': amount,
    };
  }

  factory WaterIntake.fromMap(Map<String, dynamic> map) {
    return WaterIntake(
      timestamp: DateTime.parse(map['timestamp']),
      amount: map['amount'],
    );
  }

  String toJson() => json.encode(toMap());

  factory WaterIntake.fromJson(String source) => WaterIntake.fromMap(json.decode(source));
}
