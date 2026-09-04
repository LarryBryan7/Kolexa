// ============================================================
// hijos_encontrados_page.dart — "04b/04c — Padre: hijos encontrados"
// ============================================================
// Se muestra UNA sola vez, justo después del primer login con Google
// exitoso (ver AuthBloc._onGoogleLogin / AuthState.isFirstGoogleLogin).
// Lista los hijos ya vinculados y OBLIGA a subirles una foto de perfil:
// "Continuar" queda deshabilitado hasta que todos tengan avatarUrl. Si ya
// la traían (login posterior, o ya se la habían subido antes), pasa directo.
//
// Con un solo hijo usa el layout "04c" (tarjeta grande, texto
// personalizado con su nombre); con dos o más, el layout "04b" (lista de
// tarjetas).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/data/models/user_model.dart';
import '../../classroom/data/repository/classroom_repository.dart';

const _kBg          = Color(0xFFF7F6F3);
const _kPrimary     = Color(0xFF5B4A9E);
const _kTextDark    = Color(0xFF1E1B29);
const _kTextGray    = Color(0xFF666666);
const _kAvatarBg    = Color(0xFFD9D9D9);
const _kBadgeBg     = Color(0xFFEDE8FA);
const _kInfoBadgeBg = Color(0xFFDFEBF9);
const _kInfoBlue    = Color(0xFF1671E7);

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
    // Directo a la galería — sin bottom sheet de cámara/galería. La foto de
    // perfil de un hijo casi siempre ya existe en el rollo del padre.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    // Recorte cuadrado bloqueado (mismo formato que la foto de perfil de
    // WhatsApp) — el usuario no puede cambiar la proporción, solo mover/
    // acercar el encuadre dentro del cuadrado.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar foto',
          toolbarColor: _kPrimary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Ajustar foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploadingIds.add(child.id));
    try {
      final avatarUrl = await _classroomRepo.uploadAvatar(child.id.toString(), cropped.path);
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

  bool get _allPhotosUploaded => _children.every((c) => c.avatarUrl != null);

  void _onContinue() {
    if (!_allPhotosUploaded) return;
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

  String _subtitleParts(ChildModel c) {
    final parts = [
      if (c.section != null) c.section!,
      if (c.age != null) '${c.age} años',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = _children.length == 1;

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
                isSingle
                    ? 'Hola ${widget.user.firstName} 👋, encontramos a ${_children.first.firstName}'
                    : 'Hola ${widget.user.firstName} 👋, encontramos a tus hijos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTextDark),
              ),
              const SizedBox(height: 8),
              Text(
                isSingle
                    ? 'Sube una foto de ${_children.first.firstName} para continuar'
                    : 'Sube una foto de cada hijo para continuar',
                style: const TextStyle(fontSize: 12, color: _kTextGray),
              ),
              const SizedBox(height: 20),
              // "04c" (un solo hijo): la tarjeta va pegada al subtítulo, NO
              // centrada en la pantalla — por eso NO se envuelve en Expanded
              // acá, a diferencia de la lista de "04b" que sí necesita
              // Expanded para poder hacer scroll cuando hay varios hijos.
              if (isSingle)
                _ChildPhotoCard(
                  child: _children.first,
                  subtitle: _subtitleParts(_children.first),
                  uploading: _uploadingIds.contains(_children.first.id),
                  onTap: () => _pickAndUpload(_children.first),
                  large: true,
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ChildPhotoCard(
                      child: _children[i],
                      subtitle: _subtitleParts(_children[i]),
                      uploading: _uploadingIds.contains(_children[i].id),
                      onTap: () => _pickAndUpload(_children[i]),
                      large: false,
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
                    disabledBackgroundColor: _kPrimary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _allPhotosUploaded ? _onContinue : null,
                  child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(color: _kInfoBadgeBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.info_outline, size: 11, color: _kInfoBlue),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _allPhotosUploaded
                          ? 'Edítalo cuando quieras desde la pantalla de inicio'
                          : (isSingle
                              ? 'Toca la foto para poder continuar'
                              : 'Toca cada foto para poder continuar'),
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
    required this.subtitle,
    required this.uploading,
    required this.onTap,
    required this.large,
  });

  final ChildModel child;
  final String subtitle;
  final bool uploading;
  final VoidCallback onTap;
  // true → tarjeta "04c" (un solo hijo, avatar 100px). false → tarjeta
  // "04b" dentro de la lista (avatar 56px).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final avatarSize = large ? 100.0 : 56.0;
    final badgeSize = large ? 32.0 : 24.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: large ? 24 : 14, horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: uploading ? null : onTap,
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: child.avatarUrl != null
                        ? Image.network(
                            child.avatarUrl!,
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderCircle(avatarSize),
                          )
                        : _placeholderCircle(avatarSize),
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
                      right: -4,
                      bottom: -2,
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        decoration: const BoxDecoration(color: _kBadgeBg, shape: BoxShape.circle),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: badgeSize * 0.5,
                          color: _kPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: large ? 16 : 12),
          Text(
            child.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: large ? 18 : 15,
              fontWeight: FontWeight.w600,
              color: _kTextDark,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _kTextGray),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholderCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _kAvatarBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(Icons.person_outline, size: size * 0.45, color: _kTextGray),
    );
  }
}
