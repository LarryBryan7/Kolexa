// ============================================================
// appointments_page.dart — Pantalla de Citas con el Docente
// ============================================================
// Padre: ve slots disponibles y reserva.
// Docente: crea slots de disponibilidad.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/appointments_bloc.dart';

class AppointmentsPage extends StatefulWidget {
  final String role; // 'parent' | 'teacher'
  const AppointmentsPage({super.key, required this.role});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Cargar tab inicial (0 = Disponibles)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTab(0));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _loadTab(_tabController.index);
  }

  void _loadTab(int index) {
    final bloc = context.read<AppointmentsBloc>();
    if (index == 0) {
      bloc.add(const LoadAvailableSlotsEvent());
    } else {
      bloc.add(LoadMyAppointmentsEvent(role: widget.role));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Disponibles'),
            Tab(text: 'Mis Citas'),
          ],
        ),
      ),
      // FAB solo para docentes: crear slot
      floatingActionButton: widget.role == 'teacher'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo horario'),
              onPressed: () => _showCreateSlotSheet(context),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _SlotsTab(role: widget.role),
          _MyAppointmentsTab(),
        ],
      ),
    );
  }

  void _showCreateSlotSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<AppointmentsBloc>(),
        child: const _CreateSlotSheet(),
      ),
    );
  }
}

// ── Tab: slots disponibles para reservar ─────────────────────
class _SlotsTab extends StatelessWidget {
  final String role;
  const _SlotsTab({required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppointmentsBloc, AppointmentsState>(
      builder: (context, state) {
        if (state is AppointmentsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AppointmentsError) {
          return Center(child: Text(state.message));
        }
        if (state is SlotsLoaded) {
          if (state.slots.isEmpty) {
            return const Center(
              child: Text('No hay horarios disponibles', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final slot = state.slots[i];
              return _SlotCard(slot: slot, role: role);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// Diálogo para ingresar motivo de la cita antes de reservar
void _showBookDialog(BuildContext context, int slotId) {
  final reasonCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Motivo de la cita'),
      content: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(hintText: 'Escribe el motivo...'),
        minLines: 2,
        maxLines: 4,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (reasonCtrl.text.trim().isEmpty) return;
            context.read<AppointmentsBloc>().add(
                  BookAppointmentEvent(
                    slotId: slotId,
                    studentId: 0, // el backend lo obtiene del JWT del padre
                    reason: reasonCtrl.text.trim(),
                  ),
                );
            Navigator.pop(ctx);
          },
          child: const Text('Reservar'),
        ),
      ],
    ),
  );
}

class _SlotCard extends StatelessWidget {
  final AppointmentSlotModel slot;
  final String role;
  const _SlotCard({required this.slot, required this.role});

  @override
  Widget build(BuildContext context) {
    final isFull = slot.isFull;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Ícono de calendario
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFull
                    ? Colors.grey.shade100
                    : const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_today,
                color: isFull ? Colors.grey : const Color(0xFF6366F1),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.teacherName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slot.formattedDate} · ${slot.formattedTime}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slot.bookingCount}/${slot.maxBookings} reservas',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFull ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            // Botón reservar (solo padres, slot no lleno)
            if (role == 'parent' && !isFull)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF6366F1),
                ),
                onPressed: () => _showBookDialog(context, slot.id),
                child: const Text('Reservar'),
              )
            else if (isFull)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Lleno', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: mis citas (próximas y pasadas) ──────────────────────
class _MyAppointmentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppointmentsBloc, AppointmentsState>(
      builder: (context, state) {
        if (state is AppointmentsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is MyAppointmentsLoaded) {
          final upcoming = state.upcoming;
          final past = state.past;

          if (upcoming.isEmpty && past.isEmpty) {
            return const Center(
              child: Text('No tienes citas agendadas', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const Text('PRÓXIMAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                ...upcoming.map((a) => _AppointmentTile(appointment: a, isPast: false)),
                const SizedBox(height: 16),
              ],
              if (past.isNotEmpty) ...[
                const Text('PASADAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                ...past.map((a) => _AppointmentTile(appointment: a, isPast: true)),
              ],
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isPast;
  const _AppointmentTile({required this.appointment, required this.isPast});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPast ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_note,
            color: isPast ? Colors.grey : const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.teacherName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isPast ? Colors.grey : Colors.black87,
                    )),
                Text(
                  '${appointment.formattedDate} · ${appointment.formattedTime}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet: crear slot de disponibilidad (docente) ────────────
class _CreateSlotSheet extends StatefulWidget {
  const _CreateSlotSheet();

  @override
  State<_CreateSlotSheet> createState() => _CreateSlotSheetState();
}

class _CreateSlotSheetState extends State<_CreateSlotSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _maxBookings = 1;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crear horario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Selector de fecha
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedDate != null ? _formatDate(_selectedDate!) : 'Seleccionar fecha',
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (d != null) setState(() => _selectedDate = d);
              },
            ),

            // Hora inicio
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(_startTime != null ? _formatTime(_startTime!) : 'Hora inicio'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                );
                if (t != null) setState(() => _startTime = t);
              },
            ),

            // Hora fin
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_filled),
              title: Text(_endTime != null ? _formatTime(_endTime!) : 'Hora fin'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 30),
                );
                if (t != null) setState(() => _endTime = t);
              },
            ),

            // Máx. reservas
            Row(
              children: [
                const Text('Máx. reservas:'),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _maxBookings,
                  items: [1, 2, 3, 4, 5]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setState(() => _maxBookings = v!),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_selectedDate == null || _startTime == null || _endTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completa todos los campos')),
                    );
                    return;
                  }
                  final startDt = DateTime(
                    _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
                    _startTime!.hour, _startTime!.minute,
                  );
                  final endDt = DateTime(
                    _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
                    _endTime!.hour, _endTime!.minute,
                  );
                  context.read<AppointmentsBloc>().add(
                        CreateSlotEvent(
                          startTime: startDt,
                          endTime: endDt,
                          maxBookings: _maxBookings,
                        ),
                      );
                  Navigator.pop(context);
                },
                child: const Text('Crear horario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
