/// 對應 Firestore users/{uid}/medications/{medId}
class Medication {
  final String? id;
  final String name;
  final List<String> times; // 24 小時制 "HH:MM"
  final String instructions;

  const Medication({
    this.id,
    required this.name,
    required this.times,
    this.instructions = '',
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    times: (json['times'] as List<dynamic>? ?? []).cast<String>(),
    instructions: json['instructions'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'times': times,
    'instructions': instructions,
  };
}
