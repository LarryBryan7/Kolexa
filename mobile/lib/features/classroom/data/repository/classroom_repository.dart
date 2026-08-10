import '../../../../core/api/api_client.dart';
import '../models/gc_models.dart';

class ClassroomRepository {
  final ApiClient _api;
  const ClassroomRepository(this._api);

  Future<String> getAuthUrl(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/auth-url');
    return res.data['url'] as String;
  }

  Future<bool> isConnected(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/status');
    return res.data['connected'] as bool;
  }

  Future<Map<String, int>> sync(String studentId) async {
    final res = await _api.post('classroom/student/$studentId/sync');
    return {
      'courses': res.data['courses'] as int,
      'courseworks': res.data['courseworks'] as int,
    };
  }

  Future<List<GcCourse>> getCourses(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/courses');
    return (res.data as List<dynamic>)
        .map((c) => GcCourse.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<GcCoursework>> getUpcoming(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/upcoming');
    return (res.data as List<dynamic>)
        .map((c) => GcCoursework.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<TodaySummary> getParentTodaySummary() async {
    final res = await _api.get('classroom/parent/today-summary');
    return TodaySummary.fromJson(res.data as Map<String, dynamic>);
  }
}

class ScheduleBlock {
  final String courseName;
  final String startTime; // "8:30"
  final String endTime;   // "9:50"
  final bool isActive;
  final String type; // 'class' | 'recess' | 'break' | 'lunch'
  final String? task;
  final String? taskDue;

  const ScheduleBlock({
    required this.courseName,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.type,
    this.task,
    this.taskDue,
  });

  factory ScheduleBlock.fromJson(Map<String, dynamic> j) => ScheduleBlock(
        courseName: j['courseName'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        isActive: j['isActive'] as bool? ?? false,
        type: j['type'] as String? ?? 'class',
        task: j['task'] as String?,
        taskDue: j['taskDue'] as String?,
      );
}

class TodaySummary {
  final String? arrivalStatus;
  final String? arrivalTime;
  final String? currentCourse;
  final int photoCount;
  final List<String> photoUrls;
  final List<ScheduleBlock> scheduleBlocks;

  const TodaySummary({
    required this.arrivalStatus,
    required this.arrivalTime,
    required this.currentCourse,
    required this.photoCount,
    required this.photoUrls,
    required this.scheduleBlocks,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> j) => TodaySummary(
        arrivalStatus: j['arrivalStatus'] as String?,
        arrivalTime: j['arrivalTime'] as String?,
        currentCourse: j['currentCourse'] as String?,
        photoCount: j['photoCount'] as int? ?? 0,
        photoUrls: (j['photoUrls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        scheduleBlocks: (j['scheduleBlocks'] as List<dynamic>?)
                ?.map((e) => ScheduleBlock.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get arrivalLabel {
    switch (arrivalStatus) {
      case 'present':   return 'Temprano';
      case 'late':      return 'Tarde';
      case 'absent':    return 'Ausente';
      case 'justified': return 'Justificado';
      default:          return 'Sin asistencia';
    }
  }

  String get photoLabel => photoCount > 0 ? '$photoCount nueva${photoCount != 1 ? 's' : ''}' : '–';
}
