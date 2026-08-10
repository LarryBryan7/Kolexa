// ============================================================
// suggestions_page.dart — Pantalla de Sugerencias / Buzón
// ============================================================
// Padre: enviar sugerencias (anónimas o no) y ver las suyas.
// Respuestas del colegio visibles en detalle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/suggestions_bloc.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<SuggestionsBloc>().add(const LoadMySuggestionsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buzón de sugerencias')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_note),
        label: const Text('Nueva sugerencia'),
        onPressed: () => _showSubmitSheet(context),
      ),
      body: BlocConsumer<SuggestionsBloc, SuggestionsState>(
        listener: (context, state) {
          if (state is SuggestionSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Sugerencia enviada! Gracias por tu opinión.')),
            );
            // Recarga la lista después de enviar
            context.read<SuggestionsBloc>().add(const LoadMySuggestionsEvent());
          }
        },
        builder: (context, state) {
          if (state is SuggestionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SuggestionsError) {
            return Center(child: Text(state.message));
          }
          if (state is SuggestionsLoaded) {
            if (state.suggestions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aún no has enviado sugerencias',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Toca + para enviar tu primera sugerencia',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: state.suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                return _SuggestionCard(suggestion: state.suggestions[i]);
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showSubmitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<SuggestionsBloc>(),
        child: const _SubmitSuggestionSheet(),
      ),
    );
  }
}

// ── Tarjeta de sugerencia ─────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  final SuggestionModel suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(suggestion.statusColor);
    final hasResponses = suggestion.responses.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasResponses
            ? () => _showDetail(context)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Badge de categoría
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(suggestion.category,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  // Indicador anónimo
                  if (suggestion.isAnonymous)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Anónimo',
                          style: TextStyle(fontSize: 10, color: Colors.purple)),
                    ),
                  const Spacer(),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      suggestion.statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(suggestion.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                suggestion.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _formatDate(suggestion.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  // Indicador de respuesta
                  if (hasResponses) ...[
                    const Icon(Icons.reply, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Ver respuesta',
                        style: TextStyle(fontSize: 11, color: Colors.green)),
                    const Icon(Icons.chevron_right, size: 14, color: Colors.green),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SuggestionDetailSheet(suggestion: suggestion),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Sheet: detalle / respuestas ───────────────────────────────
class _SuggestionDetailSheet extends StatelessWidget {
  final SuggestionModel suggestion;
  const _SuggestionDetailSheet({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(suggestion.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(suggestion.description, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          const Text('RESPUESTAS DEL COLEGIO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ...suggestion.responses.map(
            (r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(r.responderName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r.response, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── Sheet: enviar nueva sugerencia ───────────────────────────
class _SubmitSuggestionSheet extends StatefulWidget {
  const _SubmitSuggestionSheet();

  @override
  State<_SubmitSuggestionSheet> createState() => _SubmitSuggestionSheetState();
}

class _SubmitSuggestionSheetState extends State<_SubmitSuggestionSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'general';
  bool _isAnonymous = false;

  final List<String> _categories = [
    'general', 'instalaciones', 'academico', 'docentes', 'servicios', 'otros'
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
          const Text('Nueva sugerencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Categoría
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
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
              hintText: 'Comparte tu idea o comentario...',
            ),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),

          // Anónimo
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enviar de forma anónima', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Tu nombre no aparecerá en la sugerencia',
                style: TextStyle(fontSize: 12)),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
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
                context.read<SuggestionsBloc>().add(
                      SubmitSuggestionEvent(
                        category: _category,
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim(),
                        isAnonymous: _isAnonymous,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Enviar sugerencia'),
            ),
          ),
        ],
      ),
    );
  }
}
