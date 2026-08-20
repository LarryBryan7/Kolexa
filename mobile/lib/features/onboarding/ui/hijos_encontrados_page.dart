// ============================================================
// hijos_encontrados_page.dart — "04b — Padre: hijos encontrados"
// ============================================================
// Se muestra UNA sola vez, justo después del primer login con Google
// exitoso (ver AuthBloc._onGoogleLogin / AuthState.isFirstGoogleLogin).
// Lista los hijos ya vinculados y deja agregarles una foto de perfil,
// opcional — "continuar" siempre funciona, tengan foto o no.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/data/models/user_model.dart';
import '../../classroom/data/repository/classroom_repository.dart';

const _kBg       = Color(0xFFF7F6F3);
const _kPrimary  = Color(0xFF5B4A9E);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class HijosEncontradosPage extends StatefulWidget {
  const HijosEncontradosPage({super.key, required this.user});

  final UserModel user;

  @override
  State<HijosEncontradosPage> createState() => _HijosEncontradosPageState();
}

class _HijosEncontradosPageState extends State<HijosEncontradosPage> {
  late final ClassroomRepository _classroomRepo;
  late List<ChildModel> _children;
  final Set<int> _uploadingIds = {};

  @override
  void initState() {
    super.initState();
    _classroomRepo = ClassroomRepository(context.read<ApiClient>());
    _children = List.of(widget.user.children);
  }

  Future<void> _pickAndUpload(ChildModel child) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _kPrimary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kPrimary),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingIds.add(child.id));
    try {
      final avatarUrl = await _classroomRepo.uploadAvatar(child.id.toString(), picked.path);
      if (!mounted) return;
      setState(() {
        final i = _children.indexWhere((c) => c.id == child.id);
        if (i != -1) _children[i] = _copyWithAvatar(_children[i], avatarUrl);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('No se pudo subir la foto: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red[700],
        ));
    } finally {
      if (mounted) setState(() => _uploadingIds.remove(child.id));
    }
  }

  ChildModel _copyWithAvatar(ChildModel c, String avatarUrl) => ChildModel(
        id: c.id,
        firstName: c.firstName,
        lastName: c.lastName,
        code: c.code,
        section: c.section,
        birthday: c.birthday,
        avatarUrl: avatarUrl,
      );

  void _onContinue() {
    // Solo re-cachea si al menos una foto cambió — evita una escritura de
    // SharedPreferences innecesaria en el caso común (nadie tocó fotos).
    final changed = _children.any((c) {
      final original = widget.user.children.firstWhere((o) => o.id == c.id);
      return original.avatarUrl != c.avatarUrl;
    });
    if (changed) {
      final updatedUser = UserModel(
        id: widget.user.id,
        email: widget.user.email,
        firstName: widget.user.firstName,
        lastName: widget.user.lastName,
        phone: widget.user.phone,
        avatar: widget.user.avatar,
        roles: widget.user.roles,
        schoolId: widget.user.schoolId,
        schoolName: widget.user.schoolName,
        children: _children,
      );
      context.read<AuthBloc>().add(UserUpdatedEvent(updatedUser));
    }
    context.go(AppRouter.home);
  }

  String _initials(ChildModel c) {
    final f = c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '';
    final l = c.lastName.isNotEmpty ? c.lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Hola ${widget.user.firstName} 👋, encontramos a tus hijos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTextDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrégales una foto para reconocerlos más fácil en la app',
                style: TextStyle(fontSize: 12, color: _kTextGray),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ChildPhotoCard(
                    child: _children[i],
                    initials: _initials(_children[i]),
                    uploading: _uploadingIds.contains(_children[i].id),
                    onTap: () => _pickAndUpload(_children[i]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _onContinue,
                  child: const Text('continuar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 17, color: Colors.grey[500]),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Edítalo cuando quieras desde la pantalla de inicio',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildPhotoCard extends StatelessWidget {
  const _ChildPhotoCard({
    required this.child,
    required this.initials,
    required this.uploading,
    required this.onTap,
  });

  final ChildModel child;
  final String initials;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (child.section != null) child.section!,
      if (child.age != null) '${child.age} años',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: uploading ? null : onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: child.avatarUrl != null
                        ? Image.network(
                            child.avatarUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initialsCircle(),
                          )
                        : _initialsCircle(),
                  ),
                  if (uploading)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.photo_camera, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child.fullName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: const TextStyle(fontSize: 12, color: _kTextGray),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsCircle() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
