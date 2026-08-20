// ============================================================
// user_model.dart — Modelo de datos del Usuario
// ============================================================
// En la arquitectura Clean Architecture (que usamos aquí),
// se separan dos conceptos:
//
//   Entity  → la lógica de negocio pura (no depende de JSON/API)
//   Model   → extiende la Entity y sabe cómo convertirse desde/hacia JSON
//
// UserModel es lo que recibimos del backend. Tiene un constructor
// especial fromJson() que convierte el mapa JSON a un objeto Dart.
//
// Estructura del JSON que devuelve el backend al hacer login:
// {
//   "user": {
//     "id": 1,
//     "email": "padre@ejemplo.com",
//     "firstName": "Juan",
//     "lastName": "Pérez",
//     "phone": "+51999888777",
//     "avatar": "https://...",
//     "roles": ["parent"],
//     "schoolId": 5
//   },
//   "accessToken": "eyJhbG...",
//   "refreshToken": "eyJhbG..."
// }
// ============================================================

class ChildModel {
  final int id;
  final String firstName;
  final String lastName;
  final String code;
  final String? section;
  final DateTime? birthday;
  final String? avatarUrl;

  const ChildModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.code,
    this.section,
    this.birthday,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName';

  int? get age {
    if (birthday == null) return null;
    final today = DateTime.now();
    int years = today.year - birthday!.year;
    if (today.month < birthday!.month ||
        (today.month == birthday!.month && today.day < birthday!.day)) {
      years--;
    }
    return years;
  }

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    DateTime? birthday;
    final raw = json['birthday'] as String?;
    if (raw != null) birthday = DateTime.tryParse(raw);

    return ChildModel(
      id: int.parse(json['id'].toString()),
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      code: json['code'] as String? ?? '',
      section: json['section'] as String?,
      birthday: birthday,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'code': code,
    if (section != null) 'section': section,
    if (birthday != null) 'birthday': birthday!.toIso8601String().split('T')[0],
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };
}

class UserModel {
  // ── Propiedades del usuario ──────────────────────────────
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatar;
  final List<String> roles;
  final int? schoolId;
  final String? schoolName;
  final List<ChildModel> children;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatar,
    required this.roles,
    this.schoolId,
    this.schoolName,
    this.children = const [],
  });

  // ── fromJson ─────────────────────────────────────────────
  // El backend serializa BigInt como String y los roles como objetos:
  //   "id": "6"
  //   "roles": [{"role": "parent", "schoolId": "1", "schoolName": "..."}]
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // BigInt llega como String ("6") — convertimos a int
    final id = int.parse(json['id'].toString());

    // roles es lista de objetos: [{role, schoolId, schoolName}]
    final rawRoles = json['roles'] as List<dynamic>? ?? [];
    final roles = rawRoles
        .map((r) => (r as Map<String, dynamic>)['role'] as String)
        .toList();

    // schoolId y schoolName vienen dentro del primer rol
    int? schoolId;
    String? schoolName;
    if (rawRoles.isNotEmpty) {
      final firstRole = rawRoles.first as Map<String, dynamic>;
      final sid = firstRole['schoolId'];
      if (sid != null) schoolId = int.parse(sid.toString());
      schoolName = firstRole['schoolName'] as String?;
    }

    // children: lista de alumnos vinculados (para padres de familia)
    final rawChildren = json['children'] as List<dynamic>? ?? [];
    final children = rawChildren
        .map((c) => ChildModel.fromJson(c as Map<String, dynamic>))
        .toList();

    return UserModel(
      id: id,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      roles: roles,
      schoolId: schoolId,
      schoolName: schoolName,
      children: children,
    );
  }

  // ── toJson ───────────────────────────────────────────────
  // Convierte UserModel → Map (JSON).
  // Se usa cuando necesitamos enviar el usuario al backend
  // o cuando guardamos en caché local.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (avatar != null) 'avatar': avatar,
      // fromJson() espera 'roles' como lista de OBJETOS ({role, schoolId,
      // schoolName}), igual que el backend — no una lista plana de strings.
      // Antes este toJson() escribía la forma plana, así que el próximo
      // fromJson() (al releer el cache local en el arranque de la app)
      // fallaba con un TypeError silencioso, borraba la sesión entera, y
      // forzaba login de nuevo SIEMPRE, no solo a veces.
      'roles': roles
          .map((r) => {
                'role': r,
                if (schoolId != null) 'schoolId': schoolId.toString(),
                if (schoolName != null) 'schoolName': schoolName,
              })
          .toList(),
      if (schoolId != null) 'schoolId': schoolId,
      if (schoolName != null) 'schoolName': schoolName,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  // ── getter de conveniencia ───────────────────────────────
  // Combina firstName + lastName para mostrar en la UI
  String get fullName => '$firstName $lastName';

  // Verifica si el usuario tiene un rol específico
  bool hasRole(String role) => roles.contains(role);

  // ── toString (para debug) ────────────────────────────────
  // Se llama automáticamente cuando haces print(user)
  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, roles: $roles)';
  }
}

// ============================================================
// LoginResponse — Respuesta completa del endpoint POST /auth/login
// ============================================================
// El backend devuelve usuario + tokens en un solo objeto.
// Esta clase encapsula esa respuesta completa.
// ============================================================
class LoginResponse {
  final UserModel user;
  final String accessToken;   // JWT de corta duración (1 hora)
  final String refreshToken;  // JWT de larga duración (7 días)

  const LoginResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  // Convierte el JSON completo de la respuesta de login en un objeto
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      // Dentro de 'user' está el objeto del usuario
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}
