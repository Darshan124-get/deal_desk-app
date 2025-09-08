class PhoneNumber {
  final int? id;
  final String number;
  final String? name;
  final bool completed;

  const PhoneNumber({
    this.id,
    required this.number,
    this.name,
    this.completed = false,
  });

  PhoneNumber copyWith({int? id, String? number, String? name, bool? completed}) {
    return PhoneNumber(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      completed: completed ?? this.completed,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'number': number,
      'name': name,
      'completed': completed ? 1 : 0,
    };
  }

  static PhoneNumber fromMap(Map<String, Object?> map) {
    return PhoneNumber(
      id: map['id'] as int?,
      number: map['number'] as String,
      name: map['name'] as String?,
      completed: (map['completed'] as int? ?? 0) == 1,
    );
  }
}
