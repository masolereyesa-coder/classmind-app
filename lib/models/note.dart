class Note {
  final String id;
  final String subjectId;
  final String subjectName;
  final String transcript;
  final String structuredNotes;
  final int durationSeconds;
  final String createdAt;

  Note({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.transcript,
    required this.structuredNotes,
    required this.durationSeconds,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      subjectName: json['subject_name'] ?? '',
      transcript: json['transcript'] ?? '',
      structuredNotes: json['structured_notes'] ?? '',
      durationSeconds: json['duration_seconds'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  String get duration {
    int m = durationSeconds ~/ 60;
    int s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}
