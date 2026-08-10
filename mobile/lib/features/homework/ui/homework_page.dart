// ============================================================
// homework_page.dart — Pantalla de Tareas
// ============================================================
// Dos vistas según el rol del usuario:
//   Profesor  → HomeworkTeacherPage: lista tareas de su aula + botón crear
//   Padre     → HomeworkParentPage: lista tareas pendientes de su hijo
//
// Ambas vistas comparten el mismo BLoC (HomeworkBloc),
// pero escuchan estados distintos.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // para formatear fechas en español
import '../bloc/homework_bloc.dart';
import '../data/models/homework_model.dart';

// ── HomeworkTeacherPage ───────────────────────────────────
// Vista del PROFESOR: lista de tareas creadas para su aula
class HomeworkTeacherPage extends StatefulWidget {
  final int classroomId;

  const HomeworkTeacherPage({super.key, required this.classroomId});

  @override
  State<HomeworkTeacherPage> createState() => _HomeworkTeacherPageState();
}

class _HomeworkTeacherPageState extends State<HomeworkTeacherPage> {
  @override
  void initState() {
    super.initState();
    context.read<HomeworkBloc>().add(LoadClassroomHomeworkEvent(widget.classroomId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeworkBloc, HomeworkState>(
      listener: (context, state) {
        if (state is HomeworkError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tareas asignadas')),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Nueva tarea'),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, HomeworkState state) {
    if (state is HomeworkLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ClassroomHomeworkLoaded) {
      if (state.homeworks.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No hay tareas asignadas todavía',
                  style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text('Toca el botón "+" para crear una',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        // Pull-to-refresh: jalar hacia abajo recarga las tareas
        onRefresh: () async {
          context.read<HomeworkBloc>().add(
                LoadClassroomHomeworkEvent(widget.classroomId, forceRefresh: true),
              );
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.homeworks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final homework = state.homeworks[index];
            return _HomeworkCard(homework: homework);
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Diálogo para crear una nueva tarea
  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ocupa el espacio necesario
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        // Pasamos el BLoC al bottom sheet con BlocProvider.value
        // porque el bottom sheet tiene su propio contexto separado
        return BlocProvider.value(
          value: context.read<HomeworkBloc>(),
          child: _CreateHomeworkSheet(classroomId: widget.classroomId),
        );
      },
    );
  }
}

// ── HomeworkParentPage ────────────────────────────────────
// Vista del PADRE: tareas pendientes y entregadas de su hijo
class HomeworkParentPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const HomeworkParentPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<HomeworkParentPage> createState() => _HomeworkParentPageState();
}

class _HomeworkParentPageState extends State<HomeworkParentPage> {
  @override
  void initState() {
    super.initState();
    context.read<HomeworkBloc>().add(LoadStudentHomeworkEvent(widget.studentId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeworkBloc, HomeworkState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text('Tareas de ${widget.studentName}')),
          body: state is StudentHomeworkLoaded
              ? _buildParentBody(context, state)
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildParentBody(BuildContext context, StudentHomeworkLoaded state) {
    if (state.homeworks.isEmpty) {
      return const Center(
        child: Text('No hay tareas asignadas'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tabs: Pendientes / Entregadas
          const TabBar(
            tabs: [
              Tab(text: 'Pendientes'),
              Tab(text: 'Entregadas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Tareas pendientes
                _HomeworkListView(homeworks: state.pending),
                // Tab 2: Tareas ya entregadas
                _HomeworkListView(homeworks: state.submitted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _HomeworkCard ─────────────────────────────────────────
// Tarjeta de tarea para la vista del profesor
class _HomeworkCard extends StatelessWidget {
  final HomeworkModel homework;

  const _HomeworkCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    // Formato de fecha: "Viernes, 15 mar 2024"
    final dateStr = DateFormat('EEEE, d MMM', 'es').format(homework.dueDate);
    final isOverdue = homework.isOverdue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: materia + fecha
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    homework.courseName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Fecha con color rojo si ya venció
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: isOverdue ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Título
            Text(
              homework.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),

            // Descripción (truncada a 2 líneas)
            Text(
              homework.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Barra de progreso de entregas
            Row(
              children: [
                _ProgressPill(
                  label: '${homework.reviewedCount} revisadas',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                _ProgressPill(
                  label: '${homework.pendingCount} pendientes',
                  color: const Color(0xFFF59E0B),
                ),
                if (homework.lateCount > 0) ...[
                  const SizedBox(width: 8),
                  _ProgressPill(
                    label: '${homework.lateCount} tarde',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Píldora de color para mostrar conteos de estado
class _ProgressPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ProgressPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── _HomeworkListView ─────────────────────────────────────
// Lista de tareas del alumno (vista del padre)
class _HomeworkListView extends StatelessWidget {
  final List<StudentHomeworkModel> homeworks;

  const _HomeworkListView({required this.homeworks});

  @override
  Widget build(BuildContext context) {
    if (homeworks.isEmpty) {
      return const Center(child: Text('No hay tareas en esta sección'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: homeworks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hw = homeworks[index];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          leading: CircleAvatar(
            backgroundColor:
                Color(hw.status.colorValue).withValues(alpha: 0.15),
            child: Icon(
              Icons.assignment_outlined,
              color: Color(hw.status.colorValue),
              size: 20,
            ),
          ),
          title: Text(hw.title,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${hw.courseName} · ${DateFormat('d MMM', 'es').format(hw.dueDate)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(hw.status.colorValue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hw.status.label,
              style: TextStyle(
                fontSize: 11,
                color: Color(hw.status.colorValue),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Si el profesor dejó una nota, mostrarla expandida
          isThreeLine: hw.teacherNote != null,
        );
      },
    );
  }
}

// ── _CreateHomeworkSheet ──────────────────────────────────
// Bottom sheet para crear una nueva tarea (formulario)
class _CreateHomeworkSheet extends StatefulWidget {
  final int classroomId;

  const _CreateHomeworkSheet({required this.classroomId});

  @override
  State<_CreateHomeworkSheet> createState() => _CreateHomeworkSheetState();
}

class _CreateHomeworkSheetState extends State<_CreateHomeworkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _dueDate;
  bool _notifyParents = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = altura del teclado virtual
    // padding se adapta para que el formulario suba con el teclado
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, // solo el espacio necesario
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manejador visual del bottom sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nueva tarea',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título de la tarea'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa un título' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción / instrucciones',
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa una descripción' : null,
            ),
            const SizedBox(height: 12),
            // Selector de fecha de entrega
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 3)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _dueDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate == null
                          ? 'Fecha de entrega'
                          : DateFormat('EEEE, d MMM yyyy', 'es').format(_dueDate!),
                      style: TextStyle(
                        color: _dueDate == null ? Colors.grey : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Notificar a los padres',
                  style: TextStyle(fontSize: 14)),
              value: _notifyParents,
              onChanged: (val) => setState(() => _notifyParents = val),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() != true) return;
                if (_dueDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona la fecha de entrega')),
                  );
                  return;
                }

                // Formatear fecha a "YYYY-MM-DD"
                final dueDateStr =
                    DateFormat('yyyy-MM-dd').format(_dueDate!);

                context.read<HomeworkBloc>().add(
                      CreateHomeworkEvent(
                        classroomId: widget.classroomId,
                        courseId: 1, // TODO: selector de materia
                        title: _titleController.text.trim(),
                        description: _descController.text.trim(),
                        dueDate: dueDateStr,
                        notifyParents: _notifyParents,
                      ),
                    );

                Navigator.of(context).pop(); // cerrar el bottom sheet
              },
              child: const Text('Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
