enum CallStatus { completed, notAnswered, skipped }

class CallLog {
  final int? id;
  final int phoneId;
  final String phoneNumber;
  final CallStatus status;
  final DateTime timestamp;

  const CallLog({
    this.id,
    required this.phoneId,
    required this.phoneNumber,
    required this.status,
    required this.timestamp,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'phone_id': phoneId,
      'phone_number': phoneNumber,
      'status': status.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  static CallLog fromMap(Map<String, Object?> map) {
    return CallLog(
      id: map['id'] as int?,
      phoneId: map['phone_id'] as int,
      phoneNumber: map['phone_number'] as String,
      status: CallStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => CallStatus.completed,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
