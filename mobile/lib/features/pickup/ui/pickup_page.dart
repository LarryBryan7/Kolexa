// ============================================================
// pickup_page.dart — Pantalla de Recojo / Autorizados
// ============================================================
// Padre: gestiona personas autorizadas para recoger al hijo.
// Muestra historial de eventos de recojo.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pickup_bloc.dart';

class PickupPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const PickupPage({super.key, required this.studentId, required this.studentName});

  @override
  State<PickupPage> createState() => _PickupPageState();
}

class _PickupPageState extends State<PickupPage> {
  @override
  void initState() {
    super.initState();
    context.read<PickupBloc>().add(LoadAuthorizedEvent(widget.studentId));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Recojo · ${widget.studentName}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Autorizados'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('Agregar'),
          onPressed: () => _showAddPersonSheet(context),
        ),
        body: TabBarView(
          children: [
            _AuthorizedTab(studentId: widget.studentId),
            _HistoryTab(studentId: widget.studentId),
          ],
        ),
      ),
    );
  }

  void _showAddPersonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<PickupBloc>(),
        child: _AddPersonSheet(studentId: widget.studentId),
      ),
    );
  }
}

// ── Tab: personas autorizadas ─────────────────────────────────
class _AuthorizedTab extends StatelessWidget {
  final int studentId;
  const _AuthorizedTab({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PickupBloc, PickupState>(
      builder: (context, state) {
        if (state is PickupLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is PickupError) {
          return Center(child: Text(state.message));
        }
        if (state is AuthorizedListLoaded) {
          if (state.persons.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aún no hay personas autorizadas',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.persons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final person = state.persons[i];
              return _AuthorizedPersonCard(person: person, studentId: studentId);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _AuthorizedPersonCard extends StatelessWidget {
  final AuthorizedPersonModel person;
  final int studentId;
  const _AuthorizedPersonCard({required this.person, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
          child: Text(
            person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(person.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.relationship,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            if (person.documentId != null)
              Text('DNI: ${person.documentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: person.documentId != null,
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('¿Quitar autorización?'),
                content: Text('${person.fullName} ya no podrá recoger al alumno.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<PickupBloc>().add(
                            RemoveAuthorizedPersonEvent(
                              pickupId: person.id,
                              studentId: studentId,
                            ),
                          );
                    },
                    child: const Text('Quitar', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Tab: historial de eventos de recojo ───────────────────────
class _HistoryTab extends StatelessWidget {
  final int studentId;
  const _HistoryTab({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PickupBloc, PickupState>(
      builder: (context, state) {
        if (state is PickupHistoryLoaded) {
          if (state.events.isEmpty) {
            return const Center(
              child: Text('Sin eventos registrados', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final event = state.events[i];
              return ListTile(
                leading: const Icon(Icons.directions_walk, color: Color(0xFF10B981)),
                title: Text(event.pickedUpByName),
                subtitle: Text(
                  _formatDateTime(event.pickedUpAt),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: event.notes != null
                    ? Text(event.notes!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
              );
            },
          );
        }
        return const Center(
          child: Text('Cargando historial...', style: TextStyle(color: Colors.grey)),
        );
      },
    );
  }

  String _formatDateTime(DateTime d) {
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }
}

// ── Sheet: agregar persona autorizada ─────────────────────────
class _AddPersonSheet extends StatefulWidget {
  final int studentId;
  const _AddPersonSheet({required this.studentId});

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _nameCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relationship = 'Familiar';

  final List<String> _relationships = [
    'Familiar', 'Abuelo/a', 'Tío/a', 'Hermano/a', 'Otro'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dniCtrl.dispose();
    _phoneCtrl.dispose();
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
          const Text('Agregar persona autorizada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre completo *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _dniCtrl,
            decoration: const InputDecoration(
              labelText: 'DNI',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _relationship,
            decoration: const InputDecoration(
              labelText: 'Parentesco',
              border: OutlineInputBorder(),
            ),
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _relationship = v!),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                context.read<PickupBloc>().add(
                      AddAuthorizedPersonEvent(
                        studentId: widget.studentId,
                        fullName: _nameCtrl.text.trim(),
                        relationship: _relationship,
                        documentId: _dniCtrl.text.trim().isEmpty
                            ? null
                            : _dniCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim().isEmpty
                            ? null
                            : _phoneCtrl.text.trim(),
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
