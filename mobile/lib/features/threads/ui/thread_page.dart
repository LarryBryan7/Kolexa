// ============================================================
// thread_page.dart — Una conversación
// ============================================================
// Soporta menciones de tareas con "@": al escribir @ se busca entre las
// tareas del aula del alumno de este hilo (mismo criterio de permisos que
// ya aplica el backend) y, al elegir una, queda como un chip tocable dentro
// del mensaje que lleva directo a esa tarea — ver conversación sobre
// "@tarea_mañana" del 30-08-2026.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/manufacturer_settings_service.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../homework/bloc/homework_bloc.dart';
import '../../homework/data/datasources/homework_remote_datasource.dart';
import '../../homework/data/repositories/homework_repository.dart';
import '../../homework/ui/homework_page.dart';
import '../data/threads_repository.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
// Paleta propia de la mensajería (distinta del violeta de marca general):
// medida tal cual del diseño de Figma "thread_page - Chat Padre".
const _kAccent = Color(0xFF9F6CF3);
const _kBubbleMine = Color(0xFFB489F9);
const _kOffWhite = Color(0xFFFFF1FF);
const _kHeaderPillBg = Color(0xFFF0F0F0);
const _kDateChipText = Color(0xFF777777);
const _kMsgDark = Color(0xFF111116);
const _kOfflineDot = Color(0xFFCDCFCC);
const _kOnlineDot = Color(0xFF4CAF50);
const _kClipboardBlue = Color(0xFF186DE8);
const _kCardDivider = Color(0xFFE5E5EA);
const _kComposerHint = Color(0xFF8D8C8C);

const _kSvgBackChevron =
    '<svg width="15" height="12" viewBox="0 0 15 12" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M0.75 6H13.5833M6.25 0.75L0.75 6L6.25 11.25" stroke="black" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgInfoCircle =
    '<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M9.75 0C7.82164 0 5.93657 0.571828 4.33319 1.64317C2.72982 2.71452 1.48013 4.23726 0.742179 6.01884C0.00422452 7.80042 -0.188858 9.76082 0.187348 11.6521C0.563554 13.5434 1.49215 15.2807 2.85571 16.6443C4.21928 18.0079 5.95656 18.9365 7.84787 19.3127C9.73919 19.6889 11.6996 19.4958 13.4812 18.7578C15.2627 18.0199 16.7855 16.7702 17.8568 15.1668C18.9282 13.5634 19.5 11.6784 19.5 9.75C19.4973 7.16498 18.4692 4.68661 16.6413 2.85872C14.8134 1.03084 12.335 0.00272983 9.75 0ZM9.375 4.5C9.59751 4.5 9.81502 4.56598 10 4.6896C10.185 4.81321 10.3292 4.98891 10.4144 5.19448C10.4995 5.40005 10.5218 5.62625 10.4784 5.84448C10.435 6.06271 10.3278 6.26316 10.1705 6.4205C10.0132 6.57783 9.81271 6.68498 9.59448 6.72838C9.37625 6.77179 9.15005 6.74951 8.94449 6.66436C8.73892 6.57922 8.56322 6.43502 8.4396 6.25002C8.31598 6.06501 8.25 5.8475 8.25 5.625C8.25 5.32663 8.36853 5.04048 8.57951 4.8295C8.79049 4.61853 9.07664 4.5 9.375 4.5ZM10.5 15C10.1022 15 9.72065 14.842 9.43934 14.5607C9.15804 14.2794 9 13.8978 9 13.5V9.75C8.80109 9.75 8.61033 9.67098 8.46967 9.53033C8.32902 9.38968 8.25 9.19891 8.25 9C8.25 8.80109 8.32902 8.61032 8.46967 8.46967C8.61033 8.32902 8.80109 8.25 9 8.25C9.39783 8.25 9.77936 8.40804 10.0607 8.68934C10.342 8.97064 10.5 9.35218 10.5 9.75V13.5C10.6989 13.5 10.8897 13.579 11.0303 13.7197C11.171 13.8603 11.25 14.0511 11.25 14.25C11.25 14.4489 11.171 14.6397 11.0303 14.7803C10.8897 14.921 10.6989 15 10.5 15Z" fill="black"/>'
    '</svg>';

const _kSvgClipboardList =
    '<svg width="8" height="11" viewBox="0 0 8 11" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M2.38571 1.51587H1.44286C1.1928 1.51587 0.952976 1.6229 0.776156 1.81342C0.599336 2.00393 0.5 2.26232 0.5 2.53175V8.62698C0.5 8.89641 0.599336 9.1548 0.776156 9.34532C0.952976 9.53583 1.1928 9.64286 1.44286 9.64286H6.15714C6.4072 9.64286 6.64702 9.53583 6.82384 9.34532C7.00066 9.1548 7.1 8.89641 7.1 8.62698V2.53175C7.1 2.26232 7.00066 2.00393 6.82384 1.81342C6.64702 1.6229 6.4072 1.51587 6.15714 1.51587H5.21429M2.38571 1.51587C2.38571 1.24645 2.48505 0.988055 2.66187 0.797542C2.83869 0.607029 3.07851 0.5 3.32857 0.5H4.27143C4.52149 0.5 4.76131 0.607029 4.93813 0.797542C5.11495 0.988055 5.21429 1.24645 5.21429 1.51587M2.38571 1.51587C2.38571 1.7853 2.48505 2.04369 2.66187 2.2342C2.83869 2.42472 3.07851 2.53175 3.32857 2.53175H4.27143C4.52149 2.53175 4.76131 2.42472 4.93813 2.2342C5.11495 2.04369 5.21429 1.7853 5.21429 1.51587M2.38571 5.07143H2.39043M4.27143 5.07143H5.21429M2.38571 7.10317H2.39043M4.27143 7.10317H5.21429" stroke="#186DE8" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgPaperPlane =
    '<svg width="16" height="18" viewBox="0 0 16 18" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15.6212 8.73792C15.6218 8.96063 15.5629 9.17945 15.4505 9.37175C15.3382 9.56404 15.1765 9.72282 14.9822 9.83167L1.86341 17.3325C1.67516 17.4392 1.46262 17.4957 1.24623 17.4965C1.04684 17.4954 0.85061 17.4467 0.673907 17.3543C0.497204 17.262 0.345159 17.1287 0.230465 16.9656C0.115771 16.8025 0.0417554 16.6143 0.0145977 16.4168C-0.0125599 16.2193 0.00792809 16.0181 0.0743514 15.8301L2.18373 9.58402C2.20434 9.52295 2.24333 9.46975 2.29536 9.43171C2.34739 9.39367 2.40991 9.37264 2.47435 9.37152H8.12123C8.20691 9.3717 8.29171 9.35427 8.37037 9.32031C8.44903 9.28634 8.51986 9.23656 8.57848 9.17407C8.63709 9.11157 8.68223 9.0377 8.71108 8.95702C8.73994 8.87635 8.7519 8.7906 8.74623 8.70511C8.73205 8.54439 8.65769 8.39497 8.53803 8.28675C8.41837 8.17853 8.26224 8.11951 8.10091 8.12152H2.47591C2.41053 8.12152 2.3468 8.10102 2.29368 8.0629C2.24056 8.02478 2.20074 7.97096 2.17982 7.90902L0.0704452 1.6637C-0.0135124 1.42432 -0.0226497 1.16506 0.0442468 0.920366C0.111143 0.675669 0.250907 0.457117 0.444972 0.293743C0.639036 0.130369 0.878215 0.0299075 1.13073 0.00570365C1.38325 -0.0185002 1.63716 0.0346995 1.85873 0.158235L14.9837 7.64964C15.1769 7.75824 15.3378 7.91625 15.4498 8.10748C15.5618 8.29872 15.621 8.51629 15.6212 8.73792Z" fill="#FFF1FF"/>'
    '</svg>';

// "@[Título](homework:123)" para tareas institucionales o
// "@[Título](gc-coursework:456)" para tareas sincronizadas de Google
// Classroom — texto plano dentro de body, no una tabla aparte. El título
// queda fijo tal como se vio al escribir; el enlace navega por id, así que
// si la tarea cambia (fecha, entregada) el destino sigue siendo el actual.
final RegExp _mentionRe = RegExp(r'@\[(.*?)\]\((homework|gc-coursework):(\d+)\)');

// Controller que, mientras se compone el mensaje, PINTA el markup de una
// mención como un chip compacto ("@Título") en vez del texto crudo
// "@[Título](tipo:id)" — sin tocar el texto real: `text`/`selection`
// siguen siendo el markup completo (lo que de verdad se manda al enviar),
// solo cambia lo que EditableText dibuja en pantalla. Es la forma
// soportada por Flutter de mezclar un widget dentro de un campo de texto
// editable: TextEditingController.buildTextSpan() puede devolver
// WidgetSpan, no solo TextSpan de texto plano.
class _MentionComposerController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in _mentionRe.allMatches(source)) {
      if (m.start > last) {
        spans.add(TextSpan(text: source.substring(last, m.start), style: style));
      }
      final start = m.start;
      final end = m.end;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _MentionChip(
          label: m.group(1)!,
          // Deshacer la mención: la saca del texto (no solo la oculta) —
          // vuelve a quedar como si nunca se hubiera elegido.
          onRemove: () {
            final current = text;
            if (end > current.length) return; // el texto ya cambió, no tocar
            final newText = current.replaceRange(start, end, '');
            value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: start.clamp(0, newText.length)),
            );
          },
        ),
      ));
      last = m.end;
    }
    if (last < source.length) {
      spans.add(TextSpan(text: source.substring(last), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

// Chip compacto tipo Material "input chip": título + botón para deshacer
// la mención. Vive DENTRO del campo de texto como WidgetSpan — por eso el
// tamaño se mantiene chico (no puede competir en alto con la línea de
// texto que lo rodea) y el ancho tiene un tope con elipsis, para que un
// título largo no rompa el layout de una sola línea del compositor.
class _MentionChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _MentionChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.only(left: 8, right: 3),
      decoration: BoxDecoration(
        color: _kPrimaryLt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: _kAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class ThreadPage extends StatefulWidget {
  final String threadId;
  final String title;
  final String? avatarUrl;
  final bool online;
  final String? studentId;
  final String? studentName;

  const ThreadPage({
    super.key,
    required this.threadId,
    required this.title,
    this.avatarUrl,
    this.online = false,
    this.studentId,
    this.studentName,
  });

  @override
  State<ThreadPage> createState() => _ThreadPageState();

  // Le permite a InboxPage "adelantar" el último mensaje conocido al cache
  // de este chat ANTES de navegar — si un mensaje llegó mientras el chat
  // estaba cerrado, solo se actualizaba el cache de la bandeja, y este
  // chat mostraba la versión vieja un instante hasta que su propio fetch
  // resolvía (ver InboxPage._openThread). Se ignora si ya está reflejado
  // o si es más vieja que lo que el cache ya tiene.
  static void seedLastMessage(String threadId, ThreadPreview preview) {
    final existing = _ThreadPageState._cache[threadId];
    final lastCached = existing?.messages.isNotEmpty == true ? existing!.messages.last : null;
    if (lastCached != null && !preview.sentAt.isAfter(lastCached.sentAt)) return;
    final synthetic = ThreadMessage(
      id: 'preview-${preview.sentAt.microsecondsSinceEpoch}',
      senderId: preview.senderId,
      senderName: '',
      body: preview.body,
      sentAt: preview.sentAt,
    );
    _ThreadPageState._cache[threadId] = ThreadMessagesPage(
      messages: [...(existing?.messages ?? []), synthetic],
      otherLastReadAt: existing?.otherLastReadAt,
      otherLastActiveAt: existing?.otherLastActiveAt,
    );
  }
}

class _ThreadPageState extends State<ThreadPage> with WidgetsBindingObserver {
  // Cache en memoria por hilo: sobrevive a que la pantalla se destruya y
  // se recree (ej. salir y volver a entrar a la misma conversación), así
  // que reabrirla muestra los mensajes al instante mientras se refrescan
  // solos en segundo plano.
  static final Map<String, ThreadMessagesPage> _cache = {};

  late final ThreadsRepository _repo;
  late final int _myUserId;
  late final List<String> _myRoles;
  final _controller = _MentionComposerController();
  final _scroll = ScrollController();
  List<ThreadMessage>? _messages;
  DateTime? _otherLastReadAt;
  DateTime? _otherLastActiveAt;
  bool _loadingFirstTime = false;
  String? _error;
  // Mensajes propios ya "enviados" del lado del usuario (aparecen al
  // instante, con relojito) pero que el backend todavía no confirmó — se
  // mantienen aparte de `_messages` (que es la lista que el servidor ya
  // confirmó) para que un refresh concurrente por otra razón (push de
  // otro hilo, resume de background) nunca los borre de golpe mientras
  // el envío sigue en vuelo.
  List<ThreadMessage> _pendingMessages = [];

  // ── Autocompletado de "@" ──────────────────────────────────
  Timer? _mentionDebounce;
  int? _mentionStart; // índice del "@" que disparó la búsqueda actual
  List<MentionCandidate>? _mentionResults;

  @override
  void initState() {
    super.initState();
    _repo = ThreadsRepository(context.read<ApiClient>());
    final authState = context.read<AuthBloc>().state;
    _myUserId = authState is AuthAuthenticated ? authState.user.id : -1;
    _myRoles = authState is AuthAuthenticated ? authState.user.roles : const [];
    _controller.addListener(_onTextChanged);
    _messages = _cache[widget.threadId]?.messages;
    _otherLastReadAt = _cache[widget.threadId]?.otherLastReadAt;
    _otherLastActiveAt = _cache[widget.threadId]?.otherLastActiveAt;
    _load();
    // Se marca leído al entrar: si el otro responde mientras se lee, el
    // siguiente refresh de la bandeja ya no lo mostrará como pendiente.
    _markRead();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationsService.instance.addDataRefreshListener(_handleDataRefresh);
  }

  // markRead solo se llamaba en initState (al ENTRAR al chat) — un mensaje
  // que llega mientras el chat ya está abierto (por push, sin salir/volver
  // a entrar) nunca se marcaba como leído, aunque el usuario lo esté
  // viendo en pantalla. Eso rompía dos cosas: la bandeja lo mostraba como
  // no leído al volver, y el que lo mandó nunca recibía el push silencioso
  // de "te leyeron" (ver markRead en el backend), así que su doble check
  // no se actualizaba. Se centraliza acá para llamarlo en los 3 momentos
  // en que un mensaje puede "aparecer visto": al entrar, al llegar uno
  // nuevo con el chat ya abierto, y al volver de background con el chat
  // todavía en pantalla.
  void _markRead() {
    _repo.markRead(widget.threadId).catchError((_) {});
  }

  // Push de un mensaje nuevo en ESTA conversación → se refresca sola. Se
  // filtra por threadId para no recargar cuando llega un mensaje de otra
  // conversación distinta que el usuario no tiene abierta.
  void _handleDataRefresh(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['screen'] == 'thread' && data['threadId'] == widget.threadId) {
      _load();
      _markRead();
    }
  }

  // Red de seguridad si el push no llegó (conocido en gama baja/media):
  // al volver del background, se refresca igual.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _markRead();
    }
  }

  // Refresco que nunca borra `_messages` antes de tener el resultado
  // nuevo: la conversación ya cargada se queda visible mientras se pide de
  // nuevo (a diferencia del FutureBuilder anterior, que volvía a mostrar
  // el loader — y tapaba toda la charla — cada vez que llegaba un mensaje
  // nuevo por push). El spinner de pantalla completa solo aparece en la
  // primera carga, cuando todavía no hay nada que mostrar.
  //
  // La lista se pinta con `reverse: true` (ver build()): el offset 0 del
  // scroll siempre corresponde al mensaje más reciente, así que "quedarse
  // pegado abajo" al llegar un mensaje nuevo es automático — mientras el
  // usuario no haya scrolleado hacia arriba, no hace falta mover el scroll
  // a mano, y si sí scrolleó a leer mensajes viejos, tampoco se lo
  // interrumpe (su offset absoluto no cambia solo porque llegó algo nuevo).
  // Antes se intentaba "saltar al final" a mano después de cada carga —
  // eso fue la causa de dos bugs reales: un salto visible animado, y
  // (con datos ya en caché) un frame de más mostrando el scroll en su
  // posición por defecto antes de saltar. `reverse: true` elimina el
  // problema de raíz en vez de parchear el timing otra vez.
  Future<void> _load({bool forceScroll = false}) async {
    if (_messages == null) setState(() => _loadingFirstTime = true);
    try {
      final page = await _repo.getMessages(widget.threadId);
      _cache[widget.threadId] = page;
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _otherLastReadAt = page.otherLastReadAt;
        _otherLastActiveAt = page.otherLastActiveAt;
        _error = null;
        _loadingFirstTime = false;
      });
      // El único caso que sí necesita empujar el scroll a mano: el propio
      // usuario acaba de enviar un mensaje (puede estar leyendo historial
      // arriba) y tiene que ver su mensaje nuevo sí o sí.
      if (forceScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFirstTime = false;
        // Un refresh silencioso que falla no debe tapar la conversación ya
        // cargada con una pantalla de error — solo se muestra si no hay
        // nada que mostrar todavía.
        if (_messages == null) _error = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // Con `reverse: true`, el offset 0 es visualmente el final (el
    // mensaje más reciente) — no `maxScrollExtent` como en una lista
    // normal.
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // Detecta si el cursor está justo después de un "@" sin espacios de por
  // medio (ej. "hola @tar|" sí, "hola @tar |" no) y dispara la búsqueda.
  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return _clearMentions();

    final upToCursor = text.substring(0, cursor);
    final at = upToCursor.lastIndexOf('@');
    if (at == -1) return _clearMentions();
    final afterAt = upToCursor.substring(at + 1);
    // Los títulos de tarea suelen tener varias palabras ("Tarea de
    // mañana: ejercicios de fracciones") — un espacio simple NO corta la
    // búsqueda (antes sí, y por eso buscar "mi calendario" nunca
    // encontraba nada: se cortaba en "mi"). Sí corta si la mención ya
    // quedó cerrada con `]` (una insertada antes en el mismo mensaje), si
    // hay un salto de línea, o como tope de seguridad si el texto después
    // del @ ya es demasiado largo para ser un título.
    if (afterAt.contains(']') || afterAt.contains('\n') || afterAt.length > 60) {
      return _clearMentions();
    }

    final query = afterAt;
    _mentionStart = at;
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _repo.searchMentions(widget.threadId, query);
        if (mounted && _mentionStart == at) setState(() => _mentionResults = results);
      } catch (_) {
        // Sin conexión momentánea: no interrumpe la escritura, solo no
        // aparecen sugerencias esta vez.
      }
    });
  }

  void _clearMentions() {
    if (_mentionStart == null && _mentionResults == null) return;
    _mentionDebounce?.cancel();
    setState(() {
      _mentionStart = null;
      _mentionResults = null;
    });
  }

  void _insertMention(MentionCandidate c) {
    final start = _mentionStart;
    if (start == null) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final replacement = '@[${c.title}](${c.type}:${c.id}) ';
    final newText = text.replaceRange(start, cursor, replacement);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _clearMentions();
  }

  void _openMention(String type, String refId) {
    if (type == 'gc-coursework') {
      _openClassroomTask(refId);
    } else {
      _openHomework(refId);
    }
  }

  // Solo un padre puede abrir la tarea de su hijo (el backend exige ser su
  // tutor). Si quien mencionó es el propio docente, se le avisa dónde verla
  // en vez de navegar a una pantalla que le devolvería un error de permiso.
  void _openHomework(String homeworkId) {
    if (!_myRoles.contains('parent') || widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes verla en la sección de Tareas de esa aula.')),
      );
      return;
    }
    final api = context.read<ApiClient>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => HomeworkBloc(HomeworkRepository(HomeworkRemoteDataSource(api))),
          child: HomeworkParentPage(
            studentId: int.parse(widget.studentId!),
            studentName: widget.studentName ?? '',
            highlightHomeworkId: int.parse(homeworkId),
          ),
        ),
      ),
    );
  }

  // La tarea de Classroom no tiene pantalla propia dentro de KOLEXA — el
  // mensaje solo guardó id + título, así que el link real se resuelve acá
  // (validado por participación en el hilo) y se abre igual que el botón
  // "Ver en classroom" del resto de la app.
  Future<void> _openClassroomTask(String refId) async {
    String? link;
    try {
      link = await _repo.getClassroomTaskLink(widget.threadId, refId);
    } catch (_) {
      link = null;
    }
    if (link == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir esta tarea de Classroom.')),
      );
      return;
    }
    final openedNative = await ManufacturerSettingsService.instance.openExternalUrl(link);
    if (openedNative) return;
    final uri = Uri.tryParse(link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    _controller.clear();
    await _sendBody(body);
  }

  // Envío optimista, estilo WhatsApp: el mensaje aparece al instante con
  // un relojito (pendiente) en vez de tapar la pantalla con un spinner
  // mientras se espera al servidor. Se guarda aparte en `_pendingMessages`
  // (no en `_messages`) para que un refresh concurrente por otra razón
  // (push de otro hilo, resume de background) nunca lo borre de golpe
  // mientras el envío sigue en vuelo. Si falla, la burbuja queda marcada
  // para poder tocarla y reintentar.
  Future<void> _sendBody(String body) async {
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ThreadMessage(
      id: tempId,
      senderId: _myUserId.toString(),
      senderName: '',
      body: body,
      sentAt: DateTime.now(),
      isPending: true,
    );
    SystemSound.play(SystemSoundType.click);
    setState(() => _pendingMessages = [..._pendingMessages, pending]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    try {
      final sent = await _repo.sendMessage(widget.threadId, body);
      if (!mounted) return;
      // Con el id/sentAt reales ya alcanza para reconciliar — senderId
      // (soy yo) y body (lo que mandé) ya se conocen, así que no hace
      // falta un getMessages() completo solo para confirmar este mensaje
      // (era un round-trip entero de más, a una base que está lejos —
      // sa-east-1 — en CADA mensaje enviado). Sacar el pendiente y meter
      // el confirmado en el MISMO setState, igual que antes, para no
      // reintroducir el parpadeo (un frame sin el mensaje en ninguna
      // lista).
      final confirmed = ThreadMessage(
        id: sent.id,
        senderId: _myUserId.toString(),
        senderName: '',
        body: body,
        sentAt: sent.sentAt,
      );
      final alreadyPresent = (_messages ?? []).any((m) => m.id == confirmed.id);
      setState(() {
        _pendingMessages = _pendingMessages.where((m) => m.id != tempId).toList();
        if (!alreadyPresent) _messages = [...(_messages ?? []), confirmed];
      });
      // El cache en memoria también se actualiza a mano, para que si se
      // reabre este hilo (sin volver a pedirle nada al backend) el
      // mensaje ya esté ahí.
      _cache[widget.threadId] = ThreadMessagesPage(
        messages: _messages!,
        otherLastReadAt: _otherLastReadAt,
        otherLastActiveAt: _otherLastActiveAt,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingMessages = _pendingMessages
            .map((m) => m.id == tempId ? m.copyWith(isFailed: true) : m)
            .toList();
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _retrySend(ThreadMessage failed) {
    setState(() => _pendingMessages = _pendingMessages.where((m) => m.id != failed.id).toList());
    _sendBody(failed.body);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationsService.instance.removeDataRefreshListener(_handleDataRefresh);
    _mentionDebounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(color: _kHeaderPillBg, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: SvgPicture.string(_kSvgBackChevron, width: 15, height: 12),
                    ),
                  ),
                  // El avatar+título van centrados en el espacio entre los
                  // dos botones circulares (no pegados al de "atrás") —
                  // así está balanceado en Figma.
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 18.5,
                              backgroundColor: _kPrimaryLt,
                              backgroundImage: widget.avatarUrl != null
                                  ? NetworkImage(widget.avatarUrl!)
                                  : null,
                              child: widget.avatarUrl == null
                                  ? Text(
                                      widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          color: _kAccent, fontWeight: FontWeight.w700),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: widget.online ? _kOnlineDot : _kOfflineDot,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: _kBg, width: 1)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _kMsgDark,
                                  height: 1.2)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: _kHeaderPillBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: SvgPicture.string(_kSvgInfoCircle, width: 20, height: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                if (_messages == null) {
                  if (_loadingFirstTime) {
                    return const Center(child: CircularProgressIndicator(color: _kAccent));
                  }
                  if (_error != null) {
                    return Center(
                      child: TextButton(onPressed: _load, child: const Text('Reintentar')),
                    );
                  }
                }
                // Los mensajes ya confirmados por el servidor + los que el
                // propio usuario acaba de mandar y todavía están en vuelo
                // (con relojito) — siempre van al final, en el orden en que
                // se dispararon.
                final messages = [...(_messages ?? []), ..._pendingMessages];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Escribe el primer mensaje',
                        style: TextStyle(color: _kTextGray)),
                  );
                }
                // Intercala un marcador de día ("Hoy", "Ayer", fecha) antes
                // del primer mensaje de cada día distinto — misma lista
                // plana en orden cronológico que después se recorre al
                // revés, igual que los mensajes.
                final items = <Object>[];
                DateTime? lastDay;
                for (final m in messages) {
                  final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
                  if (lastDay == null || day != lastDay) {
                    items.add(day);
                    lastDay = day;
                  }
                  items.add(m);
                }
                return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      // `items` sigue en orden cronológico (viejo→nuevo);
                      // con `reverse: true` el índice 0 de la lista es el
                      // que se pinta abajo del todo, así que hay que
                      // invertir el mapeo acá.
                      final item = items[items.length - 1 - i];
                      if (item is DateTime) return _DateChip(day: item);
                      final message = item as ThreadMessage;
                      final isMine = message.senderId == _myUserId.toString();
                      return _Bubble(
                        message: message,
                        isMine: isMine,
                        // El doble check solo tiene sentido en mensajes
                        // propios ya confirmados — nunca en los pendientes.
                        // Cuenta como "entregado" tanto si el otro leyó
                        // este hilo como si simplemente estuvo online
                        // (activo) después de que se envió — no hace falta
                        // que haya abierto la conversación puntual para
                        // saber que "ya le llegó".
                        isRead: isMine &&
                            !message.isPending &&
                            ((_otherLastReadAt != null && !_otherLastReadAt!.isBefore(message.sentAt)) ||
                                (_otherLastActiveAt != null &&
                                    !_otherLastActiveAt!.isBefore(message.sentAt))),
                        onOpenMention: _openMention,
                        onRetry: message.isFailed ? () => _retrySend(message) : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (_mentionResults != null) _MentionSuggestions(results: _mentionResults!, onPick: _insertMention),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFBA3428), fontSize: 12)),
              ),
            _Composer(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

// Separador de día entre mensajes ("Hoy", "Ayer" o la fecha).
class _DateChip extends StatelessWidget {
  final DateTime day;
  const _DateChip({required this.day});

  String get _label {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (day.year == today.year && day.month == today.month && day.day == today.day) return 'Hoy';
    if (day.year == yesterday.year && day.month == yesterday.month && day.day == yesterday.day) {
      return 'Ayer';
    }
    return DateFormat('d MMM', 'es').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
          child: Text(_label, style: const TextStyle(fontSize: 11, color: _kDateChipText)),
        ),
      ),
    );
  }
}

class _MentionSuggestions extends StatelessWidget {
  final List<MentionCandidate> results;
  final ValueChanged<MentionCandidate> onPick;
  const _MentionSuggestions({required this.results, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: const Text('No hay tareas que coincidan', style: TextStyle(fontSize: 12, color: _kTextGray)),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final c = results[i];
          return ListTile(
            dense: true,
            leading: Icon(
              c.type == 'gc-coursework' ? Icons.school_outlined : Icons.assignment_outlined,
              color: _kAccent,
              size: 20,
            ),
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              c.dueDate != null
                  ? '${c.courseName} · vence ${DateFormat('d MMM', 'es').format(c.dueDate!)}'
                  : c.courseName,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => onPick(c),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ThreadMessage message;
  final bool isMine;
  // true si el OTRO participante ya leyó este mensaje (su lastReadAt es
  // posterior al sentAt de este mensaje) — solo se calcula para mensajes
  // propios ya confirmados, ver ThreadPage.build().
  final bool isRead;
  final void Function(String type, String refId) onOpenMention;
  // No nulo solo si este mensaje falló al enviarse — tocar la burbuja
  // reintenta.
  final VoidCallback? onRetry;
  const _Bubble({
    required this.message,
    required this.isMine,
    this.isRead = false,
    required this.onOpenMention,
    this.onRetry,
  });

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // Reloj (enviando) → un check (el servidor ya lo guardó) → doble check
  // (el otro participante ya lo leyó). No hay un estado real de
  // "entregado pero no leído" — no hay infraestructura de esa señal
  // (WebSocket/ack), así que un check cubre "mandado" y dos checks es la
  // única confirmación real que se tiene: que lo leyó.
  Widget _statusIcon() {
    final color = _kOffWhite.withValues(alpha: 0.7);
    if (message.isFailed) {
      return const Icon(Icons.error_outline, size: 13, color: Color(0xFFFFD1CC));
    }
    if (message.isPending) {
      return Icon(Icons.access_time_rounded, size: 12, color: color);
    }
    return Icon(isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final mentions = _mentionRe.allMatches(message.body).toList();
    final bubble = mentions.isNotEmpty
        ? _buildTaskCard(context, mentions)
        : _buildPlainBubble(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: onRetry != null ? GestureDetector(onTap: onRetry, child: bubble) : bubble,
    );
  }

  Widget _buildPlainBubble(BuildContext context) {
    final baseColor = isMine ? _kOffWhite : _kTextGray;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 4),
      decoration: BoxDecoration(
        color: isMine
            ? (message.isFailed ? _kBubbleMine.withValues(alpha: 0.6) : _kBubbleMine)
            : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(message.body, style: TextStyle(color: baseColor, fontSize: 12, height: 1.3)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.isFailed ? 'No enviado · toca para reintentar' : _time(message.sentAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? _kOffWhite.withValues(alpha: 0.7) : _kTextGray,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                _statusIcon(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Mensaje que menciona una tarea ("@[Título](tipo:id)"): en vez de la
  // burbuja de color de siempre, se muestra como una tarjeta blanca — texto
  // libre arriba, y una fila tocable por mención abajo que lleva directo a
  // la tarea (Classroom o institucional), separada por una línea divisoria.
  // Ver diseño Figma "thread_page - Chat Padre".
  Widget _buildTaskCard(BuildContext context, List<RegExpMatch> mentions) {
    final plainText = message.body.replaceAll(_mentionRe, '').trim();
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El mensaje y el título de la tarea van juntos, como si el
                // título fuera la continuación del párrafo — la hora viene
                // recién después de los dos, no entre ellos.
                if (plainText.isNotEmpty) ...[
                  Text(plainText, style: const TextStyle(color: _kTextGray, fontSize: 12, height: 1.3)),
                  const SizedBox(height: 9),
                ],
                for (final m in mentions) ...[
                  _TaskTitleRow(title: m.group(1)!),
                  const SizedBox(height: 9),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_time(message.sentAt),
                      style: const TextStyle(fontSize: 10, color: _kTextGray)),
                ),
              ],
            ),
          ),
          for (final m in mentions)
            _MentionLink(
              type: m.group(2)!,
              refId: m.group(3)!,
              onOpen: onOpenMention,
            ),
        ],
      ),
    );
  }
}

// Ícono + título de la tarea mencionada — va pegado al mensaje, como si
// fuera la continuación del párrafo (la hora viene después de esto, no
// entre el mensaje y esta fila).
class _TaskTitleRow extends StatelessWidget {
  final String title;
  const _TaskTitleRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.string(_kSvgClipboardList, width: 8, height: 11),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: _kClipboardBlue)),
        ),
      ],
    );
  }
}

// Fila tocable "Ver en classroom"/"Ver tarea" que navega a donde
// corresponda según el tipo de mención — va debajo del separador, después
// de la hora.
class _MentionLink extends StatelessWidget {
  final String type;
  final String refId;
  final void Function(String type, String refId) onOpen;
  const _MentionLink({
    required this.type,
    required this.refId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isClassroom = type == 'gc-coursework';
    return GestureDetector(
      onTap: () => onOpen(type, refId),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const SizedBox(height: 5),
          // El separador va pegado arriba de "Ver en classroom", no de todo
          // el bloque de mención — y llega de borde a borde de la tarjeta.
          const Divider(height: 1, thickness: 1, color: _kCardDivider),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isClassroom) ...[
                    Image.asset('assets/icons/google_classroom_icon.png', width: 15, height: 15),
                    const SizedBox(width: 6),
                  ] else ...[
                    SvgPicture.string(_kSvgClipboardList, width: 8, height: 11),
                    const SizedBox(width: 6),
                  ],
                  Text(isClassroom ? 'Ver en classroom' : 'Ver tarea',
                      style:
                          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent)),
                  const SizedBox(width: 6),
                  const Text('›',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: _kBg,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 35),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 12, color: _kTextDark),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          hintText: 'Usa: "@" para adjuntar lo que quieras',
                          hintStyle: TextStyle(fontSize: 12, color: _kComposerHint, fontWeight: FontWeight.w300),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    // Adjuntar fotos/cámara: oculto por ahora (el backend
                    // solo manda texto todavía) — antes eran íconos que
                    // mostraban "Aún no disponible" al tocarlos.
                  ],
                ),
              ),
            ),
            const SizedBox(width: 3),
            // Sin estado de "enviando" que tape el botón: el mensaje se
            // manda de forma optimista (aparece al instante en la
            // conversación con su propio relojito) — no hay nada que
            // esperar acá.
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 36,
                height: 35,
                decoration: BoxDecoration(
                  color: _kAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg),
                ),
                alignment: Alignment.center,
                child: SvgPicture.string(_kSvgPaperPlane, width: 16, height: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
