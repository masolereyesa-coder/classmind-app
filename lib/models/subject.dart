class Subject {
  final String id;
  final String name;
  final String professorName;
  final String createdAt;

  Subject({
    required this.id,
    required this.name,
    this.professorName = '',
    this.createdAt = '',
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      professorName: json['professor_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
