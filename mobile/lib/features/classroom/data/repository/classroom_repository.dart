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

  Future<SyncResult> sync(String studentId) async {
    final res = await _api.post('classroom/student/$studentId/sync');
    return SyncResult.fromJson(res.data as Map<String, dynamic>);
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

  /// Vista combinada: connected + sync + courses + upcoming en 1 sola
  /// petición HTTP. Reduce el número de requests a Railway (cada uno
  /// agrega ~1.5s de overhead de red).
  Future<ClassroomOverview> getOverview(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/overview');
    final data = res.data as Map<String, dynamic>;
    return ClassroomOverview.fromJson(data);
  }

  /// Vista ligera para el card "Esta semana" del home del padre:
  /// connected + upcoming en UNA sola petición (sin courses ni sync).
  /// Es más rápido que /overview porque no ejecuta syncStudent.
  Future<UpcomingStatus> getUpcomingStatus(String studentId) async {
    final res = await _api.get('classroom/student/$studentId/upcoming-status');
    final data = res.data as Map<String, dynamic>;
    return UpcomingStatus.fromJson(data);
  }

  // studentId obligatorio: el backend ya no acepta este endpoint sin un
  // alumno específico (hallazgo BL-1 — antes devolvía la sesión de
  // asistencia más reciente de CUALQUIER colegio, sin scoping).
  Future<TodaySummary> getParentTodaySummary(String studentId) async {
    final res = await _api.get('classroom/parent/today-summary?studentId=$studentId');
    return TodaySummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// Vista combinada del home del padre: todaySummary + upcomingStatus en
  /// UNA sola petición. Ejecuta todas las queries en 1-2 conexiones al
  /// pooler, evitando que los cards "Novedades" y "Esta semana" compitan por
  /// la única conexión (connection_limit=1) y se serialicen.
  Future<ParentHomeData> getParentHome(String studentId) async {
    final res = await _api.get('classroom/parent/home?studentId=$studentId');
    final data = res.data as Map<String, dynamic>;
    return ParentHomeData.fromJson(data);
  }
}

/// Resultado de la vista combinada `/overview`.
/// Contiene connected + sync + courses + upcoming en una sola respuesta.
class ClassroomOverview {
  final bool connected;
  final List<GcCourse> courses;
  final List<GcCoursework> upcoming;
  final int syncCourses;
  final int syncCourseworks;

  const ClassroomOverview({
    required this.connected,
    required this.courses,
    required this.upcoming,
    required this.syncCourses,
    required this.syncCourseworks,
  });

  factory ClassroomOverview.fromJson(Map<String, dynamic> json) {
    final sync = json['sync'] as Map<String, dynamic>? ?? {};
    return ClassroomOverview(
      connected: json['connected'] as bool? ?? false,
      courses: (json['courses'] as List<dynamic>? ?? [])
          .map((c) => GcCourse.fromJson(c as Map<String, dynamic>))
          .toList(),
      upcoming: (json['upcoming'] as List<dynamic>? ?? [])
          .map((c) => GcCoursework.fromJson(c as Map<String, dynamic>))
          .toList(),
      syncCourses: sync['courses'] as int? ?? 0,
      syncCourseworks: sync['courseworks'] as int? ?? 0,
    );
  }
}

/// Resultado de la vista ligera `/upcoming-status`.
/// Contiene connected + upcoming (sin courses ni sync).
class UpcomingStatus {
  final bool connected;
  final List<GcCoursework> upcoming;

  const UpcomingStatus({
    required this.connected,
    required this.upcoming,
  });

  factory UpcomingStatus.fromJson(Map<String, dynamic> json) {
    return UpcomingStatus(
      connected: json['connected'] as bool? ?? false,
      upcoming: (json['upcoming'] as List<dynamic>? ?? [])
          .map((c) => GcCoursework.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Resultado de la vista combinada `/parent/home`.
/// Contiene todaySummary + upcomingStatus en una sola respuesta.
class ParentHomeData {
  final TodaySummary todaySummary;
  final UpcomingStatus upcomingStatus;

  const ParentHomeData({
    required this.todaySummary,
    required this.upcomingStatus,
  });

  factory ParentHomeData.fromJson(Map<String, dynamic> json) {
    return ParentHomeData(
      todaySummary: TodaySummary.fromJson(
          json['todaySummary'] as Map<String, dynamic>? ?? {}),
      upcomingStatus: UpcomingStatus.fromJson(
          json['upcomingStatus'] as Map<String, dynamic>? ?? {}),
    );
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

/// Resultado de POST /sync. cacheHit=true ⇒ el backend respondió desde su
/// caché de 15 min (sin llamar a Google) y los datos de /parent/home ya están
/// frescos; cacheHit=false ⇒ hubo sync completo contra Google y conviene
/// recargar /parent/home para que el conteo incluya los datos nuevos.
/// cacheHit usa `?? false` para mantener compatibilidad con backends previos
/// que aún no devuelven el campo (asume cache miss → recarga segura).
class SyncResult {
  final int courses;
  final int courseworks;
  final bool cacheHit;
  const SyncResult({
    required this.courses,
    required this.courseworks,
    required this.cacheHit,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
        courses: json['courses'] as int? ?? 0,
        courseworks: json['courseworks'] as int? ?? 0,
        cacheHit: json['cacheHit'] as bool? ?? false,
      );
}
