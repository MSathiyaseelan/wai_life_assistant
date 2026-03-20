import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/supabase/task_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import '../../widgets/plan_widgets.dart';

class MyTasksScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final List<TaskModel> tasks; // kept for PlanItScreen's _pendingTasks count
  const MyTasksScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    required this.tasks,
  });
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<TaskModel> _tasks = [];
  bool _loading = false;
  String? _filterProject;

  List<TaskModel> get _filtered {
    var list = List<TaskModel>.from(_tasks);
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

  bool _wasOnline = true;

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _loadTasks();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadTasks();
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (widget.walletId == 'personal' || widget.walletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await TaskService.instance.fetchTasks(widget.walletId);
      if (!mounted) return;
      final loaded = rows.map(TaskModel.fromRow).toList();
      setState(() {
        _tasks = loaded;
        // Sync back to PlanItScreen's shared list for the pending-task badge
        widget.tasks
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MyTasks] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mutators ──────────────────────────────────────────────────────────────
  Future<void> _add(TaskModel t) async {
    try {
      final row = await TaskService.instance.addTask(t.toRow());
      final saved = TaskModel.fromRow(row);
      if (mounted) setState(() => _tasks.add(saved));
    } catch (e) {
      debugPrint('[MyTasks] add error: $e');
      if (mounted) setState(() => _tasks.add(t));
    }
  }

  Future<void> _delete(TaskModel t) async {
    setState(() => _tasks.remove(t));
    try {
      await TaskService.instance.deleteTask(t.id);
    } catch (_) {}
  }

  Future<void> _update(TaskModel updated) async {
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == updated.id);
      if (i >= 0) _tasks[i] = updated;
    });
    try {
      await TaskService.instance.updateTask(updated.id, updated.toRow());
    } catch (_) {}
  }

  Future<void> _updateStatus(TaskModel t, TaskStatus s) async {
    setState(() => t.status = s);
    try {
      await TaskService.instance.updateTask(t.id, {'status': s.name});
    } catch (_) {}
  }

  Future<void> _toggleSubtask(SubTask st) async {
    setState(() => st.done = !st.done);
    // Find the parent task to persist the updated subtask list
    final parent = _tasks.firstWhere(
      (t) => t.subtasks.any((s) => s.id == st.id),
      orElse: () => _tasks.first,
    );
    try {
      await TaskService.instance.updateTask(parent.id, {
        'subtasks': parent.subtasks.map((s) => s.toMap()).toList(),
      });
    } catch (_) {}
  }

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
        actions: [
          if (widget.walletName != 'Personal')
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.walletEmoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.walletName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
        onPressed: () => _openAddSheet(context, isDark, surfBg),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
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
                  key: ValueKey('todo-${_byStatus(TaskStatus.todo).length}'),
                  tasks: _byStatus(TaskStatus.todo),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: (t) => _openDetailSheet(context, t, isDark, surfBg),
                  onRefresh: _loadTasks,
                ),
                _TaskList(
                  key: ValueKey(
                    'doing-${_byStatus(TaskStatus.inProgress).length}',
                  ),
                  tasks: _byStatus(TaskStatus.inProgress),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: (t) => _openDetailSheet(context, t, isDark, surfBg),
                  onRefresh: _loadTasks,
                ),
                _TaskList(
                  key: ValueKey('done-${_byStatus(TaskStatus.done).length}'),
                  tasks: _byStatus(TaskStatus.done),
                  isDark: isDark,
                  onDelete: _delete,
                  onStatusChange: _updateStatus,
                  onToggleSubtask: _toggleSubtask,
                  onTap: null,
                  onRefresh: _loadTasks,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext ctx, bool isDark, Color surfBg) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TaskSheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        members: widget.members,
        onSave: (t) => _add(t),
      ),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    TaskModel t,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      ctx,
      child: _TaskDetailSheet(
        task: t,
        isDark: isDark,
        surfBg: surfBg,
        onStatusChange: (s) {
          _updateStatus(t, s);
          Navigator.pop(ctx);
        },
        onToggleSubtask: _toggleSubtask,
        onDelete: () {
          _delete(t);
          Navigator.pop(ctx);
        },
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(ctx, t, isDark, surfBg);
        },
      ),
    );
  }

  void _openEditSheet(
    BuildContext ctx,
    TaskModel existing,
    bool isDark,
    Color surfBg,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TaskSheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        members: widget.members,
        existing: existing,
        onSave: (t) => _update(t),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOST WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class _TaskSheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final TaskModel? existing;
  final void Function(TaskModel) onSave;

  const _TaskSheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    final mq = MediaQuery.of(hostCtx);
    // With isScrollControlled:true, Flutter injects viewInsets.bottom into the
    // modal's MediaQuery so this correctly tracks the keyboard height live.
    final kb = mq.viewInsets.bottom;

    return Padding(
      // This padding pushes the whole sheet up above the keyboard
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: _AddTaskSheet(
                isDark: isDark,
                surfBg: surfBg,
                walletId: walletId,
                members: members,
                existing: existing,
                onSave: (t) {
                  Navigator.pop(hostCtx);
                  onSave(t);
                  ScaffoldMessenger.of(hostCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? '${t.emoji} "${t.title}" updated!'
                            : '${t.emoji} "${t.title}" saved!',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.income,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
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

// ─────────────────────────────────────────────────────────────────────────────
// PROJECT FILTER
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// TASK LIST
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final bool isDark;
  final void Function(TaskModel) onDelete;
  final void Function(TaskModel, TaskStatus) onStatusChange;
  final void Function(SubTask) onToggleSubtask;
  final void Function(TaskModel)? onTap;
  final Future<void> Function() onRefresh;
  const _TaskList({
    super.key,
    required this.tasks,
    required this.isDark,
    required this.onDelete,
    required this.onStatusChange,
    required this.onToggleSubtask,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            PlanEmptyState(emoji: '✅', title: 'Nothing here', subtitle: 'This list is empty'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK CARD
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// TASK DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatefulWidget {
  final TaskModel task;
  final bool isDark;
  final Color surfBg;
  final void Function(TaskStatus) onStatusChange;
  final void Function(SubTask) onToggleSubtask;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskDetailSheet({
    required this.task,
    required this.isDark,
    required this.surfBg,
    required this.onStatusChange,
    required this.onToggleSubtask,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  // Local mirror of subtask done-states so tapping rebuilds instantly
  late final List<bool> _done;

  @override
  void initState() {
    super.initState();
    _done = widget.task.subtasks.map((s) => s.done).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final task = widget.task;
    final doneCount = _done.where((d) => d).length;

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
            Row(
              children: [
                Text(
                  'Subtasks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$doneCount/${task.subtasks.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(task.subtasks.length, (i) {
              final st = task.subtasks[i];
              final done = _done[i];
              return GestureDetector(
                onTap: () {
                  setState(() => _done[i] = !done);
                  widget.onToggleSubtask(st); // also mutates the model
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.income.withOpacity(0.07)
                        : (widget.isDark
                              ? AppColors.surfDark
                              : const Color(0xFFEDEEF5)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: done
                          ? AppColors.income.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(done),
                          color: done ? AppColors.income : sub,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          st.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            color: done ? sub : tc,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.subtasks.isEmpty
                    ? 0
                    : doneCount / task.subtasks.length,
                backgroundColor: AppColors.income.withOpacity(0.12),
                color: AppColors.income,
                minHeight: 5,
              ),
            ),
          ],

          const SizedBox(height: 20),
          // Edit button
          GestureDetector(
            onTap: widget.onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.split, Color(0xFF7C6DFF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Edit Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...TaskStatus.values
                  .where((s) => s != task.status)
                  .map(
                    (s) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: s.index > 0 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => widget.onStatusChange(s),
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
                onTap: widget.onDelete,
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

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT TASK SHEET  — AI Parse tab + Manual tab
// ─────────────────────────────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final TaskModel? existing;
  final void Function(TaskModel) onSave;

  const _AddTaskSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.existing,
    required this.onSave,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedTask? _aiPreview;
  String? _aiError;
  bool _usingClaudeAI = false;

  // Shared form state
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _projCtrl = TextEditingController();
  String _emoji = '✅';
  Priority _priority = Priority.medium;
  String _assignedTo = 'me';
  DateTime? _dueDate;
  final List<String> _subtasks = [];
  final _stCtrl = TextEditingController();
  bool _titleError = false;

  static const _emojis = [
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
    '🛒',
    '📞',
    '🏥',
    '📚',
    '✈️',
    '🎉',
    '🔑',
    '💰',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));

    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _projCtrl.text = e.project ?? '';
      _emoji = e.emoji;
      _priority = e.priority;
      _assignedTo = e.assignedTo;
      _dueDate = e.dueDate;
      _subtasks.addAll(e.subtasks.map((s) => s.title));
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _projCtrl.dispose();
    _stCtrl.dispose();
    super.dispose();
  }

  // ── AI parse ──────────────────────────────────────────────────────────────
  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaudeAI = false;
    });

    _ParsedTask? result;
    try {
      final aiResult = await AIParser.parseText(
        feature: 'planit',
        subFeature: 'task',
        text: text.trim(),
      );
      if (aiResult.success && aiResult.data != null) {
        result = _parsedTaskFromAI(aiResult.data!, widget.walletId);
        _usingClaudeAI = true;
      } else {
        throw Exception(aiResult.error ?? 'AI parse failed');
      }
    } catch (_) {
      try {
        result = _TaskNlpParser.parse(text.trim(), widget.walletId);
        _usingClaudeAI = false;
      } catch (e) {
        if (mounted)
          setState(() {
            _aiParsing = false;
            _aiError = 'Could not understand — try again or fill manually.';
          });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _aiPreview = result;
      _aiParsing = false;
      _titleCtrl.text = result!.title;
      _descCtrl.text = result.description ?? '';
      _projCtrl.text = result.project ?? '';
      _emoji = result.emoji;
      _priority = result.priority;
      _assignedTo = result.assignedTo;
      _dueDate = result.dueDate;
      if (result.subtasks.isNotEmpty) {
        _subtasks.clear();
        _subtasks.addAll(result.subtasks);
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      if (_mode.index == 0) _mode.animateTo(1);
      return;
    }
    setState(() => _titleError = false);
    final e = widget.existing;
    widget.onSave(
      TaskModel(
        id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        emoji: _emoji,
        status: e?.status ?? TaskStatus.todo,
        priority: _priority,
        assignedTo: _assignedTo,
        walletId: widget.walletId,
        project: _projCtrl.text.trim().isEmpty ? null : _projCtrl.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        // Header
        Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              widget.existing != null ? 'Edit Task' : 'New Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Mode switcher
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.split, Color(0xFF7C6DFF)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Nunito',
            ),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('AI Parse'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Manual'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI TAB ────────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          _TaskAiHint(isDark: widget.isDark),
          const SizedBox(height: 12),
          _TaskAiInputBox(
            ctrl: _aiCtrl,
            surfBg: widget.surfBg,
            isDark: widget.isDark,
            isParsing: _aiParsing,
            onParse: () => _parseAI(_aiCtrl.text),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            _TaskErrorBanner(message: _aiError!),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            _TaskAiPreviewCard(
              preview: _aiPreview!,
              isDark: widget.isDark,
              surfBg: widget.surfBg,
              usedClaudeAI: _usingClaudeAI,
              onEdit: () => _mode.animateTo(1),
            ),
            const SizedBox(height: 16),
            SaveButton(
              label: widget.existing != null ? 'Update Task →' : 'Save Task →',
              color: AppColors.split,
              onTap: _save,
            ),
          ],
          if (_aiPreview == null && !_aiParsing) ...[
            const SizedBox(height: 12),
            _TaskExamples(
              surfBg: widget.surfBg,
              sub: sub,
              onTap: (s) => _aiCtrl.text = s,
            ),
          ],
        ],

        // ── MANUAL TAB ────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          _TaskManualForm(
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            projCtrl: _projCtrl,
            members: widget.members,
            emoji: _emoji,
            priority: _priority,
            assignedTo: _assignedTo,
            dueDate: _dueDate,
            subtasks: _subtasks,
            stCtrl: _stCtrl,
            emojis: _emojis,
            titleError: _titleError,
            onEmojiChanged: (v) => setState(() => _emoji = v),
            onPriorityChanged: (v) => setState(() => _priority = v),
            onAssignedChanged: (v) => setState(() => _assignedTo = v),
            onDueDateChanged: (v) => setState(() => _dueDate = v),
            onAddSubtask: (s) => setState(() {
              _subtasks.add(s);
              _stCtrl.clear();
            }),
            onRemoveSubtask: (s) => setState(() => _subtasks.remove(s)),
          ),
          const SizedBox(height: 16),
          SaveButton(
            label: widget.existing != null ? 'Update Task →' : 'Save Task →',
            color: AppColors.split,
            onTap: _save,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TaskAiHint extends StatelessWidget {
  final bool isDark;
  const _TaskAiHint({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.split.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.split.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe your task in plain English — Claude AI will extract the title, due date, priority, subtasks and more.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TaskAiInputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final Color surfBg;
  final bool isDark, isParsing;
  final VoidCallback onParse;
  const _TaskAiInputBox({
    required this.ctrl,
    required this.surfBg,
    required this.isDark,
    required this.isParsing,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.split.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText:
                    '"Build landing page by Friday, high priority, subtasks: design, code, deploy"',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: sub,
                  fontFamily: 'Nunito',
                  height: 1.4,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.split.withOpacity(0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plain text → AI fills all fields',
                    style: TextStyle(
                      fontSize: 11,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isParsing ? null : onParse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isParsing
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.split, Color(0xFF7C6DFF)],
                            ),
                      color: isParsing
                          ? AppColors.split.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isParsing
                        ? const SizedBox(
                            width: 64,
                            height: 16,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                              minHeight: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('✨', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 5),
                              Text(
                                'Parse',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskErrorBanner extends StatelessWidget {
  final String message;
  const _TaskErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.expense.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.expense.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.expense,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: AppColors.expense,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TaskAiPreviewCard extends StatelessWidget {
  final _ParsedTask preview;
  final bool isDark, usedClaudeAI;
  final Color surfBg;
  final VoidCallback onEdit;
  const _TaskAiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.usedClaudeAI,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.income.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: preview.priority.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  preview.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        usedClaudeAI ? '🤖 AI Parsed' : '✨ AI Parsed',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.income.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: AppColors.income,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PreviewChip(
                icon: Icons.flag_rounded,
                label: preview.priority.label,
                color: preview.priority.color,
              ),
              if (preview.dueDate != null)
                _PreviewChip(
                  icon: Icons.calendar_today_rounded,
                  label: fmtDateShort(preview.dueDate!),
                  color: daysUntilColor(preview.dueDate!),
                ),
              if (preview.project != null)
                _PreviewChip(
                  icon: Icons.folder_rounded,
                  label: '📁 ${preview.project}',
                  color: AppColors.split,
                ),
              if (preview.subtasks.isNotEmpty)
                _PreviewChip(
                  icon: Icons.checklist_rounded,
                  label: '${preview.subtasks.length} subtasks',
                  color: AppColors.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskExamples extends StatelessWidget {
  final Color surfBg, sub;
  final void Function(String) onTap;
  const _TaskExamples({
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });

  static const _examples = [
    'Build the landing page by Friday, high priority',
    'Prepare client presentation next Monday, subtasks: outline, slides, review',
    'Fix login bug this week, urgent',
    'Weekly team meeting every Monday morning',
    'Write unit tests for payment module, medium priority',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Try an example',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: sub,
        ),
      ),
      const SizedBox(height: 8),
      ..._examples.map(
        (e) => GestureDetector(
          onTap: () => onTap(e),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.split.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_west_rounded,
                  size: 12,
                  color: AppColors.split.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FORM
// ─────────────────────────────────────────────────────────────────────────────

class _TaskManualForm extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final List<PlanMember> members;
  final TextEditingController titleCtrl, descCtrl, projCtrl, stCtrl;
  final String emoji, assignedTo;
  final Priority priority;
  final DateTime? dueDate;
  final List<String> subtasks, emojis;
  final bool titleError;
  final void Function(String) onEmojiChanged;
  final void Function(Priority) onPriorityChanged;
  final void Function(String) onAssignedChanged;
  final void Function(DateTime?) onDueDateChanged;
  final void Function(String) onAddSubtask;
  final void Function(String) onRemoveSubtask;

  const _TaskManualForm({
    required this.isDark,
    required this.surfBg,
    this.members = const [],
    required this.titleCtrl,
    required this.descCtrl,
    required this.projCtrl,
    required this.stCtrl,
    required this.emoji,
    required this.priority,
    required this.assignedTo,
    required this.dueDate,
    required this.subtasks,
    required this.emojis,
    required this.titleError,
    required this.onEmojiChanged,
    required this.onPriorityChanged,
    required this.onAssignedChanged,
    required this.onDueDateChanged,
    required this.onAddSubtask,
    required this.onRemoveSubtask,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Emoji Picker
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => onEmojiChanged(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? AppColors.split.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emoji == e
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

        /// Title
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: titleError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                decoration: InputDecoration.collapsed(
                  hintText: 'Task title *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: titleError ? AppColors.expense : sub,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              if (titleError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Title is required',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.expense,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),
        PlanInputField(
          controller: descCtrl,
          hint: 'Description (optional)',
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        PlanInputField(controller: projCtrl, hint: 'Project (optional)'),
        const SizedBox(height: 16),

        /// Priority
        const SheetLabel(text: 'PRIORITY'),
        Row(
          children: Priority.values
              .map(
                (p) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: p.index > 0 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => onPriorityChanged(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? p.color
                              : p.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: priority == p ? p.color : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: priority == p ? Colors.white : p.color,
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

        /// Due Date + Assign
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        dueDate ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) onDueDateChanged(d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
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
                        dueDate != null ? fmtDateShort(dueDate!) : 'Due date',
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
            Expanded(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (members.isNotEmpty ? members : mockMembers)
                      .take(5)
                      .map((m_) {
                        final m = m_ as PlanMember;
                        return GestureDetector(
                          onTap: () => onAssignedChanged(m.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: assignedTo == m.id
                                  ? AppColors.primary.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: assignedTo == m.id
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
                        );
                      })
                      .toList(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        /// Subtasks
        const SheetLabel(text: 'SUBTASKS'),

        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: TextField(
                  controller: stCtrl,
                  style: TextStyle(
                    fontSize: 13,
                    color: tc,
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
                    if (v.trim().isNotEmpty) {
                      onAddSubtask(v.trim());
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (stCtrl.text.trim().isNotEmpty) {
                  onAddSubtask(stCtrl.text.trim());
                }
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

        if (subtasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...subtasks.map(
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
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemoveSubtask(s),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLAUDE AI PARSER FOR TASKS
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedTask {
  final String title, emoji, assignedTo, walletId;
  final String? description, project;
  final DateTime? dueDate;
  final Priority priority;
  final List<String> subtasks;

  const _ParsedTask({
    required this.title,
    required this.emoji,
    required this.assignedTo,
    required this.walletId,
    required this.priority,
    required this.subtasks,
    this.description,
    this.project,
    this.dueDate,
  });
}

/// Maps the AI edge-function response map to [_ParsedTask].
_ParsedTask _parsedTaskFromAI(Map<String, dynamic> data, String walletId) {
  const pm = {
    'low': Priority.low,
    'medium': Priority.medium,
    'high': Priority.high,
    'urgent': Priority.urgent,
  };
  DateTime? dueDate;
  try {
    if (data['due_date'] != null) dueDate = DateTime.parse(data['due_date'] as String);
  } catch (_) {}
  final subtasks = (data['subtasks'] as List? ?? [])
      .map((s) => s.toString())
      .toList();
  return _ParsedTask(
    title: data['title'] as String? ?? '',
    emoji: data['emoji'] as String? ?? '✅',
    description: data['description'] as String?,
    project: data['project'] as String?,
    dueDate: dueDate,
    priority: pm[data['priority']] ?? Priority.medium,
    subtasks: subtasks,
    assignedTo: data['assigned_to'] as String? ?? 'me',
    walletId: walletId,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NLP PARSER FOR TASKS — fallback
// ─────────────────────────────────────────────────────────────────────────────

class _TaskNlpParser {
  static _ParsedTask parse(String raw, String walletId) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    // Due date
    DateTime? dueDate;
    if (lower.contains('today')) {
      dueDate = now;
    } else if (lower.contains('tomorrow')) {
      dueDate = now.add(const Duration(days: 1));
    } else if (lower.contains('next week')) {
      dueDate = now.add(const Duration(days: 7));
    } else {
      final inDays = RegExp(r'in (\d+) days?').firstMatch(lower);
      final inWeeks = RegExp(r'in (\d+) weeks?').firstMatch(lower);
      final onDay = RegExp(
        r'on (?:the )?(\d{1,2})(?:st|nd|rd|th)?',
      ).firstMatch(lower);
      const wdNames = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      if (inDays != null) {
        dueDate = now.add(Duration(days: int.parse(inDays.group(1)!)));
      } else if (inWeeks != null) {
        dueDate = now.add(Duration(days: int.parse(inWeeks.group(1)!) * 7));
      } else if (onDay != null) {
        final day = int.parse(onDay.group(1)!);
        dueDate = DateTime(now.year, now.month, day);
        if (dueDate.isBefore(now))
          dueDate = DateTime(now.year, now.month + 1, day);
      } else {
        for (int i = 0; i < wdNames.length; i++) {
          if (lower.contains(wdNames[i])) {
            int ahead = (i + 1) - now.weekday;
            if (ahead <= 0) ahead += 7;
            dueDate = now.add(Duration(days: ahead));
            break;
          }
        }
      }
    }

    // Priority
    Priority priority = Priority.medium;
    if (lower.contains('urgent') || lower.contains('asap'))
      priority = Priority.urgent;
    else if (lower.contains('high') || lower.contains('important'))
      priority = Priority.high;
    else if (lower.contains('low') || lower.contains('someday'))
      priority = Priority.low;

    // Subtasks from "subtasks: a, b, c" pattern
    final List<String> subtasks = [];
    final stMatch = RegExp(
      r'subtasks?:?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (stMatch != null) {
      subtasks.addAll(
        stMatch
            .group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }

    // Emoji
    String emoji = '✅';
    if (lower.contains('bug') || lower.contains('fix'))
      emoji = '🔧';
    else if (lower.contains('design') || lower.contains('ui'))
      emoji = '🎨';
    else if (lower.contains('meeting') || lower.contains('call'))
      emoji = '📅';
    else if (lower.contains('research') || lower.contains('study'))
      emoji = '📚';
    else if (lower.contains('deploy') || lower.contains('launch'))
      emoji = '🚀';
    else if (lower.contains('write') || lower.contains('document'))
      emoji = '📝';
    else if (lower.contains('review') || lower.contains('test'))
      emoji = '🎯';
    else if (lower.contains('shop') || lower.contains('buy'))
      emoji = '🛒';

    // Title cleanup
    String title = text
        .replaceAll(RegExp(r'subtasks?:?.+', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r',?\s*(high|low|urgent|medium)\s+priority',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s+(today|tomorrow|next week)', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+by\s+\w+', caseSensitive: false), '')
        .trim();
    if (title.isEmpty) title = text.trim();
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
    if (title.length > 60) title = '${title.substring(0, 57)}...';

    return _ParsedTask(
      title: title,
      emoji: emoji,
      assignedTo: 'me',
      walletId: walletId,
      priority: priority,
      subtasks: subtasks,
      dueDate: dueDate,
    );
  }
}
