// ============================================================
// director_repository.dart — Lectura operativa para el director
// ============================================================
// Consume los mismos endpoints @Roles('school_admin') que ya usa Web
// Admin (admin.controller.ts) — no hay endpoints nuevos salvo
// /admin/school/summary. Todo es de solo lectura: no hay métodos de
// creación/edición acá (eso se queda en Web Admin, ver plan de
// visibilidad del director).
// ============================================================

import '../../../core/api/api_client.dart';

class LatestAnnouncement {
  final String title;
  final DateTime createdAt;

  const LatestAnnouncement({required this.title, required this.createdAt});

  factory LatestAnnouncement.fromJson(Map<String, dynamic> j) => LatestAnnouncement(
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class SchoolSummary {
  final int classroomCount;
  final int studentCount;
  final int teacherCount;
  final int? attendanceTodayPercent;
  final int classroomsWithoutAttendanceToday;
  final double overduePaymentsTotal;
  final int teachersConnectedToClassroom;
  final LatestAnnouncement? latestAnnouncement;

  const SchoolSummary({
    required this.classroomCount,
    required this.studentCount,
    required this.teacherCount,
    this.attendanceTodayPercent,
    required this.classroomsWithoutAttendanceToday,
    required this.overduePaymentsTotal,
    required this.teachersConnectedToClassroom,
    this.latestAnnouncement,
  });

  factory SchoolSummary.fromJson(Map<String, dynamic> j) {
    final rawAnnouncement = j['latestAnnouncement'] as Map<String, dynamic>?;
    return SchoolSummary(
      classroomCount: j['classroomCount'] as int? ?? 0,
      studentCount: j['studentCount'] as int? ?? 0,
      teacherCount: j['teacherCount'] as int? ?? 0,
      attendanceTodayPercent: j['attendanceTodayPercent'] as int?,
      classroomsWithoutAttendanceToday: j['classroomsWithoutAttendanceToday'] as int? ?? 0,
      overduePaymentsTotal: (j['overduePaymentsTotal'] as num?)?.toDouble() ?? 0,
      teachersConnectedToClassroom: j['teachersConnectedToClassroom'] as int? ?? 0,
      latestAnnouncement:
          rawAnnouncement != null ? LatestAnnouncement.fromJson(rawAnnouncement) : null,
    );
  }
}

class DirectorClassroom {
  final int id;
  final String name;
  final String? grade;
  final String? section;
  final int academicYear;
  final String locationName;
  final int studentCount;

  const DirectorClassroom({
    required this.id,
    required this.name,
    this.grade,
    this.section,
    required this.academicYear,
    required this.locationName,
    required this.studentCount,
  });

  factory DirectorClassroom.fromJson(Map<String, dynamic> j) {
    final location = j['schoolLocation'] as Map<String, dynamic>?;
    final count = j['_count'] as Map<String, dynamic>?;
    return DirectorClassroom(
      id: int.parse(j['id'].toString()),
      name: j['name'] as String,
      grade: j['grade'] as String?,
      section: j['section'] as String?,
      academicYear: j['academicYear'] as int? ?? DateTime.now().year,
      locationName: location?['name'] as String? ?? '',
      studentCount: count?['enrollments'] as int? ?? 0,
    );
  }

  String get label => [name, if (section != null) section].join(' ');
}

class DirectorStaffMember {
  final int id;
  final String fullName;
  final String email;
  final String? avatar;
  final bool isSchoolAdmin;
  final bool isTeacher;

  const DirectorStaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatar,
    required this.isSchoolAdmin,
    required this.isTeacher,
  });

  factory DirectorStaffMember.fromJson(Map<String, dynamic> j) {
    final rawRoles = j['userRoles'] as List<dynamic>? ?? [];
    final roleNames = rawRoles
        .map((r) => (r as Map<String, dynamic>)['role'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((r) => r['name'] as String?)
        .whereType<String>()
        .toSet();
    final firstName = j['firstName'] as String? ?? '';
    final lastName = j['lastName'] as String?;
    return DirectorStaffMember(
      id: int.parse(j['id'].toString()),
      fullName: [firstName, if (lastName != null) lastName].join(' ').trim(),
      email: j['email'] as String? ?? '',
      avatar: j['avatar'] as String?,
      isSchoolAdmin: roleNames.contains('school_admin'),
      isTeacher: roleNames.contains('teacher'),
    );
  }
}

class DirectorStudent {
  final int id;
  final String fullName;
  final String? avatar;
  final List<int> classroomIds;

  const DirectorStudent({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.classroomIds,
  });

  factory DirectorStudent.fromJson(Map<String, dynamic> j) {
    final rawEnrollments = j['enrollments'] as List<dynamic>? ?? [];
    final classroomIds = rawEnrollments
        .map((e) => (e as Map<String, dynamic>)['classroom'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((c) => int.parse(c['id'].toString()))
        .toList();
    final firstName = j['firstName'] as String? ?? '';
    final lastName = j['lastName'] as String?;
    return DirectorStudent(
      id: int.parse(j['id'].toString()),
      fullName: [firstName, if (lastName != null) lastName].join(' ').trim(),
      avatar: j['avatar'] as String?,
      classroomIds: classroomIds,
    );
  }
}

class DirectorRepository {
  final ApiClient _api;
  const DirectorRepository(this._api);

  Future<SchoolSummary> getSchoolSummary() async {
    final response = await _api.get('/admin/school/summary');
    return SchoolSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DirectorClassroom>> getClassrooms() async {
    final response = await _api.get('/admin/classrooms');
    final raw = response.data as List<dynamic>? ?? [];
    return raw.map((c) => DirectorClassroom.fromJson(c as Map<String, dynamic>)).toList();
  }

  // El backend devuelve TODOS los usuarios vinculados al colegio (incluye
  // padres) — se filtra acá a docentes/directores. Se revisan TODOS los
  // roles del usuario, no solo el primero (mismo bug que se corrigió en
  // Web Admin — ver usuarios-page.tsx / staffRole()).
  Future<List<DirectorStaffMember>> getStaff() async {
    final response = await _api.get('/admin/users');
    final raw = response.data as List<dynamic>? ?? [];
    return raw
        .map((u) => DirectorStaffMember.fromJson(u as Map<String, dynamic>))
        .where((u) => u.isTeacher || u.isSchoolAdmin)
        .toList();
  }

  Future<List<DirectorStudent>> getStudents({int? classroomId, String? search}) async {
    final response = await _api.get(
      '/admin/students',
      queryParams: search != null && search.isNotEmpty ? {'search': search} : null,
    );
    final raw = response.data as List<dynamic>? ?? [];
    final students = raw.map((s) => DirectorStudent.fromJson(s as Map<String, dynamic>)).toList();
    if (classroomId == null) return students;
    return students.where((s) => s.classroomIds.contains(classroomId)).toList();
  }
}
