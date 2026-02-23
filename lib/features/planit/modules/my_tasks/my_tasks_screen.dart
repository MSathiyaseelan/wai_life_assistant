import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class MyTasksScreen extends StatefulWidget {
  final String walletId;
  const MyTasksScreen({super.key, required this.walletId});
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<TaskModel> _tasks = List.from(mockTasks);
  String? _filterProject;

  List<TaskModel> get _filtered {
    var list = _tasks.where((t) => t.walletId == widget.walletId).toList();
    if (_filterProject != null)
      list = list.where((t) => t.project == _filterProject).toList();
    return list;
  }

  List<String> get _projects => _tasks
      .where((t) => t.project != null)
      .map((t) => t.project!)
      .toSet()
      .toList();

  List<TaskModel> _byStatus(TaskStatus s) =>
      _filtered.where((t) => t.status == s).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _delete(TaskModel t) => setState(() => _tasks.remove(t));
  void _updateStatus(TaskModel t, TaskStatus s) => setState(() => t.status = s);
  void _toggleSubtask(SubTask st) => setState(() => st.done = !st.done);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'My Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: AppColors.split,
          labelColor: AppColors.split,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'To Do (${_byStatus(TaskStatus.todo).length})'),
            Tab(text: 'Doing (${_byStatus(TaskStatus.inProgress).length})'),
            Tab(text: 'Done (${_byStatus(TaskStatus.done).length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.split,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Task',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Project filter
          if (_projects.isNotEmpty)
            _ProjectFilter(
              projects: _projects,
              selected: _filterProject,
              subColor: subColor,
              onSelect: (p) => setState(() => _filterProject = p),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TaskList(
                  tasks: _byStatus(TaskStatus.todo),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: (t) => _showDetailSheet(context, t, isDark, surfBg),
                ),
                _TaskList(
                  tasks: _byStatus(TaskStatus.inProgress),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: (t) => _showDetailSheet(context, t, isDark, surfBg),
                ),
                _TaskList(
                  tasks: _byStatus(TaskStatus.done),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddTaskSheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (t) {
          setState(() => _tasks.add(t));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    TaskModel t,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      context,
      child: _TaskDetailSheet(
        task: t,
        isDark: isDark,
        surfBg: surfBg,
        onStatusChange: (s) {
          _updateStatus(t, s);
          Navigator.pop(context);
        },
        onToggleSubtask: _toggleSubtask,
        onDelete: () {
          _delete(t);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Project filter ─────────────────────────────────────────────────────────────

class _ProjectFilter extends StatelessWidget {
  final List<String> projects;
  final String? selected;
  final Color subColor;
  final void Function(String?) onSelect;
  const _ProjectFilter({
    required this.projects,
    required this.selected,
    required this.subColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _FilterPill(
            label: 'All',
            selected: selected == null,
            color: AppColors.split,
            onTap: () => onSelect(null),
          ),
          ...projects.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterPill(
                label: p,
                selected: selected == p,
                color: AppColors.split,
                onTap: () => onSelect(selected == p ? null : p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.surfDark : const Color(0xFFE0E0EC)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: selected
                ? color
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

// ── Task list ──────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final bool isDark;
  final void Function(TaskModel) onDelete;
  final void Function(TaskModel, TaskStatus) onStatusChange;
  final void Function(SubTask) onToggleSubtask;
  final void Function(TaskModel)? onTap;
  const _TaskList({
    required this.tasks,
    required this.isDark,
    required this.onDelete,
    required this.onStatusChange,
    required this.onToggleSubtask,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const PlanEmptyState(
        emoji: '✅',
        title: 'Nothing here',
        subtitle: 'This list is empty',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: tasks.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SwipeTile(
          onDelete: () => onDelete(tasks[i]),
          child: _TaskCard(
            task: tasks[i],
            isDark: isDark,
            onStatusChange: (s) => onStatusChange(tasks[i], s),
            onToggleSubtask: onToggleSubtask,
            onTap: onTap != null ? () => onTap!(tasks[i]) : null,
          ),
        ),
      ),
    );
  }
}

// ── Task card ──────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final void Function(TaskStatus) onStatusChange;
  final void Function(SubTask) onToggleSubtask;
  final VoidCallback? onTap;
  const _TaskCard({
    required this.task,
    required this.isDark,
    required this.onStatusChange,
    required this.onToggleSubtask,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final st = task.status;
    final doneCount = task.subtasks.where((s) => s.done).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: st.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final next = st == TaskStatus.todo
                        ? TaskStatus.inProgress
                        : st == TaskStatus.inProgress
                        ? TaskStatus.done
                        : TaskStatus.todo;
                    onStatusChange(next);
                  },
                  child: Icon(st.icon, color: st.color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                      decoration: st == TaskStatus.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Text(task.emoji, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),

            // Tags/project/due
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (task.project != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.split.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📁 ${task.project}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: AppColors.split,
                      ),
                    ),
                  ),
                PriorityBadge(priority: task.priority),
                if (task.dueDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: daysUntilColor(task.dueDate!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysUntil(task.dueDate!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: daysUntilColor(task.dueDate!),
                      ),
                    ),
                  ),
                MemberAvatar(memberId: task.assignedTo, size: 22),
              ],
            ),

            // Subtask progress bar
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.subtasks.isEmpty
                            ? 0
                            : doneCount / task.subtasks.length,
                        backgroundColor: AppColors.income.withOpacity(0.12),
                        color: AppColors.income,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$doneCount/${task.subtasks.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: sub,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Task detail sheet ──────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final Color surfBg;
  final void Function(TaskStatus) onStatusChange;
  final void Function(SubTask) onToggleSubtask;
  final VoidCallback onDelete;
  const _TaskDetailSheet({
    required this.task,
    required this.isDark,
    required this.surfBg,
    required this.onStatusChange,
    required this.onToggleSubtask,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(task.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
              ),
              PriorityBadge(priority: task.priority),
            ],
          ),
          const SizedBox(height: 10),
          if (task.description != null)
            Text(
              task.description!,
              style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (task.project != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.split.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📁 ${task.project}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: AppColors.split,
                    ),
                  ),
                ),
              if (task.dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: daysUntilColor(task.dueDate!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fmtDate(task.dueDate!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: daysUntilColor(task.dueDate!),
                    ),
                  ),
                ),
            ],
          ),

          // Subtasks
          if (task.subtasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Subtasks',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 8),
            ...task.subtasks.map(
              (st) => GestureDetector(
                onTap: () => onToggleSubtask(st),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        st.done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: st.done ? AppColors.income : sub,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        st.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: st.done ? sub : tc,
                          decoration: st.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          // Status change buttons
          Row(
            children: [
              ...TaskStatus.values
                  .where((s) => s != task.status)
                  .map(
                    (s) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: s.index > 0 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => onStatusChange(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: s.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: s.color.withOpacity(0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '→ ${s.label}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: s.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add task sheet ─────────────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(TaskModel) onSave;
  const _AddTaskSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _projCtrl = TextEditingController();
  String _emoji = '✅';
  Priority _priority = Priority.medium;
  String _assignedTo = 'me';
  DateTime? _dueDate;
  final List<String> _subtasks = [];
  final _stCtrl = TextEditingController();

  final _emojis = [
    '✅',
    '📊',
    '🎯',
    '🔧',
    '🎒',
    '🚀',
    '💡',
    '📝',
    '🏃',
    '🎨',
    '💼',
    '🏠',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _projCtrl.dispose();
    _stCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'New Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          // Emoji
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _emoji == e
                              ? AppColors.split.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e
                                ? AppColors.split
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          PlanInputField(controller: _titleCtrl, hint: 'Task title *'),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _descCtrl,
            hint: 'Description (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          PlanInputField(controller: _projCtrl, hint: 'Project (optional)'),
          const SizedBox(height: 16),

          // Priority
          const SheetLabel(text: 'PRIORITY'),
          Row(
            children: Priority.values
                .map(
                  (p) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: p.index > 0 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _priority == p
                                ? p.color
                                : p.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _priority == p
                                  ? p.color
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _priority == p ? Colors.white : p.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          // Due date + Assign
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _dueDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: AppColors.split,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _dueDate != null
                              ? fmtDateShort(_dueDate!)
                              : 'Due date',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.split,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Assign to
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: mockMembers
                            .take(5)
                            .map(
                              (m) => GestureDetector(
                                onTap: () => setState(() => _assignedTo = m.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _assignedTo == m.id
                                        ? AppColors.primary.withOpacity(0.15)
                                        : widget.surfBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _assignedTo == m.id
                                          ? AppColors.primary
                                          : Colors.transparent,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    m.emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subtasks
          const SheetLabel(text: 'SUBTASKS'),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.surfBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _stCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark
                          ? AppColors.textDark
                          : AppColors.textLight,
                      fontFamily: 'Nunito',
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Add subtask…',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: sub,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      setState(() {
                        _subtasks.add(v.trim());
                        _stCtrl.clear();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_stCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _subtasks.add(_stCtrl.text.trim());
                    _stCtrl.clear();
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.split,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (_subtasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._subtasks.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: AppColors.split,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _subtasks.remove(s)),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.subDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          SaveButton(
            label: 'Save Task',
            color: AppColors.split,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              widget.onSave(
                TaskModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  description: _descCtrl.text.trim().isEmpty
                      ? null
                      : _descCtrl.text.trim(),
                  emoji: _emoji,
                  status: TaskStatus.todo,
                  priority: _priority,
                  assignedTo: _assignedTo,
                  walletId: widget.walletId,
                  project: _projCtrl.text.trim().isEmpty
                      ? null
                      : _projCtrl.text.trim(),
                  dueDate: _dueDate,
                  subtasks: _subtasks
                      .map(
                        (s) => SubTask(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: s,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
