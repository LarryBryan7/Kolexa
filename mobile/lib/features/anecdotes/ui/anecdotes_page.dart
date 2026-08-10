// ============================================================
// anecdotes_page.dart — Pantalla de Anécdotas del alumno
// ============================================================
// Docente: ve todas las anécdotas (incl. privadas) y puede crear.
// Padre: ve solo las públicas registradas sobre su hijo.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/anecdotes_bloc.dart';

class AnecdotesPage extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String role; // 'teacher' | 'parent'

  const AnecdotesPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  @override
  State<AnecdotesPage> createState() => _AnecdotesPageState();
}

class _AnecdotesPageState extends State<AnecdotesPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnecdotesBloc>().add(LoadAnecdotesEvent(widget.studentId, role: widget.role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Anécdotas · ${widget.studentName}')),
      floatingActionButton: widget.role == 'teacher'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Registrar'),
              onPressed: () => _showCreateSheet(context),
            )
          : null,
      body: BlocBuilder<AnecdotesBloc, AnecdotesState>(
        builder: (context, state) {
          if (state is AnecdotesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnecdotesError) {
            return Center(child: Text(state.message));
          }
          if (state is AnecdotesLoaded) {
            if (state.anecdotes.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📝', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('Sin anécdotas registradas',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.anecdotes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final anecdote = state.anecdotes[i];
                return _AnecdoteCard(
                  anecdote: anecdote,
                  canDelete: widget.role == 'teacher',
                  studentId: widget.studentId,
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<AnecdotesBloc>(),
        child: _CreateAnecdoteSheet(studentId: widget.studentId),
      ),
    );
  }
}

// ── Tarjeta de anécdota ───────────────────────────────────────
class _AnecdoteCard extends StatelessWidget {
  final AnecdoteModel anecdote;
  final bool canDelete;
  final int studentId;

  const _AnecdoteCard({
    required this.anecdote,
    required this.canDelete,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivate = anecdote.isPrivate;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPrivate ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji de categoría
                Text(anecdote.categoryIcon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    anecdote.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                // Indicador de privacidad
                if (isPrivate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Privado',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                // Botón eliminar (docentes)
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Eliminar anécdota?'),
                          content: const Text('Esta acción no se puede deshacer.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.read<AnecdotesBloc>().add(
                                      DeleteAnecdoteEvent(
                                          id: anecdote.id, studentId: studentId),
                                    );
                              },
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(anecdote.description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            // Footer: autor y fecha
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  anecdote.authorName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  _formatDate(anecdote.occurredAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Sheet: crear anécdota ─────────────────────────────────────
class _CreateAnecdoteSheet extends StatefulWidget {
  final int studentId;
  const _CreateAnecdoteSheet({required this.studentId});

  @override
  State<_CreateAnecdoteSheet> createState() => _CreateAnecdoteSheetState();
}

class _CreateAnecdoteSheetState extends State<_CreateAnecdoteSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'general';
  bool _isPrivate = false;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': '📝 General'},
    {'value': 'behavior', 'label': '🔴 Conducta'},
    {'value': 'academic', 'label': '📚 Académico'},
    {'value': 'social', 'label': '🤝 Social'},
    {'value': 'health', 'label': '🏥 Salud'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva anécdota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Selector de categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = cat['value'] == _category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _category = cat['value']!),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción *',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),

          // Privado (solo el docente puede ver)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privado', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Solo tú y la dirección pueden ver esto',
                style: TextStyle(fontSize: 12)),
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_titleCtrl.text.trim().isEmpty ||
                    _descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa título y descripción')),
                  );
                  return;
                }
                context.read<AnecdotesBloc>().add(
                      CreateAnecdoteEvent(
                        studentId: widget.studentId,
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim(),
                        category: _category,
                        isPrivate: _isPrivate,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Registrar anécdota'),
            ),
          ),
        ],
      ),
    );
  }
}
