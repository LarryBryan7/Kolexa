import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class TeacherClassroom {
  final int id;
  final String name;
  final String grade;
  final String section;
  final int studentCount;

  const TeacherClassroom({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    required this.studentCount,
  });

  factory TeacherClassroom.fromJson(Map<String, dynamic> json) {
    return TeacherClassroom(
      id: json['id'] as int,
      name: json['name'] as String,
      grade: json['grade'] as String,
      section: json['section'] as String,
      studentCount: json['studentCount'] as int,
    );
  }
}

class GcTeacherCourse {
  final int id;
  final String googleId;
  final String name;
  final String? section;
  final int submissionCount;

  const GcTeacherCourse({
    required this.id,
    required this.googleId,
    required this.name,
    this.section,
    required this.submissionCount,
  });

  factory GcTeacherCourse.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return GcTeacherCourse(
      id: int.parse(json['id'].toString()),
      googleId: json['googleId'] as String,
      name: json['name'] as String,
      section: json['section'] as String?,
      submissionCount: count?['submissions'] as int? ?? 0,
    );
  }
}

class AttendanceSummary {
  final int present;
  final int late;
  final int absent;
  final int total;

  const AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.total,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        present: j['present'] as int? ?? 0,
        late: j['late'] as int? ?? 0,
        absent: j['absent'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
      );

  String get label => '$present temprano · $late tarde · $absent ausente';
}

class TeacherHomeData {
  final List<TeacherClassroom> classrooms;
  final bool hasSchedule;
  final String? gcSection;
  final int? gcStudentCount;
  // 'none' | 'attendance_only' | 'complete'
  final String attendanceState;
  final AttendanceSummary? attendanceSummary;
  // Fuente única de conexión Classroom (equivale a Mejora A del padre)
  final bool connected;

  const TeacherHomeData({
    required this.classrooms,
    required this.hasSchedule,
    this.gcSection,
    this.gcStudentCount,
    this.attendanceState = 'none',
    this.attendanceSummary,
    this.connected = false,
  });

  factory TeacherHomeData.fromJson(Map<String, dynamic> json) {
    final rawClassrooms = json['classrooms'] as List<dynamic>? ?? [];
    final rawSummary = json['attendanceSummary'] as Map<String, dynamic>?;
    return TeacherHomeData(
      classrooms: rawClassrooms
          .map((c) => TeacherClassroom.fromJson(c as Map<String, dynamic>))
          .toList(),
      hasSchedule: json['hasSchedule'] as bool? ?? false,
      gcSection: json['gcSection'] as String?,
      gcStudentCount: json['gcStudentCount'] as int?,
      attendanceState: json['attendanceState'] as String? ?? 'none',
      attendanceSummary: rawSummary != null ? AttendanceSummary.fromJson(rawSummary) : null,
      connected: json['connected'] as bool? ?? false,
    );
  }
}

class ScheduleSlot {
  final String courseName;
  final String type; // 'class' | 'recess'
  final String startTime; // "HH:mm"
  final String endTime;

  const ScheduleSlot({
    required this.courseName,
    required this.type,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(
        courseName: j['courseName'] as String,
        type: j['type'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
      );

  int get _startMins {
    final p = startTime.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  int get _endMins {
    final p = endTime.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool isActive(DateTime now) {
    final mins = now.hour * 60 + now.minute;
    return mins >= _startMins && mins < _endMins;
  }

  bool isUpcoming(DateTime now) {
    final mins = now.hour * 60 + now.minute;
    return _startMins > mins;
  }
}

class ClassroomStudent {
  final int id;
  final String googleId;
  final String fullName;
  final String? email;
  final String? photoUrl;

  const ClassroomStudent({
    required this.id,
    required this.googleId,
    required this.fullName,
    this.email,
    this.photoUrl,
  });

  factory ClassroomStudent.fromJson(Map<String, dynamic> j) => ClassroomStudent(
        id: j['id'] as int,
        googleId: j['googleId'] as String,
        fullName: j['fullName'] as String,
        email: j['email'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

class SyncResult {
  final bool cacheHit;
  const SyncResult({required this.cacheHit});
}

class TeacherRepository {
  final ApiClient _api;
  const TeacherRepository(this._api);

  Future<TeacherHomeData> getHomeData() async {
    final response = await _api.get('/teachers/me/home');
    return TeacherHomeData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> isClassroomConnected() async {
    final response = await _api.get('/classroom/teacher/status');
    return (response.data as Map<String, dynamic>)['connected'] as bool;
  }

  Future<String> getClassroomAuthUrl() async {
    final response = await _api.get('/classroom/teacher/auth-url');
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  Future<SyncResult> syncClassroom() async {
    final response = await _api.post('/classroom/teacher/sync');
    final data = response.data as Map<String, dynamic>? ?? {};
    return SyncResult(cacheHit: data['cacheHit'] as bool? ?? false);
  }

  Future<List<GcTeacherCourse>> getCourses() async {
    final response = await _api.get('/classroom/teacher/courses');
    final raw = response.data as List<dynamic>? ?? [];
    return raw.map((c) => GcTeacherCourse.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<int> getPendingCount() async {
    final response = await _api.get('/classroom/teacher/pending');
    return (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<List<ClassroomStudent>> getClassroomRoster({int? courseId}) async {
    final response = await _api.get(
      '/classroom/teacher/roster',
      queryParams: courseId != null ? {'courseId': courseId} : null,
    );
    final raw = response.data as List<dynamic>? ?? [];
    return raw
        .map((e) => ClassroomStudent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAttendance({
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    await _api.post('/teachers/me/attendance', data: {
      'date': date,
      'records': records,
    });
  }

  Future<void> uploadAttendancePhotos({
    required String date,
    required List<String> photoPaths,
  }) async {
    final files = await Future.wait(
      photoPaths.map((path) {
        final name = path.split('/').last;
        return MultipartFile.fromFile(path, filename: name);
      }),
    );
    final formData = FormData.fromMap({'date': date, 'photos': files});
    await _api.post('/teachers/me/attendance/photos', data: formData);
  }

  Future<void> saveSchedule(List<Map<String, dynamic>> blocks) async {
    await _api.post('/teachers/me/schedule', data: {'blocks': blocks});
  }

  Future<List<ScheduleSlot>> getTodaySchedule() async {
    final response = await _api.get('/teachers/me/schedule/today');
    final raw = response.data as List<dynamic>? ?? [];
    return raw.map((e) => ScheduleSlot.fromJson(e as Map<String, dynamic>)).toList();
  }
}
