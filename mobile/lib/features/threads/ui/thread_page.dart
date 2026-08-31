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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

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
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _kPrimaryLt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '📋 ${m.group(1)}',
            style: (style ?? const TextStyle()).copyWith(
              color: _kPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
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

class ThreadPage extends StatefulWidget {
  final String threadId;
  final String title;
  final String? studentId;
  final String? studentName;

  const ThreadPage({
    super.key,
    required this.threadId,
    required this.title,
    this.studentId,
    this.studentName,
  });

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> with WidgetsBindingObserver {
  // Cache en memoria por hilo: sobrevive a que la pantalla se destruya y
  // se recree (ej. salir y volver a entrar a la misma conversación), así
  // que reabrirla muestra los mensajes al instante mientras se refrescan
  // solos en segundo plano.
  static final Map<String, List<ThreadMessage>> _cache = {};

  late final ThreadsRepository _repo;
  late final int _myUserId;
  late final List<String> _myRoles;
  final _controller = _MentionComposerController();
  final _scroll = ScrollController();
  List<ThreadMessage>? _messages;
  bool _loadingFirstTime = false;
  bool _sending = false;
  String? _error;

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
    _messages = _cache[widget.threadId];
    _load();
    // Se marca leído al entrar: si el otro responde mientras se lee, el
    // siguiente refresh de la bandeja ya no lo mostrará como pendiente.
    _repo.markRead(widget.threadId).catchError((_) {});
    WidgetsBinding.instance.addObserver(this);
    PushNotificationsService.instance.addDataRefreshListener(_handleDataRefresh);
  }

  // Push de un mensaje nuevo en ESTA conversación → se refresca sola. Se
  // filtra por threadId para no recargar cuando llega un mensaje de otra
  // conversación distinta que el usuario no tiene abierta.
  void _handleDataRefresh(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['screen'] == 'thread' && data['threadId'] == widget.threadId) {
      _load();
    }
  }

  // Red de seguridad si el push no llegó (conocido en gama baja/media):
  // al volver del background, se refresca igual.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
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
      final msgs = await _repo.getMessages(widget.threadId);
      _cache[widget.threadId] = msgs;
      if (!mounted) return;
      setState(() {
        _messages = msgs;
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
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(widget.threadId, body);
      _controller.clear();
      _load(forceScroll: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _kTextDark),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700, color: _kTextDark)),
                        if (widget.studentName != null)
                          Text('Sobre ${widget.studentName}',
                              style: const TextStyle(fontSize: 12, color: _kPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                if (_messages == null) {
                  if (_loadingFirstTime) {
                    return const Center(child: CircularProgressIndicator(color: _kPrimary));
                  }
                  if (_error != null) {
                    return Center(
                      child: TextButton(onPressed: _load, child: const Text('Reintentar')),
                    );
                  }
                }
                final messages = _messages ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Escribe el primer mensaje',
                        style: TextStyle(color: _kTextGray)),
                  );
                }
                return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      // `messages` sigue en orden cronológico (viejo→nuevo);
                      // con `reverse: true` el índice 0 de la lista es el
                      // que se pinta abajo del todo, así que hay que
                      // invertir el mapeo acá.
                      final message = messages[messages.length - 1 - i];
                      return _Bubble(
                        message: message,
                        isMine: message.senderId == _myUserId.toString(),
                        onOpenMention: _openMention,
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
            _Composer(controller: _controller, sending: _sending, onSend: _send),
          ],
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
              color: _kPrimary,
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
  final void Function(String type, String refId) onOpenMention;
  const _Bubble({required this.message, required this.isMine, required this.onOpenMention});

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // Convierte "...@[Título](homework:123)..." (o "gc-coursework:") en
  // spans: texto normal + un span tocable por cada mención, subrayado y
  // con ícono de tarea.
  List<InlineSpan> _buildSpans(BuildContext context) {
    final body = message.body;
    final baseColor = isMine ? Colors.white : _kTextDark;
    final mentionColor = isMine ? Colors.white : _kPrimary;
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in _mentionRe.allMatches(body)) {
      if (m.start > last) {
        spans.add(TextSpan(text: body.substring(last, m.start)));
      }
      final title = m.group(1)!;
      final type = m.group(2)!;
      final refId = m.group(3)!;
      spans.add(TextSpan(
        text: '📋 $title',
        style: TextStyle(
          color: mentionColor,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: mentionColor,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onOpenMention(type, refId),
      ));
      last = m.end;
    }
    if (last < body.length) spans.add(TextSpan(text: body.substring(last)));
    return [TextSpan(style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.3), children: spans)];
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _kPrimary : Colors.white,
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
            Text.rich(TextSpan(children: _buildSpans(context))),
            const SizedBox(height: 4),
            Text(_time(message.sentAt),
                style: TextStyle(
                    fontSize: 10,
                    color: isMine ? Colors.white.withValues(alpha: 0.7) : _kTextGray)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje… usa @ para mencionar una tarea',
                  filled: true,
                  fillColor: _kPrimaryLt.withValues(alpha: 0.4),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded, color: _kPrimary),
                  ),
          ],
        ),
      ),
    );
  }
}
