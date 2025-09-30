class CallReview {
  final int? id;
  final int phoneId;
  final String phoneNumber;
  final String reviewType;
  final String? customNote;
  final DateTime timestamp;

  CallReview({
    this.id,
    required this.phoneId,
    required this.phoneNumber,
    required this.reviewType,
    this.customNote,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_id': phoneId,
      'phone_number': phoneNumber,
      'review_type': reviewType,
      'custom_note': customNote,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory CallReview.fromMap(Map<String, dynamic> map) {
    return CallReview(
      id: map['id'],
      phoneId: map['phone_id'],
      phoneNumber: map['phone_number'],
      reviewType: map['review_type'],
      customNote: map['custom_note'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  @override
  String toString() {
    return 'CallReview(id: $id, phoneId: $phoneId, phoneNumber: $phoneNumber, reviewType: $reviewType, customNote: $customNote, timestamp: $timestamp)';
  }
}

class ReviewOption {
  final String key;
  final String label;
  final String message;

  ReviewOption({
    required this.key,
    required this.label,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'message': message,
    };
  }

  factory ReviewOption.fromMap(Map<String, dynamic> map) {
    return ReviewOption(
      key: map['key'],
      label: map['label'],
      message: map['message'],
    );
  }
}

