// ============================================================
// personal_page.dart — Personal del colegio (director, solo lectura)
// ============================================================
// Lista de docentes/directores desde GET /admin/users (filtrado en
// el cliente a esos dos roles, ver DirectorRepository.getStaff()).
// No hay drill-down por docente en esta fase — el dashboard ya
// muestra el agregado de cuántos conectaron Google Classroom.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/api_client.dart';
import '../../data/director_repository.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key});

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  late Future<List<DirectorStaffMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = DirectorRepository(context.read<ApiClient>()).getStaff();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text('Personal', style: TextStyle(color: _kTextDark)),
        iconTheme: const IconThemeData(color: _kTextDark),
      ),
      body: FutureBuilder<List<DirectorStaffMember>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar el personal'));
          }
          final staff = snapshot.data ?? [];
          if (staff.isEmpty) {
            return const Center(child: Text('Sin personal registrado', style: TextStyle(color: _kTextGray)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = staff[i];
              final roleLabel = s.isSchoolAdmin ? 'Dirección' : 'Docente';
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
                        child: Icon(
                          s.isSchoolAdmin ? Icons.school_outlined : Icons.person_outline,
                          color: _kPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.fullName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
                            const SizedBox(height: 2),
                            Text(s.email, style: const TextStyle(fontSize: 12, color: _kTextGray)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimaryLt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(roleLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kPrimary)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
