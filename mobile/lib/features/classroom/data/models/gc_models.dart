class GcCoursework {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final double? maxPoints;
  final String workType;
  final String? alternateLink;

  const GcCoursework({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    this.description,
    this.dueDate,
    this.maxPoints,
    required this.workType,
    this.alternateLink,
  });

  factory GcCoursework.fromJson(Map<String, dynamic> json) {
    return GcCoursework(
      id: json['id'].toString(),
      courseId: json['courseId'].toString(),
      courseName: (json['course'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      maxPoints: (json['maxPoints'] as num?)?.toDouble(),
      workType: json['workType'] as String? ?? 'ASSIGNMENT',
      alternateLink: json['alternateLink'] as String?,
    );
  }
}

class GcCourse {
  final String id;
  final String name;
  final String? section;
  final String? teacherName;
  final List<GcCoursework> courseworks;

  const GcCourse({
    required this.id,
    required this.name,
    this.section,
    this.teacherName,
    this.courseworks = const [],
  });

  factory GcCourse.fromJson(Map<String, dynamic> json) {
    // El backend ahora devuelve el conteo de tareas vía _count en lugar de
    // la lista completa de courseworks (optimización de rendimiento).
    final count = (json['_count'] as Map<String, dynamic>?)?['courseworks'] as int? ?? 0;
    return GcCourse(
      id: json['id'].toString(),
      name: json['name'] as String,
      section: json['section'] as String?,
      teacherName: json['teacherName'] as String?,
      courseworks: List.generate(count, (i) => GcCoursework(
            id: '${json['id']}-$i',
            courseId: json['id'].toString(),
            courseName: json['name'] as String,
            title: '',
            workType: 'ASSIGNMENT',
          )),
    );
  }
}
