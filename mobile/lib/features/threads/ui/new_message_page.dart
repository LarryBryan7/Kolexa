// ============================================================
// new_message_page.dart — Elegir a quién escribir
// ============================================================
// Solo lista contactos que /threads/contacts ya validó como permitidos (el
// backend aplica la misma regla al confirmar: comparten un alumno, o el
// destinatario es el director). Nunca se pide un id a mano.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../data/threads_repository.dart';
import 'thread_page.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class NewMessagePage extends StatefulWidget {
  const NewMessagePage({super.key});

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  late final ThreadsRepository _repo;
  late Future<List<Contact>> _future;

  @override
  void initState() {
    super.initState();
    _repo = ThreadsRepository(context.read<ApiClient>());
    _future = _repo.getContacts();
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('¿Sobre cuál de tus hijos?',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _kTextDark)),
              ),
              ...c.students.map((s) => ListTile(
                    title: Text(s.name),
                    onTap: () => Navigator.pop(context, s),
                  )),
            ],
          ),
        ),
      );
      if (student == null) return; // canceló el selector
    }

    if (!mounted) return;
    final threadId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ComposeFirstMessagePage(contact: c, student: student),
      ),
    );
    if (threadId != null && mounted) {
      Navigator.of(context).pop(true); // avisa a InboxPage que refresque
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadPage(
            threadId: threadId,
            title: c.name,
            studentId: student?.id,
            studentName: student?.name,
          ),
        ),
      );
    }
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
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
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
                  const Text('Nuevo mensaje',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kTextDark)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Contact>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _kPrimary));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString().replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: _kTextGray),
                      ),
                    );
                  }
                  final contacts = snapshot.data ?? [];
                  if (contacts.isEmpty) {
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
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = contacts[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _kPrimaryLt,
                          backgroundImage: c.avatar != null ? NetworkImage(c.avatar!) : null,
                          child: c.avatar == null
                              ? const Icon(Icons.person, color: _kPrimary, size: 20)
                              : null,
                        ),
                        title: Text(c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: _kTextDark)),
                        subtitle: Text(
                          c.role == 'teacher'
                              ? 'Docente${c.students.isNotEmpty ? ' · ${c.students.map((s) => s.name).join(', ')}' : ''}'
                              : c.role == 'parent'
                                  ? 'Padre de familia${c.students.isNotEmpty ? ' · ${c.students.map((s) => s.name).join(', ')}' : ''}'
                                  : 'Dirección del colegio',
                          style: const TextStyle(fontSize: 12, color: _kTextGray),
                        ),
                        onTap: () => _pick(c),
                      );
                    },
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

class _ComposeFirstMessagePage extends StatefulWidget {
  final Contact contact;
  final ThreadStudentRef? student;
  const _ComposeFirstMessagePage({required this.contact, required this.student});

  @override
  State<_ComposeFirstMessagePage> createState() => _ComposeFirstMessagePageState();
}

class _ComposeFirstMessagePageState extends State<_ComposeFirstMessagePage> {
  late final ThreadsRepository _repo;
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ThreadsRepository(context.read<ApiClient>());
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final threadId = await _repo.openThread(
        recipientId: widget.contact.userId,
        studentId: widget.student?.id,
        firstMessageBody: body,
      );
      if (mounted) Navigator.of(context).pop(threadId);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
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
                        Text(widget.contact.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: _kTextDark)),
                        if (widget.student != null)
                          Text('Sobre ${widget.student!.name}',
                              style: const TextStyle(fontSize: 12, color: _kPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFBA3428), fontSize: 12)),
              ),
            Container(
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
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Escribe tu mensaje…',
                          filled: true,
                          fillColor: _kPrimaryLt.withValues(alpha: 0.4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            onPressed: _send,
                            icon: const Icon(Icons.send_rounded, color: _kPrimary),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
