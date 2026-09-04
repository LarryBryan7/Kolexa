// ============================================================
// new_message_page.dart — Elegir a quién escribir
// ============================================================
// Solo lista contactos que /threads/contacts ya validó como permitidos (el
// backend aplica la misma regla al confirmar: comparten un alumno, o el
// destinatario es el director). Nunca se pide un id a mano.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/cached_avatar.dart';
import '../../../core/widgets/press_tint.dart';
import '../data/staleness_guard.dart';
import '../data/threads_local_store.dart';
import '../data/threads_repository.dart';
import 'thread_page.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kHeaderTitle = Color(0xFF444444);
const _kMsgDark = Color(0xFF111116);
const _kHeaderPillBg = Color(0xFFF0F0F0);
const _kOfflineDot = Color(0xFFCDCFCC);
const _kOnlineDot = Color(0xFF4CAF50);
const _kCardDivider = Color(0xFFE5E5EA);

// Paleta rotativa para los círculos de iniciales de hijos compartidos (no
// hay foto por alumno en el modelo — solo id/nombre — así que todos se
// muestran con iniciales, coloreadas de forma estable según su posición).
const _kStudentColors = [
  Color(0xFFCC49A1),
  Color(0xFFC99B49),
  Color(0xFF5B4A9E),
  Color(0xFF1E88A8),
];

const _kSvgMagnifyingGlass =
    '<svg width="17" height="17" viewBox="0 0 17 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.6165 15.29L12.9064 11.5783C14.0188 10.1286 14.5382 8.31013 14.3591 6.49165C14.1801 4.67318 13.316 2.99089 11.9422 1.78607C10.5684 0.581238 8.78776 -0.0559155 6.96147 0.00385482C5.13518 0.0636252 3.4 0.815844 2.10792 2.10792C0.815844 3.4 0.0636252 5.13518 0.00385482 6.96147C-0.0559155 8.78776 0.581238 10.5684 1.78607 11.9422C2.99089 13.316 4.67318 14.1801 6.49165 14.3591C8.31013 14.5382 10.1286 14.0188 11.5783 12.9064L15.2915 16.6205C15.3788 16.7077 15.4823 16.7768 15.5962 16.824C15.7102 16.8712 15.8323 16.8955 15.9556 16.8955C16.0789 16.8955 16.2011 16.8712 16.315 16.824C16.4289 16.7768 16.5325 16.7077 16.6197 16.6205C16.7069 16.5332 16.7761 16.4297 16.8232 16.3158C16.8704 16.2018 16.8947 16.0797 16.8947 15.9564C16.8947 15.8331 16.8704 15.7109 16.8232 15.597C16.7761 15.4831 16.7069 15.3795 16.6197 15.2923L16.6165 15.29ZM1.89076 7.20326C1.89076 6.15255 2.20234 5.12543 2.78608 4.2518C3.36983 3.37816 4.19952 2.69724 5.17026 2.29515C6.14099 1.89306 7.20916 1.78786 8.23968 1.99284C9.2702 2.19782 10.2168 2.70379 10.9598 3.44676C11.7027 4.18972 12.2087 5.13632 12.4137 6.16685C12.6187 7.19737 12.5135 8.26554 12.1114 9.23627C11.7093 10.207 11.0284 11.0367 10.1547 11.6204C9.28109 12.2042 8.25398 12.5158 7.20326 12.5158C5.79474 12.5143 4.44433 11.9541 3.44836 10.9582C2.45238 9.96219 1.89221 8.61178 1.89076 7.20326Z" fill="#666666"/>'
    '</svg>';

const _kSvgBackChevron =
    '<svg width="15" height="12" viewBox="0 0 15 12" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M0.75 6H13.5833M6.25 0.75L0.75 6L6.25 11.25" stroke="black" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgSliders =
    '<svg width="15" height="13" viewBox="0 0 15 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M11.875 2.5C11.875 2.33424 11.9408 2.17527 12.0581 2.05806C12.1753 1.94085 12.3342 1.875 12.5 1.875H14.375C14.5408 1.875 14.6997 1.94085 14.8169 2.05806C14.9342 2.17527 15 2.33424 15 2.5C15 2.66576 14.9342 2.82473 14.8169 2.94194C14.6997 3.05915 14.5408 3.125 14.375 3.125H12.5C12.3342 3.125 12.1753 3.05915 12.0581 2.94194C11.9408 2.82473 11.875 2.66576 11.875 2.5ZM0.625 3.125H8.125V4.375C8.125 4.54076 8.19085 4.69973 8.30806 4.81694C8.42527 4.93415 8.58424 5 8.75 5H10C10.1658 5 10.3247 4.93415 10.4419 4.81694C10.5592 4.69973 10.625 4.54076 10.625 4.375V0.625C10.625 0.45924 10.5592 0.300269 10.4419 0.183058C10.3247 0.0658481 10.1658 0 10 0H8.75C8.58424 0 8.42527 0.0658481 8.30806 0.183058C8.19085 0.300269 8.125 0.45924 8.125 0.625V1.875H0.625C0.45924 1.875 0.300269 1.94085 0.183058 2.05806C0.0658481 2.17527 0 2.33424 0 2.5C0 2.66576 0.0658481 2.82473 0.183058 2.94194C0.300269 3.05915 0.45924 3.125 0.625 3.125ZM14.375 9.375H7.5C7.33424 9.375 7.17527 9.44085 7.05806 9.55806C6.94085 9.67527 6.875 9.83424 6.875 10C6.875 10.1658 6.94085 10.3247 7.05806 10.4419C7.17527 10.5592 7.33424 10.625 7.5 10.625H14.375C14.5408 10.625 14.6997 10.5592 14.8169 10.4419C14.9342 10.3247 15 10.1658 15 10C15 9.83424 14.9342 9.67527 14.8169 9.55806C14.6997 9.44085 14.5408 9.375 14.375 9.375ZM5 7.5H3.75C3.58424 7.5 3.42527 7.56585 3.30806 7.68306C3.19085 7.80027 3.125 7.95924 3.125 8.125V9.375H0.625C0.45924 9.375 0.300269 9.44085 0.183058 9.55806C0.0658481 9.67527 0 9.83424 0 10C0 10.1658 0.0658481 10.3247 0.183058 10.4419C0.300269 10.5592 0.45924 10.625 0.625 10.625H3.125V11.875C3.125 12.0408 3.19085 12.1997 3.30806 12.3169C3.42527 12.4342 3.58424 12.5 3.75 12.5H5C5.16576 12.5 5.32473 12.4342 5.44194 12.3169C5.55915 12.1997 5.625 12.0408 5.625 11.875V8.125C5.625 7.95924 5.55915 7.80027 5.44194 7.68306C5.32473 7.56585 5.16576 7.5 5 7.5Z" fill="black"/>'
    '</svg>';

class NewMessagePage extends StatefulWidget {
  const NewMessagePage({super.key});

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();

  // Limpia el cache en memoria de contactos — se llama al cerrar sesión
  // (ver main.dart), mismo motivo que InboxPage.clearCache().
  static void clearCache() {
    _NewMessagePageState._cachedContacts = null;
    // Invalida cualquier _refresh()/_loadFromDisk() en vuelo de la cuenta
    // que se está cerrando — ver staleness_guard.dart.
    _NewMessagePageState._guard.invalidateAccount();
  }

  @visibleForTesting
  static List<Contact>? get debugCachedContacts => _NewMessagePageState._cachedContacts;

  @visibleForTesting
  static set debugCachedContacts(List<Contact>? value) => _NewMessagePageState._cachedContacts = value;

  @visibleForTesting
  static StalenessGuard get debugGuard => _NewMessagePageState._guard;
}

class _NewMessagePageState extends State<NewMessagePage> {
  // Cache en memoria a nivel de clase (mismo patrón que InboxPage): a
  // quién le podés escribir casi no cambia en medio de una sesión, así
  // que no hace falta pagar la carga de red cada vez que se abre esta
  // pantalla — se muestra lo último conocido al instante y se refresca
  // solo en segundo plano.
  static List<Contact>? _cachedContacts;

  // Guard de "respuesta obsoleta" — ver staleness_guard.dart.
  static final _guard = StalenessGuard();

  late final ThreadsRepository _repo;
  List<Contact>? _contacts;
  bool _loadingFirstTime = false;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repo = ThreadsRepository(context.read<ApiClient>());
    _contacts = _cachedContacts;
    if (_contacts == null) _loadFromDisk();
    _refresh(showErrorIfEmpty: true);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Contact> _applySearch(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    return contacts.where((c) {
      final name = c.name.toLowerCase();
      final students = c.students.map((s) => s.name.toLowerCase()).join(' ');
      return name.contains(_searchQuery) || students.contains(_searchQuery);
    }).toList();
  }

  // Lectura de disco en paralelo al `_refresh()` de red: a quién le podés
  // escribir casi no cambia entre sesiones, así que la última lista
  // conocida (guardada la vez anterior) alcanza para mostrar algo real de
  // inmediato en vez del spinner, incluso recién abierta la app.
  Future<void> _loadFromDisk() async {
    final epoch = _guard.beginAccountEpoch();
    final local = await ThreadsLocalStore.loadContacts();
    if (!mounted || !_guard.isAccountCurrent(epoch) || local.isEmpty || _contacts != null) return;
    _cachedContacts = local;
    setState(() {
      _contacts = local;
      _loadingFirstTime = false;
    });
  }

  // Refresco silencioso: nunca borra `_contacts` antes de tener el
  // resultado nuevo, así la lista ya cargada se queda visible mientras se
  // pide de nuevo. El spinner de pantalla completa solo aparece si de
  // verdad no hay nada que mostrar todavía (primera vez en la sesión).
  Future<void> _refresh({bool showErrorIfEmpty = false}) async {
    final epoch = _guard.beginAccountEpoch();
    final seq = _guard.beginSequence();
    if (_contacts == null) setState(() => _loadingFirstTime = true);
    try {
      final contacts = await _repo.getContacts();
      if (!_guard.isCurrent(epoch, seq)) return;
      _cachedContacts = contacts;
      ThreadsLocalStore.saveContacts(contacts).catchError((e, st) {
        debugPrint('[NewMessagePage] saveContacts falló: $e\n$st');
      });
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _error = null;
        _loadingFirstTime = false;
      });
    } catch (e) {
      if (!_guard.isCurrent(epoch, seq)) return;
      if (!mounted) return;
      setState(() => _loadingFirstTime = false);
      if (showErrorIfEmpty && _contacts == null) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // Busca en la bandeja ya conocida (disco, mantenida al día por
  // InboxSyncService en segundo plano) un hilo directo con este contacto
  // sobre el mismo alumno — mismo criterio de "mismo par + mismo alumno"
  // que usa ThreadsService.openThread para reutilizar hilos del lado del
  // backend.
  Future<ThreadSummary?> _findExistingThread(Contact c, ThreadStudentRef? student) async {
    final threads = await ThreadsLocalStore.loadInbox();
    for (final t in threads) {
      if (t.otherParticipant?.id == c.userId && t.studentId == student?.id) return t;
    }
    return null;
  }

  Future<void> _pick(Contact c) async {
    ThreadStudentRef? student;
    if (c.students.length == 1) {
      student = c.students.first;
    } else if (c.students.length > 1) {
      student = await showModalBottomSheet<ThreadStudentRef>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 17, 16, 10),
                child: Text('¿Sobre cuál de tus hijos?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextDark)),
              ),
              ...c.students.asMap().entries.map((e) => _StudentPickRow(
                    student: e.value,
                    colorIndex: e.key,
                    onTap: () => Navigator.pop(context, e.value),
                  )),
            ],
          ),
        ),
      );
      if (student == null) return; // canceló el selector
    }

    if (!mounted) return;

    // Una sola pantalla para los dos casos — ThreadPage: si ya existe una
    // conversación con este contacto (mismo alumno, si aplica) se le pasa
    // su threadId y entra directo con todo el historial; si es de verdad
    // nueva, se le pasa el recipientId en su lugar y ThreadPage crea el
    // hilo recién al mandar el primer mensaje (ver
    // _ThreadPageState._sendBody). Ya no hay una pantalla aparte de
    // "primer mensaje" con otro diseño.
    final existing = await _findExistingThread(c, student);
    if (!mounted) return;
    Navigator.of(context).pop(true); // avisa a InboxPage que refresque
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadPage(
          threadId: existing?.id,
          recipientId: existing == null ? c.userId : null,
          title: c.name,
          avatarUrl: c.avatar,
          online: c.online,
          // Ya se conoce sin depender del backend de ThreadSummary — el
          // Contact elegido ES la otra persona, sea hilo nuevo o existente.
          otherRole: c.role,
          studentId: student?.id,
          studentName: student?.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: _kHeaderPillBg, borderRadius: BorderRadius.circular(20)),
                    child: PressTint(
                      onTap: () => Navigator.pop(context),
                      tintColor: pressedTint(_kHeaderPillBg),
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: SvgPicture.string(_kSvgBackChevron, width: 15, height: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Nuevo Mensaje',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: _kHeaderTitle)),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: _kHeaderPillBg, borderRadius: BorderRadius.circular(20)),
                    child: PressTint(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aún no disponible')),
                      ),
                      tintColor: pressedTint(_kHeaderPillBg),
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: SvgPicture.string(_kSvgSliders, width: 15, height: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                height: 37,
                padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
                decoration:
                    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    SvgPicture.string(_kSvgMagnifyingGlass, width: 17, height: 17),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w300),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Busca a quien quieres enviarle un mensaje',
                          hintStyle:
                              TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w300),
                        ),
                        textAlignVertical: TextAlignVertical.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_loadingFirstTime) {
                    return const Center(child: CircularProgressIndicator(color: _kPrimary));
                  }
                  if (_error != null) {
                    return Center(
                      child: Text(_error!, style: const TextStyle(color: _kTextGray)),
                    );
                  }
                  final contacts = _applySearch(_contacts ?? []);
                  if ((_contacts ?? []).isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Todavía no hay a quién escribirle. Esto aparece una vez que tengas un aula o un hijo matriculado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kTextGray),
                        ),
                      ),
                    );
                  }
                  if (contacts.isEmpty) {
                    return const Center(
                      child: Text('Sin resultados', style: TextStyle(color: _kTextGray)),
                    );
                  }
                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, i) => _ContactRow(
                      contact: contacts[i],
                      onTap: () => _pick(contacts[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fila del bottom sheet "¿Sobre cuál de tus hijos?": círculo de iniciales
// (mismo criterio de color estable por posición que _StudentAvatarStack) +
// nombre completo.
class _StudentPickRow extends StatelessWidget {
  final ThreadStudentRef student;
  final int colorIndex;
  final VoidCallback onTap;
  const _StudentPickRow({required this.student, required this.colorIndex, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13.5,
              backgroundColor: _kStudentColors[colorIndex % _kStudentColors.length],
              backgroundImage:
                  student.avatar != null ? cachedAvatarProvider(student.avatar!) : null,
              child: student.avatar == null
                  ? Text(_initials(student.name),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600))
                  : null,
            ),
            const SizedBox(width: 12),
            Text(student.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kTextGray)),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  const _ContactRow({required this.contact, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final subtitle = c.role == 'teacher'
        ? 'Docente${c.students.isNotEmpty ? ' · ${c.students.map((s) => s.name).join(', ')}' : ''}'
        : c.role == 'parent'
            ? 'Apoderado${c.students.isNotEmpty ? ' · ${c.students.map((s) => s.name).join(', ')}' : ''}'
            : 'Dirección del colegio';

    return Container(
      color: Colors.white,
      child: PressTint(
        onTap: onTap,
        tintColor: pressedTint(Colors.white),
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          // Mínimo 70 (como en Figma) pero puede crecer si el subtítulo
          // pasa a 2 líneas — fijarlo en 70 siempre dejaba casi sin
          // margen antes del separador en ese caso.
          constraints: const BoxConstraints(minHeight: 70),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 10, top: 11, bottom: 10),
                child: Row(
                  // Arriba fijo, no centrado: si el subtítulo pasa a 2
                  // líneas, el nombre no debe correrse — en Figma el
                  // nombre siempre arranca en la misma posición.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
                          ),
                          child: CircleAvatar(
                            radius: 17.5,
                            backgroundColor: _kPrimaryLt,
                            backgroundImage:
                                c.avatar != null ? cachedAvatarProvider(c.avatar!) : null,
                            child: c.avatar == null
                                ? Text(_initials(c.name),
                                    style: const TextStyle(
                                        color: _kPrimary, fontWeight: FontWeight.w700, fontSize: 13))
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 3,
                          bottom: 5,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c.online ? _kOnlineDot : _kOfflineDot,
                              shape: BoxShape.circle,
                              border: const Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, color: _kMsgDark)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: _kHeaderTitle)),
                        ],
                      ),
                    ),
                    if (c.students.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      // Baja para quedar a la altura del subtítulo (el
                      // renglón del rol), no del nombre — mismo criterio
                      // que Figma.
                      Padding(
                        padding: const EdgeInsets.only(top: 21),
                        child: _StudentAvatarStack(students: c.students),
                      ),
                    ],
                  ],
                ),
              ),
              // El separador arranca alineado con el texto (no con el
              // avatar) y llega hasta el borde derecho de la tarjeta.
              const Positioned(
                left: 60,
                right: 0,
                bottom: 0,
                child: Divider(height: 1, thickness: 1, color: _kCardDivider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Círculos superpuestos con las iniciales de los hijos en común — no hay
// foto por alumno en el modelo, así que siempre son iniciales, coloreadas
// de forma estable según su posición en la lista.
class _StudentAvatarStack extends StatelessWidget {
  final List<ThreadStudentRef> students;
  const _StudentAvatarStack({required this.students});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final visible = students.take(2).toList();
    final extra = students.length - visible.length;
    final slots = visible.length + (extra > 0 ? 1 : 0);
    const circle = 20.0;
    const step = 14.0;

    return SizedBox(
      width: circle + (slots - 1) * step,
      height: circle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg, width: 2),
                ),
                child: CircleAvatar(
                  radius: circle / 2,
                  backgroundColor: _kStudentColors[i % _kStudentColors.length],
                  backgroundImage: visible[i].avatar != null
                      ? cachedAvatarProvider(visible[i].avatar!)
                      : null,
                  child: visible[i].avatar == null
                      ? Text(_initials(visible[i].name),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 6, fontWeight: FontWeight.w600))
                      : null,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * step,
              child: Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD9D9D9),
                  border: Border.all(color: _kBg, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$extra',
                    style: const TextStyle(
                        color: _kTextGray, fontSize: 6, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
